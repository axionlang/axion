-- Typestate on a foreign resource: the phantom parameter of `Handle` names the protocol state, so
-- each step is only callable in the right state, every state transition consumes the old handle,
-- and the session must end in `closeS`. Compile-checked (the C symbols are stand-ins); the test
-- `typestate_handle_enforces_the_protocol` plants each mistake. See docs/ownership.md.
data Disconnected = Disconnected
data Connected = Connected
data Ready = Ready

foreign "libc.so.6" openS = "abs" :: Int -> Handle Disconnected
foreign "libc.so.6" connectS = "abs" :: Own (Handle Disconnected) -> Handle Connected
foreign "libc.so.6" authS = "abs" :: Own (Handle Connected) -> Handle Ready
foreign "libc.so.6" sendS = "abs" :: Borrow (Handle Ready) -> Int
foreign "libc.so.6" closeS = "abs" :: Own (Handle Ready) -> Int

session :: Int -> Int
session n = let s = authS (connectS (openS n)) in sendS s + sendS s + closeS s

main :: Int
main = 0
