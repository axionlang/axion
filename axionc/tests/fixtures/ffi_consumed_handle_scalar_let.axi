-- A `let` whose value consumes a linear handle but is itself a plain scalar (`let c = closeFd h + 1`)
-- does not inherit the handle's must-use class: the FFI destroyer consumed the handle and the Int
-- it returns carries nothing. (axmpv's `let c = pclose apipe + sdlClearQueued aud` was refused:
-- "must-use resource 'c' dropped".) A binding that may BE the handle still inherits it.
data Fd = Fd
foreign "libc.so.6" dupFd = "dup" :: Int -> Handle Fd
foreign "libc.so.6" closeFd = "close" :: Own (Handle Fd) -> Int

finish :: Handle Fd %1 -> Int
finish h = let c = closeFd h + 1 in c * 2

main :: IO ()
main = putStrLn (showInt (finish (dupFd 1)))
