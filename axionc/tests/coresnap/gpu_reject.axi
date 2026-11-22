   --> axionc/tests/fixtures/gpu_reject.axi:13:11
   --> axionc/tests/fixtures/gpu_reject.axi:16:33
   --> axionc/tests/fixtures/gpu_reject.axi:28:34
   --> axionc/tests/fixtures/gpu_reject.axi:33:21
   --> axionc/tests/fixtures/gpu_reject.axi:40:25
   |
   |
   |
   |
   |
   |
   |
   |
   |
   |                                  ^^^^^^^ this cannot run on the GPU
   |                                 ^ this cannot run on the GPU
   |                         ^^^^^^ used here without both arguments
   |                         ^^^^^^^^^^^ in this kernel
   |                      ^^^^^^^^^^^^^^^^^^^ in this kernel
   |                      ^^^^^^^^^^^^^^^^^^^^^^^ in this kernel
   |                     ^ in this kernel
   |                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ this kernel runs on several threads at once
   |           ^^^^^^ this cannot run on the GPU
  --> axionc/tests/fixtures/gpu_reject.axi:9:3
  = help: a GPU kernel computes with `Int`, `Float` and `Bool` values: arithmetic, comparisons, `if`, `case` on numbers, `let`, `getArray`/`lenArray` on the arrays it captures, and calls to functions that do the same. It cannot use strings, lists, tuples, records or other `data` values, or function values. Use `parFor` for a kernel that needs them (see docs/gpu.md).
  = help: a GPU kernel computes with `Int`, `Float` and `Bool` values: arithmetic, comparisons, `if`, `case` on numbers, `let`, `getArray`/`lenArray` on the arrays it captures, and calls to functions that do the same. It cannot use strings, lists, tuples, records or other `data` values, or function values. Use `parFor` for a kernel that needs them (see docs/gpu.md).
  = help: a GPU kernel computes with `Int`, `Float` and `Bool` values: arithmetic, comparisons, `if`, `case` on numbers, `let`, `getArray`/`lenArray` on the arrays it captures, and calls to functions that do the same. It cannot use strings, lists, tuples, records or other `data` values, or function values. Use `parFor` for a kernel that needs them (see docs/gpu.md).
  = help: a GPU kernel computes with `Int`, `Float` and `Bool` values: arithmetic, comparisons, `if`, `case` on numbers, `let`, `getArray`/`lenArray` on the arrays it captures, and calls to functions that do the same. It cannot use strings, lists, tuples, records or other `data` values, or function values. Use `parFor` for a kernel that needs them (see docs/gpu.md).
  = help: the kernel runs once per element, on several threads, in no fixed order: it may compute, allocate and read what it captures, but not do I/O, exit, use channels or sessions, or write a Buffer or arena in place. Compute the values with `parFor`, then do the effects after it (see docs/parallel.md).
  = help: write the call out, `gpuFor a (\i x -> …)`, so the kernel can be checked: a kernel must not have effects (see docs/parallel.md)
  |
  |   ^^^^^^^^^ this cannot run on the GPU
13 | label i = strLen (showInt i)
16 | applyTo f a = gpuFor a (\i x -> f x)
16 | applyTo f a = gpuFor a (\i x -> f x)
20 | shapes a = gpuFor a (\i x -> area (Circle x))
24 | labels a = gpuFor a (\i x -> label x + 1)
28 | pairs a = gpuFor a (\i x -> case (i, x) of
28 | pairs a = gpuFor a (\i x -> case (i, x) of
33 | noisy a = gpuFor a (\i x -> let u = putStrLn "x" in x)
40 | partial a = withKernel (gpuFor a)
9 |   Circle r -> 3 * r * r
error[AX0800]: a `gpuFor` kernel must not have effects: it uses `putStrLn`, which has effects
error[AX0801]: `gpuFor` must be applied to its array and its kernel
error[AX0802]: a `gpuFor` kernel must run on the GPU: it uses `strLen`, which cannot run on the GPU, in `label`
error[AX0802]: a `gpuFor` kernel must run on the GPU: it uses a call through the function value `f`
error[AX0802]: a `gpuFor` kernel must run on the GPU: it uses a pattern on the data value `Circle`, in `area`
error[AX0802]: a `gpuFor` kernel must run on the GPU: it uses a tuple
