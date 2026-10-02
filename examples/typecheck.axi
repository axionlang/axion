-- typecheck.axi — a Hindley-Milner type inferencer (algorithm W) for the tiny lambda language,
-- a companion to examples/lambda.axi. It infers a principal type for each expression and rejects
-- ill-typed programs with a message. Demonstrates the FUNCTIONAL CORE once more — recursion,
-- an environment, unification — but with a twist chosen for Axión's LINEAR, GC-free model:
--
--   Types are represented as INT HANDLES into a node store, NOT as a recursive `Ty` value. Each
--   `Node` (NInt | NFun Int Int | NVar Int) carries only Int fields, so a type is a scalar and its
--   recursive structure lives in the handles. This is the standard union-find HM representation —
--   and here it also makes reclamation TRIVIAL: unify threads a scalar substitution (var-id ->
--   node-id) and borrows the store; there are no recursive heap type-values to free. (A direct
--   recursive-`Ty` encoding forces the borrow inference to an all-borrowed fixpoint over the
--   mutually-recursive unifier, leaking the type nodes — the handle encoding sidesteps that.)
--
-- Infers: identity `\x -> x : (t0 -> t0)`, curried `\x -> \y -> x + y : (Int -> (Int -> Int))`,
-- `twice : Int`, `if : Int`; rejects applying a number and adding a function. Hand-built ASTs
-- (parsing is covered by lambda.axi). Runs identically on interp/dev/release; verify + ASan + LSan
-- clean.

-- Arena/index types: a Node carries only Int handles (child node-ids / var-id), so types are
-- scalars and the recursive structure lives in the handles — no recursive-value reclamation.
data Node = NInt | NFun Int Int | NVar Int

copyNode :: Node -> Node
copyNode n = case n of
  NInt -> NInt
  NFun a b -> NFun a b
  NVar v -> NVar v

-- the type store: node-id -> Node (built with increasing ids). getNode returns a COPY (Int fields
-- → flat), never an element alias.
getNode :: List (Int, Node) -> Int -> Node
getNode store i = case store of
  Nil -> NInt
  Cons kv rest -> case kv of
    (k, nd) -> if k == i then copyNode nd else getNode rest i

-- subst: var-id -> node-id (both Int).
lookupI :: Int -> List (Int, Int) -> Maybe Int
lookupI n sub = case sub of
  Nil -> Nothing
  Cons kv rest -> case kv of
    (k, v) -> if k == n then Just v else lookupI n rest

-- resolve a node-id to its representative (chase bound vars).
resolve :: List (Int, Node) -> List (Int, Int) -> Int -> Int
resolve store sub i = case getNode store i of
  NVar v -> resolveVar store sub i v
  NInt -> i
  NFun a b -> i

resolveVar :: List (Int, Node) -> List (Int, Int) -> Int -> Int -> Int
resolveVar store sub i v = case lookupI v sub of
  Just j -> resolve store sub j
  Nothing -> i

occurs :: List (Int, Node) -> List (Int, Int) -> Int -> Int -> Bool
occurs store sub v i =
  let r = resolve store sub i in
  case getNode store r of
    NVar w -> v == w
    NInt -> False
    NFun a b -> occurs store sub v a || occurs store sub v b

unify :: List (Int, Node) -> List (Int, Int) -> Int -> Int -> Either String (List (Int, Int))
unify store sub a b = unifyR store sub (resolve store sub a) (resolve store sub b)

unifyR :: List (Int, Node) -> List (Int, Int) -> Int -> Int -> Either String (List (Int, Int))
unifyR store sub a b = case getNode store a of
  NInt -> unifyInt store sub a b
  NVar v -> bindV store sub v b
  NFun a1 a2 -> unifyFun store sub a a1 a2 b

unifyInt :: List (Int, Node) -> List (Int, Int) -> Int -> Int -> Either String (List (Int, Int))
unifyInt store sub a b = case getNode store b of
  NInt -> Right sub
  NVar v -> Right (Cons (v, a) sub)
  NFun x y -> Left "cannot unify Int with a function type"

unifyFun :: List (Int, Node) -> List (Int, Int) -> Int -> Int -> Int -> Int -> Either String (List (Int, Int))
unifyFun store sub afun a1 a2 b = case getNode store b of
  NFun b1 b2 -> do
    s1 <-! unify store sub a1 b1
    unify store s1 a2 b2
  NVar v -> bindV store sub v afun
  NInt -> Left "cannot unify a function type with Int"

-- bind var v (node-id vnode's var) to node-id t, with occurs check.
bindV :: List (Int, Node) -> List (Int, Int) -> Int -> Int -> Either String (List (Int, Int))
bindV store sub v t =
  if occurs store sub v t then Left "occurs check: infinite type"
  else Right (Cons (v, t) sub)

showType :: List (Int, Node) -> List (Int, Int) -> Int -> String
showType store sub i =
  let r = resolve store sub i in
  case getNode store r of
    NInt -> "Int"
    NVar v -> strAppend "t" (showInt v)
    NFun a b -> strAppend "(" (strAppend (showType store sub a) (strAppend " -> " (strAppend (showType store sub b) ")")))

-- ===================== inference (algorithm W over Int handles) =====================

data Expr = Num Int | Var String | Add Expr Expr | Mul Expr Expr | Eq Expr Expr
          | Lam String Expr | App Expr Expr | Let String Expr Expr | If Expr Expr Expr

-- threaded state: the node store, the substitution, and the next fresh id.
data St = St (List (Int, Node)) (List (Int, Int)) Int

-- allocate a node (id = the current counter), returning the new state and the id.
addNode :: St -> Node -> (St, Int)
addNode st nd = case st of
  St store sub c -> (St (Cons (c, nd) store) sub (c + 1), c)

-- a fresh type variable (its var-id equals its node-id).
freshVar :: St -> (St, Int)
freshVar st = case st of
  St store sub c -> (St (Cons (c, NVar c) store) sub (c + 1), c)

stStore :: St -> List (Int, Node)
stStore st = case st of
  St store sub c -> store

-- run unify against the state's store/subst, folding the resulting subst back in.
stUnify :: St -> Int -> Int -> Either String St
stUnify st a b = case st of
  St store sub c -> case unify store sub a b of
    Left m -> Left m
    Right sub2 -> Right (St store sub2 c)

-- type-env lookup: name -> node-id.
envLook :: String -> List (String, Int) -> Either String Int
envLook x env = case env of
  Nil -> Left (strAppend "unbound variable: " x)
  Cons kv rest -> case kv of
    (k, v) -> if strCmp k x == 0 then Right v else envLook x rest

copyStr :: String -> String
copyStr s = strAppend s ""

copyEnv :: List (String, Int) -> List (String, Int)
copyEnv env = case env of
  Nil -> Nil
  Cons kv rest -> case kv of
    (k, v) -> Cons (copyStr k, v) (copyEnv rest)

-- infer: thread St + type env; return (St, node-id of the expression's type).
infer :: St -> List (String, Int) -> Expr -> Either String (St, Int)
infer st env e = case e of
  Num n -> Right (addNode st NInt)
  Var x -> inferVar st env x
  Add a b -> inferArith st env a b
  Mul a b -> inferArith st env a b
  Eq a b -> inferArith st env a b
  Lam x body -> inferLam st env x body
  App f a -> inferApp st env f a
  Let x rhs body -> inferLet st env x rhs body
  If c t el -> inferIf st env c t el

inferVar :: St -> List (String, Int) -> String -> Either String (St, Int)
inferVar st env x = case envLook x env of
  Left m -> Left m
  Right i -> Right (st, i)

-- binary Int op: both operands must be Int, result Int.
inferArith :: St -> List (String, Int) -> Expr -> Expr -> Either String (St, Int)
inferArith st env a b = do
  (st1, ta) <-! infer st env a
  (st2, i1) <-! intNode st1
  st3 <-! stUnify st2 ta i1
  (st4, tb) <-! infer st3 env b
  (st5, i2) <-! intNode st4
  st6 <-! stUnify st5 tb i2
  Right (addNode st6 NInt)

intNode :: St -> Either String (St, Int)
intNode st = Right (addNode st NInt)

inferLam :: St -> List (String, Int) -> String -> Expr -> Either String (St, Int)
inferLam st env x body = case freshVar st of
  (st1, tx) -> do
    (st2, tbody) <-! infer st1 (Cons (copyStr x, tx) (copyEnv env)) body
    Right (addNode st2 (NFun tx tbody))

inferApp :: St -> List (String, Int) -> Expr -> Expr -> Either String (St, Int)
inferApp st env f a = do
  (st1, tf) <-! infer st env f
  (st2, ta) <-! infer st1 env a
  (st3, tr) <-! freshVarE st2
  (st4, tfun) <-! funNode st3 ta tr
  st5 <-! stUnify st4 tf tfun
  Right (st5, tr)

freshVarE :: St -> Either String (St, Int)
freshVarE st = Right (freshVar st)

funNode :: St -> Int -> Int -> Either String (St, Int)
funNode st a b = Right (addNode st (NFun a b))

inferLet :: St -> List (String, Int) -> String -> Expr -> Expr -> Either String (St, Int)
inferLet st env x rhs body = do
  (st1, t1) <-! infer st env rhs
  infer st1 (Cons (copyStr x, t1) (copyEnv env)) body

inferIf :: St -> List (String, Int) -> Expr -> Expr -> Expr -> Either String (St, Int)
inferIf st env c t el = do
  (st1, tc) <-! infer st env c
  (st2, ic) <-! intNode st1
  st3 <-! stUnify st2 tc ic
  (st4, tt) <-! infer st3 env t
  (st5, te) <-! infer st4 env el
  st6 <-! stUnify st5 tt te
  Right (st6, tt)

typeOf :: Expr -> String
typeOf e = case infer (St Nil Nil 0) Nil e of
  Left m -> strAppend "type error: " m
  Right res -> case res of
    (st, i) -> case st of
      St store sub c -> showType store sub i

-- demos: identity, add (curried), twice, let, if, and type errors.
p1 :: Expr
p1 = Lam "x" (Var "x")
p2 :: Expr
p2 = Lam "x" (Lam "y" (Add (Var "x") (Var "y")))
p3 :: Expr
p3 = Let "twice" (Lam "f" (Lam "x" (App (Var "f") (App (Var "f") (Var "x")))))
       (App (App (Var "twice") (Lam "n" (Mul (Var "n") (Var "n")))) (Num 3))
p4 :: Expr
p4 = If (Eq (Num 1) (Num 1)) (Num 10) (Num 20)
p5 :: Expr
p5 = App (Num 1) (Num 2)
p6 :: Expr
p6 = Add (Num 1) (Lam "x" (Var "x"))

main :: IO ()
main = do
  putStrLn (typeOf p1)
  putStrLn (typeOf p2)
  putStrLn (typeOf p3)
  putStrLn (typeOf p4)
  putStrLn (typeOf p5)
  putStrLn (typeOf p6)
