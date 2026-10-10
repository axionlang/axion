-- json.axi — a JSON parser + serializer (flagship). STAGE 0: the recursive value type + serializer.
-- Json is a recursive ADT with MIXED heap fields (String, Float, List Json, object members) — the
-- reclamation surface where record/tagged-field ownership is hardest. Stage 0 proves this type
-- builds, serializes, and reclaims (verify-clean + ASan/LSan) before any parser exists.
data Json
  = JNull
  | JBool Bool
  | JNum Float
  | JStr String
  | JArr (List Json)
  | JObj (List Member)

-- Object members are a NAMED data record, NOT a bare `(String, Json)` tuple: a bare tuple as a
-- polymorphic list-element type is rejected on the native backends (AX0912, the nested-tuple
-- poly-payload the monomorphizer cannot lower — it runs only on the interpreter). A `data` record
-- element lowers cleanly on all three. (Flagship finding #2.)
data Member = Member String Json

-- serialize a Json value to its text form (recursive; string-building via strAppend).
showJson :: Json -> String
showJson v = case v of
  JNull -> "null"
  JBool b -> if b then "true" else "false"
  JNum n -> showFloat n
  JStr s -> strAppend "\"" (strAppend s "\"")
  JArr xs -> strAppend "[" (strAppend (showArr xs) "]")
  JObj ms -> strAppend "{" (strAppend (showObj ms) "}")

-- comma-separated element list
showArr :: List Json -> String
showArr xs = case xs of
  Nil -> ""
  Cons y ys -> case ys of
    Nil -> showJson y
    Cons z zs -> strAppend (showJson y) (strAppend "," (showArr ys))

-- comma-separated "key":value members
showObj :: List Member -> String
showObj ms = case ms of
  Nil -> ""
  Cons p rest -> case p of
    Member k val -> case rest of
      Nil -> showMember k val
      Cons q qs -> strAppend (showMember k val) (strAppend "," (showObj rest))

showMember :: String -> Json -> String
showMember k val = strAppend "\"" (strAppend k (strAppend "\":" (showJson val)))

-- ─── parser (scannerless recursive descent; index-cursor over a borrowed String) ───
-- Each parse fn takes (s, i) and returns Either String (Json, Int): Right (value, nextIndex) or a
-- Left error. The String is BORROWED (charAt/substr read it); substr yields FRESH owned Strings, so
-- parsed values never alias the input.
isDigitCh :: Int -> Bool
isDigitCh c = c >= 48 && c <= 57

isWsCh :: Int -> Bool
isWsCh c = c == 32 || c == 9 || c == 10 || c == 13

skipWs :: String -> Int -> Int
skipWs s i = if isWsCh (charAt i s) then skipWs s (i + 1) else i

-- hand-rolled number parsing (FINDING #1: no `readFloat` builtin; readInt exists but is Int-only).
-- integer run from `i`, accumulating acc*10+digit.
pfIntGo :: String -> Int -> Float -> Float
pfIntGo s i acc =
  if isDigitCh (charAt i s) then pfIntGo s (i + 1) (acc *. 10.0 +. toFloat (charAt i s - 48)) else acc
-- end index of the integer run
pfIntEnd :: String -> Int -> Int
pfIntEnd s i = if isDigitCh (charAt i s) then pfIntEnd s (i + 1) else i
-- fractional run after '.', place = 0.1, 0.01, … ; returns the fraction value
pfFrac :: String -> Int -> Float -> Float -> Float
pfFrac s i acc place =
  if isDigitCh (charAt i s) then pfFrac s (i + 1) (acc +. toFloat (charAt i s - 48) *. place) (place /. 10.0) else acc

parseNum :: String -> Int -> Either String (Json, Int)
parseNum s i =
  let neg = charAt i s == 45 in
  let i0 = if neg then i + 1 else i in
  let ip = pfIntGo s i0 0.0 in
  let j = pfIntEnd s i0 in
  let hasFrac = charAt j s == 46 in
  let fp = if hasFrac then pfFrac s (j + 1) 0.0 0.1 else 0.0 in
  let k = if hasFrac then pfIntEnd s (j + 1) else j in
  let mag = ip +. fp in
  Right (JNum (if neg then 0.0 -. mag else mag), k)

-- string: scan from the opening quote to the closing quote; substr the content (no escapes in v1).
strEnd :: String -> Int -> Int
strEnd s i = if charAt i s == 34 then i else if charAt i s == 0 - 1 then i else strEnd s (i + 1)
parseStr :: String -> Int -> Either String (Json, Int)
parseStr s i =
  let e = strEnd s (i + 1) in
  if charAt e s == 34 then Right (JStr (substr (i + 1) (e - i - 1) s), e + 1)
  else Left "unterminated string"

-- a bare keyword literal (null/true/false): check char-by-char, advance by its length.
litMatch :: String -> Int -> String -> Int -> Bool
litMatch s i lit li =
  if li >= strLen lit then True
  else if charAt i s == charAt li lit then litMatch s (i + 1) lit (li + 1) else False

parseVal :: String -> Int -> Either String (Json, Int)
parseVal s i0 =
  let i = skipWs s i0 in
  let c = charAt i s in
  if c == 110 then (if litMatch s i "null" 0 then Right (JNull, i + 4) else Left "bad literal")
  else if c == 116 then (if litMatch s i "true" 0 then Right (JBool True, i + 4) else Left "bad literal")
  else if c == 102 then (if litMatch s i "false" 0 then Right (JBool False, i + 5) else Left "bad literal")
  else if c == 34 then parseStr s i
  else if c == 45 then parseNum s i
  else if isDigitCh c then parseNum s i
  else if c == 91 then parseArr s (i + 1) Nil
  else if c == 123 then parseObj s (i + 1) Nil
  else Left (strAppend "unexpected char at index " (showInt i))

-- array: elements accumulated reversed, then reversed at the close.
parseArr :: String -> Int -> List Json -> Either String (Json, Int)
parseArr s i acc =
  let j = skipWs s i in
  if charAt j s == 93 then Right (JArr (reverse acc), j + 1)
  else case parseVal s j of
    Left e -> Left e
    Right pr -> case pr of
      (v, k) ->
        let m = skipWs s k in
        let c = charAt m s in
        if c == 44 then parseArr s (m + 1) (Cons v acc)
        else if c == 93 then Right (JArr (reverse (Cons v acc)), m + 1)
        else Left "expected , or ] in array"

-- object: (key,value) members accumulated reversed, then reversed at the close.
parseObj :: String -> Int -> List Member -> Either String (Json, Int)
parseObj s i acc =
  let j = skipWs s i in
  if charAt j s == 125 then Right (JObj (reverse acc), j + 1)
  else if charAt j s == 34 then
    case parseStr s j of
      Left e -> Left e
      Right kp -> case kp of
        (kv, k) -> case kv of
          JStr key ->
            let c1 = skipWs s k in
            if charAt c1 s == 58 then
              case parseVal s (c1 + 1) of
                Left e -> Left e
                Right vp -> case vp of
                  (val, k2) ->
                    let m = skipWs s k2 in
                    let c = charAt m s in
                    if c == 44 then parseObj s (m + 1) (Cons (Member key val) acc)
                    else if c == 125 then Right (JObj (reverse (Cons (Member key val) acc)), m + 1)
                    else Left "expected , or } in object"
            else Left "expected : in object"
          other -> Left "object key must be a string"
  else Left "expected string key in object"

parseJson :: String -> Either String Json
parseJson s = case parseVal s 0 of
  Left e -> Left e
  Right pr -> case pr of
    (v, _) -> Right v

-- round-trip: parse source text, re-serialize (or print the error).
roundtrip :: String -> String
roundtrip src = case parseJson src of
  Left e -> strAppend "ERROR: " e
  Right v -> showJson v

main :: IO ()
main = putStrLn (roundtrip "{\"name\":\"ax\",\"ok\":true,\"xs\":[1,2,null],\"pi\":3.5}")
