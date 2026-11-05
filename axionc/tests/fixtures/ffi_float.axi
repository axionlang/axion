-- ffi_float.axi — FFI float arguments and results (§18). A `Float` crosses the C ABI as a `double`
-- in an FP register (not the i64 integer path): Axión's Float is the f64 bit-pattern, so the
-- backends bitcast at the boundary. Calls into libm: cos 0 = 1, sqrt 4 = 2, pow 2 10 = 1024.
-- Native-only (the FFI island); run via cranelift/llvm, which dlopen/link libm.

foreign "libm.so.6" c_cos = "cos" :: Float -> Float
foreign "libm.so.6" c_sqrt = "sqrt" :: Float -> Float
foreign "libm.so.6" c_pow = "pow" :: Float -> Float -> Float

main :: IO ()
main = do
  putStrLn (showFloat (c_cos 0.0))
  putStrLn (showFloat (c_sqrt 4.0))
  putStrLn (showFloat (c_pow 2.0 10.0))
