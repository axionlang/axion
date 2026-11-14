-- httpd.axi — a small HTTP/1.1 static file server. Every connection is a session task: it reads
-- the request head, decides a response from it with ordinary (pure) functions, and streams the
-- file in chunks through a linear `File` and a byte `Buffer`. Sockets and files are linear: each
-- is closed exactly once on every path, or the program does not compile. No garbage collector.
--
-- Usage:  AXHTTPD_ROOT=./site AXHTTPD_PORT=8080 axionc --release examples/httpd.axi
--   AXHTTPD_ROOT  directory to serve (default `.`)
--   AXHTTPD_PORT  TCP port (default 8080)
--   AXHTTPD_MAX   stop after this many connections (default: never; used by the tests)
-- Serves GET and HEAD. One request per connection (`Connection: close`). A path never leaves the
-- root: `..` (also as `%2e%2e`) is 403, a NUL or a malformed escape is 400. Native only.

-- ─── configuration ─────────────────────────────────────────────────────────────────────────

docRoot :: Int -> String
docRoot d = if strLen (getEnv "AXHTTPD_ROOT") == 0 then "." else getEnv "AXHTTPD_ROOT"

listenPort :: Int -> Int
listenPort d = fromMaybe 8080 (readInt (getEnv "AXHTTPD_PORT"))

-- the largest request head accepted before answering 431
maxHead :: Int -> Int
maxHead d = 8192

chunkSize :: Int -> Int
chunkSize d = 65536

-- ─── request parsing ───────────────────────────────────────────────────────────────────────

-- A parsed request line: the method and the decoded, normalized path (always starting with `/`).
data Req = Req String String

-- the bytes up to the first CR (or the end)
firstLine :: String -> String
firstLine raw = substr 0 (lineEnd raw 0) raw

lineEnd :: String -> Int -> Int
lineEnd s i = if i >= strLen s || charAt i s == 13 || charAt i s == 10 then i else lineEnd s (i + 1)

-- `True` once the head is complete (a blank line ends it)
headDone :: String -> Bool
headDone s = findFrom s "\r\n\r\n" 0 >= 0 || findFrom s "\n\n" 0 >= 0

findFrom :: String -> String -> Int -> Int
findFrom s pat i =
  if i + strLen pat > strLen s then -1
  else if substr i (strLen pat) s == pat then i
  else findFrom s pat (i + 1)

-- The response status a request gets before any file is touched (0 = go ahead), or the
-- parsed request. Each check short-circuits with `<-!`.
parseReq :: String -> Either Int Req
parseReq raw = do
  parts <-! threeWords (words (firstLine raw))
  m <-! knownMethod (pick 0 parts)
  v <-! knownVersion (pick 2 parts)
  p <-! cleanPath (stripQuery (pick 1 parts))
  Right (Req m p)

-- the n-th word, as a copy: returning the element itself would take the list (each call would
-- consume it), so `parseReq` could not pick three words from one list
pick :: Int -> List String -> String
pick n xs = case xs of
  Nil -> ""
  Cons y ys -> if n == 0 then strAppend y "" else pick (n - 1) ys

threeWords :: List String -> Either Int (List String)
threeWords ws = if length ws == 3 then Right ws else Left 400

knownMethod :: String -> Either Int String
knownMethod m = if m == "GET" || m == "HEAD" then Right m else Left 405

knownVersion :: String -> Either Int String
knownVersion v = if v == "HTTP/1.1" || v == "HTTP/1.0" then Right v else Left 505

stripQuery :: String -> String
stripQuery t = substr 0 (cutAt t 0) t

cutAt :: String -> Int -> Int
cutAt t i = if i >= strLen t || charAt i t == 63 || charAt i t == 35 then i else cutAt t (i + 1)

-- Decode `%XX`, then rebuild the path from its segments: empty and `.` segments vanish, and
-- `..` is refused (403) — so the result can never leave the document root. A NUL byte or a
-- malformed escape is a 400. The target must start with `/`.
cleanPath :: String -> Either Int String
cleanPath t = do
  slash <-! startsWithSlash t
  d <-! percentDecode t 0 ""
  segs <-! safeSegments (splitOn 47 d)
  Right (joinSegs segs (hasSuffix "/" d))

startsWithSlash :: String -> Either Int Int
startsWithSlash t = if strLen t > 0 && charAt 0 t == 47 then Right 0 else Left 400

hexVal :: Int -> Int
hexVal c =
  if c >= 48 && c <= 57 then c - 48
  else if c >= 97 && c <= 102 then c - 87
  else if c >= 65 && c <= 70 then c - 55
  else -1

percentDecode :: String -> Int -> String -> Either Int String
percentDecode t i acc =
  if i >= strLen t then Right acc
  else if charAt i t == 37 then decodeEscape t i acc
  else percentDecode t (i + 1) (strAppend acc (substr i 1 t))

decodeEscape :: String -> Int -> String -> Either Int String
decodeEscape t i acc =
  if i + 2 >= strLen t then Left 400
  else if hexVal (charAt (i + 1) t) < 0 || hexVal (charAt (i + 2) t) < 0 then Left 400
  else if hexVal (charAt (i + 1) t) * 16 + hexVal (charAt (i + 2) t) == 0 then Left 400
  else percentDecode t (i + 3) (strAppend acc (chr (hexVal (charAt (i + 1) t) * 16 + hexVal (charAt (i + 2) t))))

safeSegments :: List String -> Either Int (List String)
safeSegments segs = case segs of
  Nil -> Right Nil
  Cons s rest -> if s == ".." then Left 403 else (if s == "" || s == "." then safeSegments rest else consRight s (safeSegments rest))

consRight :: String -> Either Int (List String) -> Either Int (List String)
consRight s r = case r of
  Left e -> Left e
  Right xs -> Right (Cons s xs)

joinSegs :: List String -> Bool -> String
joinSegs segs dir = strAppend (strAppend "/" (joinWith segs)) (if dir && length segs > 0 then "/" else "")

joinWith :: List String -> String
joinWith segs = case segs of
  Nil -> ""
  Cons s rest -> if length rest == 0 then strAppend s "" else strAppend (strAppend s "/") (joinWith rest)

-- ─── the decision a session task acts on ───────────────────────────────────────────────────

-- 0 when the request may be served, else the error status to answer with
reqStatus :: String -> Int
reqStatus raw = case parseReq raw of
  Left code -> code
  Right r -> 0

-- the file to open for an accepted request (a directory path gets `index.html`)
reqFile :: String -> String
reqFile raw = case parseReq raw of
  Left code -> ""
  Right r -> case r of
    Req m p -> strAppend (docRoot 0) (if hasSuffix "/" p then strAppend p "index.html" else p)

reqIsHead :: String -> Bool
reqIsHead raw = case parseReq raw of
  Left code -> False
  Right r -> case r of
    Req m p -> m == "HEAD"

-- an errno from opening a file → the status it answers with
errnoStatus :: Int -> Int
errnoStatus e = if e == 2 || e == 20 then 404 else (if e == 13 then 403 else 500)

-- ─── responses ─────────────────────────────────────────────────────────────────────────────

reason :: Int -> String
reason code = case code of
  200 -> "OK"
  400 -> "Bad Request"
  403 -> "Forbidden"
  404 -> "Not Found"
  405 -> "Method Not Allowed"
  431 -> "Request Header Fields Too Large"
  505 -> "HTTP Version Not Supported"
  _ -> "Internal Server Error"

extension :: String -> String
extension path = toLower (baseAfterDot (baseName path))

baseAfterDot :: String -> String
baseAfterDot b = if lastIndex 46 b 0 (-1) < 0 then "" else substr (lastIndex 46 b 0 (-1) + 1) (strLen b) b

mimeType :: String -> String
mimeType path = case extension path of
  "html" -> "text/html; charset=utf-8"
  "htm" -> "text/html; charset=utf-8"
  "css" -> "text/css"
  "js" -> "text/javascript"
  "json" -> "application/json"
  "txt" -> "text/plain; charset=utf-8"
  "svg" -> "image/svg+xml"
  "png" -> "image/png"
  "jpg" -> "image/jpeg"
  "jpeg" -> "image/jpeg"
  "gif" -> "image/gif"
  "ico" -> "image/x-icon"
  "wasm" -> "application/wasm"
  "pdf" -> "application/pdf"
  _ -> "application/octet-stream"

statusLine :: Int -> String
statusLine code = strAppend (strAppend (strAppend "HTTP/1.1 " (showInt code)) " ") (reason code)

header :: Int -> String -> Int -> String
header code ctype len = concatStr
  [ statusLine code, "\r\nContent-Type: ", ctype
  , "\r\nContent-Length: ", showInt len
  , "\r\nConnection: close\r\nServer: axhttpd\r\n\r\n" ]

concatStr :: List String -> String
concatStr xs = case xs of
  Nil -> ""
  Cons s rest -> strAppend s (concatStr rest)

-- a whole error response: head and a one-line text body
errorResponse :: Int -> String
errorResponse code = strAppend (header code "text/plain; charset=utf-8" (strLen (errorBody code))) (errorBody code)

errorBody :: Int -> String
errorBody code = strAppend (strAppend (showInt code) " ") (strAppend (reason code) "\n")

okHeader :: String -> Int -> String
okHeader path size = header 200 (mimeType path) size

-- the unsent rest of `s` from `off`
from :: String -> Int -> String
from s off = substr off (strLen s - off) s

-- ─── the session tasks ─────────────────────────────────────────────────────────────────────

-- Read the request head (it may arrive in pieces), then answer.
readHead :: Sock %1 -> String -> IO ()
readHead s acc = do
  chunk <- netRecv s
  if strLen chunk == 0
    then netClose s
    else if strLen acc + strLen chunk > maxHead 0
      then sendText s (errorResponse 431) 0
      else if headDone (strAppend acc chunk)
        then respond s (strAppend acc chunk)
        else readHead s (strAppend acc chunk)

-- Decide: an early error status, or open the file.
respond :: Sock %1 -> String -> IO ()
respond s raw =
  if reqStatus raw /= 0
    then sendText s (errorResponse (reqStatus raw)) 0
    else openFile s (reqFile raw) (reqIsHead raw)

-- Open the file and check it is a regular file. Every early exit closes it.
openFile :: Sock %1 -> String -> Bool -> IO ()
openFile s path isHead = do
  let f = fileOpenRaw path
  if fileErrno f /= 0
    then do
      let code = errnoStatus (fileErrno f)
      fileClose f
      sendText s (errorResponse code) 0
    else if fileSize f < 0
      then do
        fileClose f
        sendText s (errorResponse 404) 0
      else sendHead s f (okHeader path (fileSize f)) 0 isHead

-- Send the response head (looping on partial sends), then the body.
sendHead :: Sock %1 -> File %1 -> String -> Int -> Bool -> IO ()
sendHead s f hdr off isHead =
  if off >= strLen hdr
    then (if isHead then finish s f else pump s f (fileRead f (chunkSize 0)) 0)
    else do
      n <- netSend s (from hdr off)
      if n < 0
        then finish s f
        else sendHead s f hdr (off + n) isHead

-- Stream the file: send the current chunk from `off`, read the next one when it is drained,
-- stop at end of file (an empty chunk) or when the peer goes away.
pump :: Sock %1 -> File %1 -> Buffer U8 -> Int -> IO ()
pump s f buf off =
  if bufLen buf == 0
    then finish s f
    else if off >= bufLen buf
      then pump s f (fileRead f (chunkSize 0)) 0
      else do
        n <- netSendBuf s buf off (bufLen buf - off)
        if n < 0
          then finish s f
          else pump s f buf (off + n)

finish :: Sock %1 -> File %1 -> IO ()
finish s f = do
  fileClose f
  netClose s

-- Send a whole String response, then close.
sendText :: Sock %1 -> String -> Int -> IO ()
sendText s msg off =
  if off >= strLen msg
    then netClose s
    else do
      n <- netSend s (from msg off)
      if n < 0
        then netClose s
        else sendText s msg (off + n)

handler :: Sock %1 -> IO ()
handler s = readHead s (emptyStr 0)

emptyStr :: Int -> String
emptyStr d = ""

-- Accept connections, each handled by its own task. `left` counts down the connections still to
-- serve (AXHTTPD_MAX); below zero it never reaches 0, so the server runs until killed.
serve :: Listener %1 -> Int -> IO ()
serve l left =
  if left == 0
    then netCloseL l
    else do
      s <- netAccept l
      _ <- spawn (handler s)
      serve l (left - 1)

maxConns :: Int -> Int
maxConns d = fromMaybe (-1) (readInt (getEnv "AXHTTPD_MAX"))

main :: Int
main = bound $ do
  l <- netListen (listenPort 0)
  _ <- spawn (serve l (maxConns 0))
  0
