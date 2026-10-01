-- lambda.axi — a tree-walking interpreter for a tiny expression/lambda language, the third Axión
-- flagship (after `pass` and `fff`). It exercises the FUNCTIONAL CORE that the IO/OS-heavy flagships
-- do not: recursive ADTs (the AST + runtime values), deep pattern matching, recursion-heavy
-- evaluation, an environment — and the interesting part for a LINEAR, GC-free language: explicit
-- deep copiers. There is no zero-cost sharing, so variable lookup returns a COPY of the bound value
-- and evaluating a `Lam` captures a COPY of the environment into the closure. That makes the cost of
-- closures-without-a-GC concrete and sound by construction. Runs identically on interp/dev/release,
-- verify- and leak-clean.
--
-- Pipeline: `tokenize :: String -> List Tok` → recursive-descent `parseAt` (an Int cursor over the
-- borrowed token list — no list consumed, no suffix aliased) → `eval` over an association-list
-- environment. Errors thread through `Either String _` with the `<-!` short-circuit bind.
--
-- Language: `Num`, `Var`, `+ - *`, `== <` (→ 1/0), `\x -> e`, application, `let x = e in e`,
-- `if c then e else e` (truthy = nonzero). Usage: `lambda '<program>'` evaluates one program;
-- with no argument it runs a built-in demo suite.

data Expr = Num Int
          | Var String
          | Add Expr Expr
          | Sub Expr Expr
          | Mul Expr Expr
          | Eq Expr Expr
          | Lt Expr Expr
          | Lam String Expr
          | App Expr Expr
          | Let String Expr Expr
          | If Expr Expr Expr

data Value = IntV Int | CloV String Expr (List (String, Value))

data Tok = TNum Int | TName String | TSym String

copyStr :: String -> String
copyStr s = strAppend s ""

copyExpr :: Expr -> Expr
copyExpr e = case e of
  Num n -> Num n
  Var x -> Var (copyStr x)
  Add a b -> Add (copyExpr a) (copyExpr b)
  Sub a b -> Sub (copyExpr a) (copyExpr b)
  Mul a b -> Mul (copyExpr a) (copyExpr b)
  Eq a b -> Eq (copyExpr a) (copyExpr b)
  Lt a b -> Lt (copyExpr a) (copyExpr b)
  Lam x b -> Lam (copyStr x) (copyExpr b)
  App f a -> App (copyExpr f) (copyExpr a)
  Let x a b -> Let (copyStr x) (copyExpr a) (copyExpr b)
  If c t el -> If (copyExpr c) (copyExpr t) (copyExpr el)

copyValue :: Value -> Value
copyValue v = case v of
  IntV n -> IntV n
  CloV p b env -> CloV (copyStr p) (copyExpr b) (copyEnv env)

copyEnv :: List (String, Value) -> List (String, Value)
copyEnv env = case env of
  Nil -> Nil
  Cons kv rest -> case kv of
    (k, val) -> Cons (copyStr k, copyValue val) (copyEnv rest)

-- ===================== evaluator =====================

envLookup :: String -> List (String, Value) -> Either String Value
envLookup k env = case env of
  Nil -> Left (strAppend "unbound variable: " k)
  Cons kv rest -> case kv of
    (key, val) -> if strCmp key k == 0 then Right (copyValue val) else envLookup k rest

asInt :: Value -> Either String Int
asInt v = case v of
  IntV n -> Right n
  CloV p b env -> Left "expected a number, got a function"

applyOp :: Int -> Int -> Int -> Int
applyOp op x y =
  if op == 0 then x + y
  else if op == 1 then x - y
  else if op == 2 then x * y
  else if op == 3 then (if x == y then 1 else 0)
  else (if x < y then 1 else 0)

eval :: List (String, Value) -> Expr -> Either String Value
eval env e = case e of
  Num n -> Right (IntV n)
  Var x -> envLookup x env
  Add a b -> evalArith env a b 0
  Sub a b -> evalArith env a b 1
  Mul a b -> evalArith env a b 2
  Eq a b -> evalArith env a b 3
  Lt a b -> evalArith env a b 4
  Lam p body -> Right (CloV (copyStr p) (copyExpr body) (copyEnv env))
  App f a -> evalApp env f a
  Let x rhs body -> evalLet env x rhs body
  If c t el -> evalIf env c t el

evalArith :: List (String, Value) -> Expr -> Expr -> Int -> Either String Value
evalArith env a b op = do
  va <-! eval env a
  na <-! asInt va
  vb <-! eval env b
  nb <-! asInt vb
  Right (IntV (applyOp op na nb))

evalApp :: List (String, Value) -> Expr -> Expr -> Either String Value
evalApp env f a = do
  fv <-! eval env f
  applyClo fv env a

applyClo :: Value -> List (String, Value) -> Expr -> Either String Value
applyClo fv env a = case fv of
  IntV n -> Left "cannot apply a number as a function"
  CloV p body cenv -> do
    arg <-! eval env a
    eval (Cons (p, arg) cenv) body

evalLet :: List (String, Value) -> String -> Expr -> Expr -> Either String Value
evalLet env x rhs body = do
  v <-! eval env rhs
  eval (Cons (copyStr x, v) (copyEnv env)) body

evalIf :: List (String, Value) -> Expr -> Expr -> Expr -> Either String Value
evalIf env c t el = do
  vc <-! eval env c
  nc <-! asInt vc
  if nc == 0 then eval env el else eval env t

-- ===================== tokenizer =====================

isSpaceCh :: Int -> Bool
isSpaceCh c = c == 32 || c == 9 || c == 10 || c == 13

isDigitCh :: Int -> Bool
isDigitCh c = c >= 48 && c <= 57

isAlphaCh :: Int -> Bool
isAlphaCh c = (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || c == 95

isAlnumCh :: Int -> Bool
isAlnumCh c = isAlphaCh c || isDigitCh c

scanWhile :: String -> Int -> Int -> Int
scanWhile s i kind =
  if i >= strLen s then i
  else
    let c = charAt i s in
    let ok = if kind == 0 then isDigitCh c else isAlnumCh c in
    if ok then scanWhile s (i + 1) kind else i

readIntOr :: String -> Int
readIntOr s = fromMaybe 0 (readInt s)

tokLoop :: String -> Int -> List Tok -> List Tok
tokLoop s i acc =
  if i >= strLen s then reverseToks acc
  else
    let c = charAt i s in
    if isSpaceCh c then tokLoop s (i + 1) acc
    else if isDigitCh c then
      let j = scanWhile s i 0 in
      tokLoop s j (Cons (TNum (readIntOr (substr i (j - i) s))) acc)
    else if isAlphaCh c then
      let j = scanWhile s i 1 in
      tokLoop s j (Cons (TName (substr i (j - i) s)) acc)
    else tokSym s i c acc

tokSym :: String -> Int -> Int -> List Tok -> List Tok
tokSym s i c acc =
  if c == 45 && i + 1 < strLen s && charAt (i + 1) s == 62 then
    tokLoop s (i + 2) (Cons (TSym (strAppend "-" ">")) acc)
  else if c == 61 && i + 1 < strLen s && charAt (i + 1) s == 61 then
    tokLoop s (i + 2) (Cons (TSym (strAppend "=" "=")) acc)
  else tokLoop s (i + 1) (Cons (TSym (chr c)) acc)

reverseToks :: List Tok -> List Tok
reverseToks ts = revToksGo ts Nil

revToksGo :: List Tok -> List Tok -> List Tok
revToksGo ts acc = case ts of
  Nil -> acc
  Cons t rest -> revToksGo rest (Cons t acc)

tokenize :: String -> List Tok
tokenize s = tokLoop s 0 Nil

-- ===================== parser (index-cursor recursive descent) =====================
-- The token list is BORROWED throughout; the cursor is an `Int` position. Each parser
-- returns `Either String (Expr, Int)` — the node + the next position. No list is
-- consumed and no suffix is aliased, so the parser is reclamation-trivial. Lookups walk
-- to the position (O(pos)); programs are small, so O(n^2) is irrelevant.

-- single-token classifiers (borrow the token).
tokKind :: Tok -> Int
tokKind t = case t of
  TNum n -> 0
  TName x -> 1
  TSym x -> 2

tokNum :: Tok -> Int
tokNum t = case t of
  TNum n -> n
  TName x -> 0
  TSym x -> 0

tokWord :: Tok -> String
tokWord t = case t of
  TNum n -> ""
  TName x -> copyStr x
  TSym x -> copyStr x

-- token kind at position: 0 = number, 1 = name, 2 = symbol, 3 = end
kindAt :: List Tok -> Int -> Int
kindAt toks i = case toks of
  Nil -> 3
  Cons t rest -> if i == 0 then tokKind t else kindAt rest (i - 1)

numAt :: List Tok -> Int -> Int
numAt toks i = case toks of
  Nil -> 0
  Cons t rest -> if i == 0 then tokNum t else numAt rest (i - 1)

-- the symbol OR name text at position (a fresh copy), "" if a number / past end.
wordAt :: List Tok -> Int -> String
wordAt toks i = case toks of
  Nil -> ""
  Cons t rest -> if i == 0 then tokWord t else wordAt rest (i - 1)

isKeyword :: String -> Bool
isKeyword x =
  strCmp x "let" == 0 || strCmp x "in" == 0 || strCmp x "if" == 0
    || strCmp x "then" == 0 || strCmp x "else" == 0

-- does position `p` begin an atom? number, non-keyword name, or '('
startsAtomAt :: List Tok -> Int -> Bool
startsAtomAt toks p =
  let k = kindAt toks p in
  if k == 0 then True
  else if k == 1 then not (isKeyword (wordAt toks p))
  else if k == 2 then strCmp (wordAt toks p) "(" == 0
  else False

-- expr := cmp
pExpr :: List Tok -> Int -> Either String (Expr, Int)
pExpr toks p = pCmp toks p

-- cmp := add (('=='|'<') add)?
pCmp :: List Tok -> Int -> Either String (Expr, Int)
pCmp toks p = do
  (l, p1) <-! pAdd toks p
  pCmpAfter toks l p1

pCmpAfter :: List Tok -> Expr -> Int -> Either String (Expr, Int)
pCmpAfter toks l p =
  let s = wordAt toks p in
  if strCmp s "==" == 0 then pCmpTail toks 3 l p
  else if strCmp s "<" == 0 then pCmpTail toks 4 l p
  else Right (l, p)

pCmpTail :: List Tok -> Int -> Expr -> Int -> Either String (Expr, Int)
pCmpTail toks op l p = do
  (r, p2) <-! pAdd toks (p + 1)
  Right (mkBin op l r, p2)

mkBin :: Int -> Expr -> Expr -> Expr
mkBin op l r =
  if op == 0 then Add l r
  else if op == 1 then Sub l r
  else if op == 2 then Mul l r
  else if op == 3 then Eq l r
  else Lt l r

-- add := mul (('+'|'-') mul)*
pAdd :: List Tok -> Int -> Either String (Expr, Int)
pAdd toks p = do
  (l, p1) <-! pMul toks p
  pAddLoop toks l p1

pAddLoop :: List Tok -> Expr -> Int -> Either String (Expr, Int)
pAddLoop toks l p =
  let s = wordAt toks p in
  if strCmp s "+" == 0 then pAddStep toks 0 l p
  else if strCmp s "-" == 0 then pAddStep toks 1 l p
  else Right (l, p)

pAddStep :: List Tok -> Int -> Expr -> Int -> Either String (Expr, Int)
pAddStep toks op l p = do
  (r, p2) <-! pMul toks (p + 1)
  pAddLoop toks (mkBin op l r) p2

-- mul := app ('*' app)*
pMul :: List Tok -> Int -> Either String (Expr, Int)
pMul toks p = do
  (l, p1) <-! pApp toks p
  pMulLoop toks l p1

pMulLoop :: List Tok -> Expr -> Int -> Either String (Expr, Int)
pMulLoop toks l p =
  let s = wordAt toks p in
  if strCmp s "*" == 0 then pMulStep toks l p
  else Right (l, p)

pMulStep :: List Tok -> Expr -> Int -> Either String (Expr, Int)
pMulStep toks l p = do
  (r, p2) <-! pApp toks (p + 1)
  pMulLoop toks (Mul l r) p2

-- app := atom atom*   (juxtaposition = application)
pApp :: List Tok -> Int -> Either String (Expr, Int)
pApp toks p = do
  (l, p1) <-! pAtom toks p
  pAppLoop toks l p1

pAppLoop :: List Tok -> Expr -> Int -> Either String (Expr, Int)
pAppLoop toks l p =
  if startsAtomAt toks p then pAppStep toks l p
  else Right (l, p)

pAppStep :: List Tok -> Expr -> Int -> Either String (Expr, Int)
pAppStep toks l p = do
  (r, p2) <-! pAtom toks p
  pAppLoop toks (App l r) p2

-- atom := Num | Var | '(' expr ')' | lam | let | if
pAtom :: List Tok -> Int -> Either String (Expr, Int)
pAtom toks p =
  let k = kindAt toks p in
  if k == 0 then Right (Num (numAt toks p), p + 1)
  else if k == 1 then pAtomName toks p
  else if k == 2 then pAtomSym toks p
  else Left "unexpected end of input"

-- The name text is read FRESH per use (`wordAt toks p`), not bound once as a value that is
-- conditionally moved: a keyword branch borrows the temp in `strCmp` (reclaimed as an owned
-- temp after the call), and only the terminal `Var`/error branch moves a fresh copy in. A
-- single `let x = …` spanning the branches would be moved on one path yet dead on the others
-- — the conditionally-escaping-owned-temp shape the reclaimer leaves conservative.
pAtomName :: List Tok -> Int -> Either String (Expr, Int)
pAtomName toks p =
  if strCmp (wordAt toks p) "let" == 0 then pLet toks (p + 1)
  else if strCmp (wordAt toks p) "if" == 0 then pIf toks (p + 1)
  else Right (Var (wordAt toks p), p + 1)

pAtomSym :: List Tok -> Int -> Either String (Expr, Int)
pAtomSym toks p =
  if strCmp (wordAt toks p) "(" == 0 then pParen toks (p + 1)
  else if strCmp (wordAt toks p) "\\" == 0 then pLam toks (p + 1)
  else Left (strAppend "unexpected symbol: " (wordAt toks p))

pParen :: List Tok -> Int -> Either String (Expr, Int)
pParen toks p = do
  (e, p1) <-! pExpr toks p
  expectWord toks ")" e p1

-- consume an expected keyword/symbol at `p`, returning (e, p+1); else error
expectWord :: List Tok -> String -> Expr -> Int -> Either String (Expr, Int)
expectWord toks want e p =
  if strCmp (wordAt toks p) want == 0 then Right (e, p + 1)
  else Left (strAppend "expected " want)

-- lam := '\' Name '->' expr   ('\' consumed, p at the Name)
pLam :: List Tok -> Int -> Either String (Expr, Int)
pLam toks p =
  if kindAt toks p == 1 then pLamBody toks (wordAt toks p) (p + 1)
  else Left "expected a parameter name after '\\'"

pLamBody :: List Tok -> String -> Int -> Either String (Expr, Int)
pLamBody toks nm p =
  if strCmp (wordAt toks p) "->" == 0 then pLamFinish toks nm (p + 1)
  else Left "expected '->' in lambda"

pLamFinish :: List Tok -> String -> Int -> Either String (Expr, Int)
pLamFinish toks nm p = do
  (body, p1) <-! pExpr toks p
  Right (Lam nm body, p1)

-- let := 'let' Name '=' expr 'in' expr   ('let' consumed, p at the Name)
pLet :: List Tok -> Int -> Either String (Expr, Int)
pLet toks p =
  if kindAt toks p == 1 then pLetEq toks (wordAt toks p) (p + 1)
  else Left "expected a name after 'let'"

pLetEq :: List Tok -> String -> Int -> Either String (Expr, Int)
pLetEq toks nm p =
  if strCmp (wordAt toks p) "=" == 0 then pLetRhs toks nm (p + 1)
  else Left "expected '=' in let"

pLetRhs :: List Tok -> String -> Int -> Either String (Expr, Int)
pLetRhs toks nm p = do
  (rhs, p1) <-! pExpr toks p
  pLetIn toks nm rhs p1

pLetIn :: List Tok -> String -> Expr -> Int -> Either String (Expr, Int)
pLetIn toks nm rhs p =
  if strCmp (wordAt toks p) "in" == 0 then pLetBody toks nm rhs (p + 1)
  else Left "expected 'in' in let"

pLetBody :: List Tok -> String -> Expr -> Int -> Either String (Expr, Int)
pLetBody toks nm rhs p = do
  (body, p1) <-! pExpr toks p
  Right (Let nm rhs body, p1)

-- if := 'if' expr 'then' expr 'else' expr   ('if' consumed)
pIf :: List Tok -> Int -> Either String (Expr, Int)
pIf toks p = do
  (c, p1) <-! pExpr toks p
  pIfThen toks c p1

pIfThen :: List Tok -> Expr -> Int -> Either String (Expr, Int)
pIfThen toks c p =
  if strCmp (wordAt toks p) "then" == 0 then pIfThenB toks c (p + 1)
  else Left "expected 'then'"

pIfThenB :: List Tok -> Expr -> Int -> Either String (Expr, Int)
pIfThenB toks c p = do
  (tb, p1) <-! pExpr toks p
  pIfElse toks c tb p1

pIfElse :: List Tok -> Expr -> Expr -> Int -> Either String (Expr, Int)
pIfElse toks c tb p =
  if strCmp (wordAt toks p) "else" == 0 then pIfElseB toks c tb (p + 1)
  else Left "expected 'else'"

pIfElseB :: List Tok -> Expr -> Expr -> Int -> Either String (Expr, Int)
pIfElseB toks c tb p = do
  (eb, p1) <-! pExpr toks p
  Right (If c tb eb, p1)

-- parse a full expression and require the cursor to reach the end
parseAt :: List Tok -> Either String Expr
parseAt toks = do
  (e, p) <-! pExpr toks 0
  if kindAt toks p == 3 then Right e else Left "trailing tokens after expression"

-- ===================== driver =====================

showValue :: Value -> String
showValue v = case v of
  IntV n -> showInt n
  CloV p b env -> "<closure>"

run :: String -> String
run src = runToks (tokenize src)

-- borrow the token list for parsing (parseAt reads it), then it is dropped here.
runToks :: List Tok -> String
runToks toks = case parseAt toks of
  Left msg -> strAppend "parse error: " msg
  Right e -> runEval e

runEval :: Expr -> String
runEval e = case eval Nil e of
  Left msg -> strAppend "eval error: " msg
  Right v -> showValue v

demo :: IO ()
demo = do
  putStrLn (run "1 + 2 * 3")
  putStrLn (run "let add = \\x -> \\y -> x + y in add 3 4")
  putStrLn (run "let twice = \\f -> \\x -> f (f x) in twice (\\n -> n * n) 3")
  putStrLn (run "if 1 < 2 then 10 else 20")
  putStrLn (run "let x = 5 in x * x")
  putStrLn (run "nope + 1")
  putStrLn (run "(1 + 2")

main :: IO ()
main = dispatch (getArg 0)

dispatch :: String -> IO ()
dispatch arg = if strLen arg == 0 then demo else putStrLn (run arg)
