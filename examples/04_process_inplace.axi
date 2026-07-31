-- Target program 4/5 — L1 inferred Auto-Drop + in-place mutation (Listing 2.1).
-- Phase 1 success: a record with an embedded linear field; the last live mention
-- of 'p' becomes an in-place mutation of the field; if 'p'' were not returned,
-- Auto-Drop would insert free(p'.buffer).

data Process = Process
  { pid    :: Int
  , status :: String
  , buffer :: Buffer U8 %1     -- linear field embedded in the record
  }

-- 'p' is consumed (%1) and returned (%1): ownership goes in and out, never cloned.
updateKernel :: Process %1 -> Process %1
updateKernel p =
  let p' = p { status = "Running" }   -- last live mention of 'p'
  in  p'
  -- 1. The inner buffer is never copied (borrow elision).
  -- 2. 'p' dies here -> the compiler MUTATES the 'status' field in-place.
  -- 3. If 'p'' were not returned, Auto-Drop would insert free(p'.buffer).
