   --> axionc/tests/fixtures/parfor_reject.axi:12:22
   --> axionc/tests/fixtures/parfor_reject.axi:16:24
   --> axionc/tests/fixtures/parfor_reject.axi:23:20
   --> axionc/tests/fixtures/parfor_reject.axi:27:46
   --> axionc/tests/fixtures/parfor_reject.axi:31:21
   --> axionc/tests/fixtures/parfor_reject.axi:38:29
   |
   |
   |
   |
   |
   |
   |                                              ^^^^^^^^^^^^^^^^ every run of the kernel would write the same array
   |                             ^^^^^^ used here without both arguments
   |                        ^^^^^^^^^^^^^^^^^^^ this kernel runs on several threads at once
   |                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ this kernel runs on several threads at once
   |                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ this kernel runs on several threads at once
   |                    ^^^^^ this kernel runs on several threads at once
  = help: the kernel runs once per element, on several threads at once, and every run sees the same captured `cap`: writing it in place is a data race. Read it (`getArray`), or build a fresh array inside the kernel.
  = help: the kernel runs once per element, on several threads, in no fixed order: it may compute, allocate and read what it captures, but not do I/O, exit, use channels or sessions, or write a Buffer or arena in place. Compute the values with `parFor`, then do the effects after it (see docs/parallel.md).
  = help: the kernel runs once per element, on several threads, in no fixed order: it may compute, allocate and read what it captures, but not do I/O, exit, use channels or sessions, or write a Buffer or arena in place. Compute the values with `parFor`, then do the effects after it (see docs/parallel.md).
  = help: the kernel runs once per element, on several threads, in no fixed order: it may compute, allocate and read what it captures, but not do I/O, exit, use channels or sessions, or write a Buffer or arena in place. Compute the values with `parFor`, then do the effects after it (see docs/parallel.md).
  = help: the kernel runs once per element, on several threads, in no fixed order: it may compute, allocate and read what it captures, but not do I/O, exit, use channels or sessions, or write a Buffer or arena in place. Compute the values with `parFor`, then do the effects after it (see docs/parallel.md).
  = help: write the call out, `parFor a (\i x -> …)`, so the kernel can be checked: a kernel must not have effects (see docs/parallel.md)
12 | direct a = parFor a (\i x -> let u = putStrLn "hi" in x)
16 | indirect a = parFor a (\i x -> viaLogged x)
23 | named a = parFor a noisy
27 | writeCap cap a = parFor a (\i x -> getArray (setArray cap 0 i) 0)
31 | quits a = parFor a (\i x -> if x < 0 then exitWith 1 else x)
38 | usesPartial a = withKernel (parFor a)
error[AX0800]: a `parFor` kernel must not have effects: it uses `exitWith`, which has effects
error[AX0800]: a `parFor` kernel must not have effects: it uses `noisy` → `logged` → `putStrLn`, which has effects
error[AX0800]: a `parFor` kernel must not have effects: it uses `putStrLn`, which has effects
error[AX0800]: a `parFor` kernel must not have effects: it uses `viaLogged` → `logged` → `putStrLn`, which has effects
error[AX0800]: a `parFor` kernel must not write what it captured: `setArray` writes `cap` in place
error[AX0801]: `parFor` must be applied to its array and its kernel
