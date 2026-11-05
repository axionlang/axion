-- ffi_handle.axi — linear FFI resource handles (§18). `Handle a` is a must-use linear type: a
-- handle must be destroyed EXACTLY ONCE on every path — forgetting is AX0002, double-destroy AX0001,
-- use-after-destroy AX0004. The creating FFI returns an owned handle; a read-only op `Borrow`s it;
-- the destroying FFI `Own`s it (consumes). Here a handle is threaded through a recursive loop that
-- either keeps looping (moving the handle on) or quits (destroying it) — both consume it once, so
-- the linear checker proves no leak and no double-destroy across the branch (the echoserver pattern
-- applied to C handles). Compile-/verify-checked only (the C symbols are an unsafe-island contract).

data Dev = Dev

foreign "lib.so" openDev  = "c_open"  :: Int -> Handle Dev
foreign "lib.so" pollDev  = "c_poll"  :: Borrow (Handle Dev) -> Int
foreign "lib.so" closeDev = "c_close" :: Own (Handle Dev) -> Int

-- loop `n` times, reading the device each step (borrow), then close it exactly once at the end.
run :: Handle Dev %1 -> Int -> Int
run h n =
  if n == 0 then closeDev h            -- quit path: consume the handle
  else let _ = pollDev h in run h (n - 1)  -- keep-going path: borrow, then move into the recursion

main :: IO ()
main = putStrLn (showInt (run (openDev 7) 3))
