



















        let _t4 = + i 1  ; Δ{}
        ret call printSol x n _t4  ; Δ{}
      _ ->
      drop _t2 : String
      let _d1000000 = putStrLn _t2  ; Δ{_t2}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t1 = call resid a x n 0 0f  ; Δ{}
      let _t2 = call verdict _t1  ; Δ{} · makes String
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{}
      ret best  ; Δ{}
      ret i  ; Δ{}
    _ ->
    drop _t2 : String
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + k 1  ; Δ{m1}
    let _t1 = call ix n i j  ; Δ{}
    let _t1 = call ix n i j  ; Δ{}
    let _t1 = call ix n i k  ; Δ{}
    let _t1 = call ix n i k  ; Δ{}
    let _t1 = call ix n i n  ; Δ{}
    let _t1 = call ix n r1 j  ; Δ{}
    let _t1 = call rowSum a x n i 0 0f  ; Δ{}
    let _t1 = rtcall axion_array_get x i  ; Δ{}
    let _t2 = + k 1  ; Δ{m2}
    let _t2 = call ix n i n  ; Δ{}
    let _t2 = call ix n k j  ; Δ{}
    let _t2 = call ix n r2 j  ; Δ{}
    let _t2 = rtcall axion_array_get m _t1  ; Δ{}
    let _t2 = rtcall axion_array_get m _t1  ; Δ{}
    let _t2 = rtcall axion_array_get m _t1  ; Δ{}
    let _t2 = rtcall axion_array_get m _t1  ; Δ{}
    let _t2 = rtcall axion_show_float _t1  ; Δ{} · makes String
    let _t3 = + i 1  ; Δ{}
    let _t3 = call ix n best k  ; Δ{}
    let _t3 = call ix n i j  ; Δ{}
    let _t3 = call ix n k k  ; Δ{}
    let _t3 = call ix n r1 j  ; Δ{}
    let _t3 = putStrLn _t2  ; Δ{_t2}
    let _t3 = rtcall axion_array_get a _t2  ; Δ{}
    let _t3 = rtcall axion_array_get x j  ; Δ{}
    let _t4 = *. factor mkj  ; Δ{}
    let _t4 = + i 1  ; Δ{}
    let _t4 = + j 1  ; Δ{}
    let _t4 = call ix n r2 j  ; Δ{m1}
    let _t4 = call rowSum m x n i _t3 0f  ; Δ{}
    let _t4 = rtcall axion_array_get m _t3  ; Δ{}
    let _t4 = rtcall axion_array_get m _t3  ; Δ{}
    let _t5 = *. d d  ; Δ{}
    let _t5 = + i 1  ; Δ{m1}
    let _t5 = + j 1  ; Δ{m2}
    let _t5 = +. acc term  ; Δ{}
    let _t5 = -. mij _t4  ; Δ{}
    let _t5 = >. cur bst  ; Δ{}
    let _t5 = call ix n i i  ; Δ{}
    let _t6 = + i 1  ; Δ{}
    let _t6 = + j 1  ; Δ{m1}
    let _t6 = +. acc _t5  ; Δ{}
    let _t6 = rtcall axion_array_get m _t5  ; Δ{}
    let _t7 = - i 1  ; Δ{x2}
    let _tag = loadraw _p+0  ; Δ{}
    let best2 = if _t5 then
    let bst = call fabs _t4  ; Δ{}
    let cur = call fabs _t2  ; Δ{}
    let d = -. _t1 _t3  ; Δ{}
    let factor = /. _t2 _t4  ; Δ{}
    let m1 = call elimRow m n k i k factor  ; Δ{} · makes Array
    let m1 = call swapRow m n k p 0  ; Δ{} · makes Array
    let m1 = rtcall axion_array_set m _t3 _t5  ; Δ{} · makes Array
    let m1 = rtcall axion_array_set m _t3 v2  ; Δ{} · makes Array
    let m2 = call elimBelow m1 n k _t1  ; Δ{m1} · moves{m1} · makes Array
    let m2 = rtcall axion_array_set m1 _t4 v1  ; Δ{m1} · moves{m1} · makes Array
    let mij = rtcall axion_array_get m _t1  ; Δ{}
    let mkj = rtcall axion_array_get m _t2  ; Δ{}
    let p = call argmaxCol m n k k k  ; Δ{}
    let s = -. _t2 _t4  ; Δ{}
    let term = *. _t2 _t3  ; Δ{}
    let v1 = rtcall axion_array_get m _t1  ; Δ{}
    let v2 = rtcall axion_array_get m _t2  ; Δ{}
    let x2 = rtcall axion_array_set x i xi  ; Δ{} · makes Array
    let xi = /. s _t6  ; Δ{}
    ret "FAIL"  ; Δ{}
    ret "ok"  ; Δ{}
    ret -. 0f x  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret best  ; Δ{}
    ret call argmaxCol m n k _t6 best2  ; Δ{}
    ret call backsub m x2 n _t7  ; Δ{x2} · moves{x2} · makes Array
    ret call elimBelow m1 n k _t5  ; Δ{m1} · moves{m1} · makes Array
    ret call elimRow m1 n k i _t6 factor  ; Δ{m1} · moves{m1} · makes Array
    ret call forward m2 n _t2  ; Δ{m2} · moves{m2} · makes Array
    ret call resid a x n _t4 _t6  ; Δ{}
    ret call rowSum m x n i _t4 _t5  ; Δ{}
    ret call swapRow m2 n r1 r2 _t5  ; Δ{m2} · moves{m2} · makes Array
    ret case _t3 of
    ret m  ; Δ{}
    ret m  ; Δ{}
    ret m  ; Δ{}
    ret m  ; Δ{}
    ret putStr ""  ; Δ{}
    ret x  ; Δ{}
    ret x  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t3 : Array
  drop m : Array
  drop x : Array
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = call report _t3 x n  ; Δ{_t3 x}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = + n 1  ; Δ{}
  let _t0 = + n 1  ; Δ{}
  let _t0 = < i 0  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = <. r 0.000001f  ; Δ{}
  let _t0 = <. x 0f  ; Δ{}
  let _t0 = > j n  ; Δ{}
  let _t0 = > j n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int j n  ; Δ{}
  let _t0 = call >=$Int k n  ; Δ{}
  let _t0 = call build n  ; Δ{} · makes Array
  let _t0 = call ix n i j  ; Δ{}
  let _t0 = call printSol x n 0  ; Δ{}
  let _t1 = * i _t0  ; Δ{}
  let _t1 = * n _t0  ; Δ{}
  let _t1 = newArray n 0f  ; Δ{m} · makes Array
  let _t2 = - n 1  ; Δ{_t1 m}
  let _t2 = -. 0f 1f  ; Δ{m$2}
  let _t3 = -. 0f 3f  ; Δ{m$4}
  let _t3 = call build n  ; Δ{x} · makes Array
  let _t4 = -. 0f 1f  ; Δ{m$5}
  let _t5 = -. 0f 11f  ; Δ{m$7}
  let _t6 = -. 0f 2f  ; Δ{m$8}
  let _t7 = -. 0f 3f  ; Δ{m$11}
  let m = call forward _t0 n 0  ; Δ{_t0} · moves{_t0} · makes Array
  let m = newArray _t1 0f  ; Δ{} · makes Array
  let m$1 = call put m n 0 0 2f  ; Δ{m} · moves{m} · makes Array
  let m$10 = call put m$9 n 2 1 1f  ; Δ{m$9} · moves{m$9} · makes Array
  let m$11 = call put m$10 n 2 2 2f  ; Δ{m$10} · moves{m$10} · makes Array
  let m$2 = call put m$1 n 0 1 1f  ; Δ{m$1} · moves{m$1} · makes Array
  let m$3 = call put m$2 n 0 2 _t2  ; Δ{m$2} · moves{m$2} · makes Array
  let m$4 = call put m$3 n 0 3 8f  ; Δ{m$3} · moves{m$3} · makes Array
  let m$5 = call put m$4 n 1 0 _t3  ; Δ{m$4} · moves{m$4} · makes Array
  let m$6 = call put m$5 n 1 1 _t4  ; Δ{m$5} · moves{m$5} · makes Array
  let m$7 = call put m$6 n 1 2 2f  ; Δ{m$6} · moves{m$6} · makes Array
  let m$8 = call put m$7 n 1 3 _t5  ; Δ{m$7} · moves{m$7} · makes Array
  let m$9 = call put m$8 n 2 0 _t6  ; Δ{m$8} · moves{m$8} · makes Array
  let n = 3  ; Δ{}
  let x = call backsub m _t1 n _t2  ; Δ{_t1 m} · moves{_t1} · makes Array
  ret + _t1 j  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call put m$11 n 2 3 _t7  ; Δ{m$11} · moves{m$11} · makes Array
  ret case _t0 of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_array_set m _t0 v  ; Δ{} · makes Array
>=$Int x y  =
argmaxCol m n k i best  =
axion_drop_Array _p  =
axion_drop_List _p  =
backsub m x n i  =
build n  =
elimBelow m n k i  =
elimRow m n k i j factor  =
fabs x  =
forward m n k  =
ix n i j  =
le$Int x y  =
main  =
printSol x n i  =
put m n i j v  =
report a x n  =
resid a x n i acc  =
rowSum m x n i j acc  =
swapRow m n r1 r2 j  =
verdict r  =
