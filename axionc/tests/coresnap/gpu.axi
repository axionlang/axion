


























                          drop _t52
                          drop _t54 : Array
                          drop _t56 : String
                          let _d1000000 = putStrLn _t56  ; Δ{_t56}
                          let _t51 = newArray 20 0  ; Δ{} · makes Array
                          let _t52 = closure lam$9  ; Δ{_t51} · makes Closure
                          let _t53 = rtcall axion_par_for _t51 _t52  ; Δ{_t51 _t52}
                          let _t54 = _t51  ; Δ{_t51} · moves{_t51}
                          let _t55 = call sumA _t54 0 0  ; Δ{}
                          let _t56 = showInt _t55  ; Δ{} · makes String
                          ret _d1000000  ; Δ{}
                        _ ->
                      drop _t45
                      drop _t47 : Array
                      drop _t49 : String
                      let _t44 = newArray 0 0  ; Δ{} · makes Array
                      let _t45 = closure lam$8  ; Δ{_t44} · makes Closure
                      let _t46 = rtcall axion_gpu_for _t44 _t45  ; Δ{_t44 _t45}
                      let _t47 = _t44  ; Δ{_t44} · moves{_t44}
                      let _t48 = rtcall axion_array_len _t47  ; Δ{}
                      let _t49 = showInt _t48  ; Δ{} · makes String
                      let _t50 = putStrLn _t49  ; Δ{_t49}
                      ret case _t50 of
                    _ ->
                  drop _t38
                  drop _t40 : Array
                  drop _t42 : String
                  let _t36 = 0  ; Δ{}
                  let _t37 = newArray 5000 _t36  ; Δ{} · makes Array
                  let _t38 = closure lam$7  ; Δ{_t37} · makes Closure
                  let _t39 = rtcall axion_gpu_for _t37 _t38  ; Δ{_t37 _t38}
                  let _t40 = _t37  ; Δ{_t37} · moves{_t37}
                  let _t41 = call countTrue _t40 0 0  ; Δ{}
                  let _t42 = showInt _t41  ; Δ{} · makes String
                  let _t43 = putStrLn _t42  ; Δ{_t42}
                  ret case _t43 of
                _ ->
              drop _t30
              drop _t32 : Array
              drop _t34 : String
              drop w : Array
              let _t29 = newArray 64 0  ; Δ{w} · makes Array
              let _t30 = closure lam$6 off w  ; Δ{_t29 w} · makes Closure
              let _t31 = rtcall axion_gpu_for _t29 _t30  ; Δ{_t29 _t30 w}
              let _t32 = _t29  ; Δ{_t29} · moves{_t29}
              let _t33 = call sumA _t32 0 0  ; Δ{}
              let _t34 = showInt _t33  ; Δ{} · makes String
              let _t35 = putStrLn _t34  ; Δ{_t34}
              let off = rtcall axion_str_len "abc"  ; Δ{w}
              let w = rtcall axion_array_iota 64  ; Δ{} · makes Array
              ret case _t35 of
            _ ->
          drop _t22
          drop _t25 : Array
          drop _t27 : String
          let _t21 = rtcall axion_array_iota 1000  ; Δ{} · makes Array
          let _t22 = closure lam$5  ; Δ{_t21} · makes Closure
          let _t23 = rtcall axion_gpu_for _t21 _t22  ; Δ{_t21 _t22}
          let _t24 = _t21  ; Δ{_t21} · moves{_t21}
          let _t25 = call doubleAll _t24  ; Δ{} · makes Array
          let _t26 = call sumA _t25 0 0  ; Δ{_t25}
          let _t27 = showInt _t26  ; Δ{} · makes String
          let _t28 = putStrLn _t27  ; Δ{_t27}
          ret case _t28 of
        _ ->
      drop _t15
      drop _t17 : Array
      drop _t19 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t1 = + j 1  ; Δ{}
      let _t14 = newArray 100000 0  ; Δ{} · makes Array
      let _t15 = closure lam$4  ; Δ{_t14} · makes Closure
      let _t16 = rtcall axion_gpu_for _t14 _t15  ; Δ{_t14 _t15}
      let _t17 = _t14  ; Δ{_t14} · moves{_t14}
      let _t18 = call sumA _t17 0 0  ; Δ{}
      let _t19 = showInt _t18  ; Δ{} · makes String
      let _t2 = * r n  ; Δ{}
      let _t20 = putStrLn _t19  ; Δ{_t19}
      let _t3 = + _t2 j  ; Δ{}
      let _t3 = div n 2  ; Δ{}
      let _t4 = + steps 1  ; Δ{}
      let _t4 = rtcall axion_array_get m _t3  ; Δ{}
      let _t5 = * 3 n  ; Δ{}
      let _t5 = rtcall axion_array_get v j  ; Δ{}
      let _t6 = *. _t4 _t5  ; Δ{}
      let _t6 = + _t5 1  ; Δ{}
      let _t7 = + steps 1  ; Δ{}
      let _t7 = +. acc _t6  ; Δ{}
      ret + acc 1  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret acc  ; Δ{}
      ret acc  ; Δ{}
      ret call collatz _t3 _t4  ; Δ{}
      ret call collatz _t6 _t7  ; Δ{}
      ret call dotRow m v n r _t1 _t7  ; Δ{}
      ret case _t20 of
    _ ->
    drop _t10 : String
    drop _t11 : String
    drop _t12 : String
    drop _t5 : String
    drop _t7 : String
    drop _t8 : String
    drop _t9 : String
    else
    else
    else
    else
    let _d1000000 = rtcall axion_contract_fail _t12  ; Δ{_t12}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t0 = call >=$Int j n  ; Δ{}
    let _t1 = + j 1  ; Δ{}
    let _t1 = mod n 2  ; Δ{}
    let _t10 = showInt contract$a1  ; Δ{_t9} · makes String
    let _t11 = rtcall axion_strcat _t9 _t10  ; Δ{_t10 _t9} · makes String
    let _t12 = rtcall axion_strcat _t11 "), called from `main`"  ; Δ{_t11} · makes String
    let _t2 = * r n  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = == _t1 0  ; Δ{}
    let _t3 = + _t2 j  ; Δ{}
    let _t3 = rtcall axion_array_get a i  ; Δ{}
    let _t3 = rtcall axion_array_get a i  ; Δ{}
    let _t3 = rtcall axion_array_get a i  ; Δ{}
    let _t3 = rtcall axion_array_len w  ; Δ{}
    let _t4 = + acc _t3  ; Δ{}
    let _t4 = +. acc _t3  ; Δ{}
    let _t4 = if _t3 then
    let _t4 = rtcall axion_array_get_nobc m _t3  ; Δ{}
    let _t5 = rtcall axion_array_get_nobc v j  ; Δ{}
    let _t5 = rtcall axion_strcat "axion: contract violated: `pick` requires `0 <= i && i < (len a)`" " (len a = "  ; Δ{} · makes String
    let _t6 = *. _t4 _t5  ; Δ{}
    let _t6 = rtcall axion_array_len w  ; Δ{_t5}
    let _t7 = +. acc _t6  ; Δ{}
    let _t7 = showInt _t6  ; Δ{_t5} · makes String
    let _t8 = rtcall axion_strcat _t5 _t7  ; Δ{_t5 _t7} · makes String
    let _t9 = rtcall axion_strcat _t8 ", i = "  ; Δ{_t8} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret < contract$a1 _t3  ; Δ{}
    ret == x y  ; Δ{}
    ret _d1000000  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret call countTrue a _t2 _t4  ; Δ{}
    ret call dotRow$bce m v n r _t1 _t7  ; Δ{}
    ret call dotRow$bce m v n r j acc  ; Δ{}
    ret call pick w contract$a1  ; Δ{}
    ret call sumA a _t2 _t4  ; Δ{}
    ret call sumF a _t2 _t4  ; Δ{}
    ret if _t0 then
    ret if _t2 then
    ret steps  ; Δ{}
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0
  drop _t1
  drop _t10 : Array
  drop _t12 : String
  drop _t2
  drop _t3 : Array
  drop _t5
  drop _t8
  drop m : Array
  drop v : Array
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
  let $bce1 = > j -1  ; Δ{}
  let $bce10 = > 1 0  ; Δ{}
  let $bce11 = band $bce9 $bce10  ; Δ{}
  let $bce12 = * 1 $bce10  ; Δ{}
  let $bce13 = - 1 $bce10  ; Δ{}
  let $bce14 = + $bce12 $bce13  ; Δ{}
  let $bce15 = - $bce7 1  ; Δ{}
  let $bce16 = div $bce15 $bce14  ; Δ{}
  let $bce17 = + $bce16 2  ; Δ{}
  let $bce18 = > $bce17 n  ; Δ{}
  let $bce19 = band $bce11 $bce18  ; Δ{}
  let $bce2 = rtcall axion_array_len m  ; Δ{}
  let $bce20 = rtcall axion_array_len v  ; Δ{}
  let $bce21 = > 0 -1  ; Δ{}
  let $bce22 = band $bce19 $bce21  ; Δ{}
  let $bce23 = - $bce20 0  ; Δ{}
  let $bce24 = > $bce23 0  ; Δ{}
  let $bce25 = band $bce22 $bce24  ; Δ{}
  let $bce26 = > 1 0  ; Δ{}
  let $bce27 = band $bce25 $bce26  ; Δ{}
  let $bce28 = * 1 $bce26  ; Δ{}
  let $bce29 = - 1 $bce26  ; Δ{}
  let $bce3 = * r n  ; Δ{}
  let $bce30 = + $bce28 $bce29  ; Δ{}
  let $bce31 = - $bce23 1  ; Δ{}
  let $bce32 = div $bce31 $bce30  ; Δ{}
  let $bce33 = + $bce32 2  ; Δ{}
  let $bce34 = > $bce33 n  ; Δ{}
  let $bce35 = band $bce27 $bce34  ; Δ{}
  let $bce4 = + $bce3 0  ; Δ{}
  let $bce5 = > $bce4 -1  ; Δ{}
  let $bce6 = band $bce1 $bce5  ; Δ{}
  let $bce7 = - $bce2 $bce4  ; Δ{}
  let $bce8 = > $bce7 0  ; Δ{}
  let $bce9 = band $bce6 $bce8  ; Δ{}
  let _d1000000 = call sumA _t3 0 0  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = * i 7  ; Δ{}
  let _t0 = * n n  ; Δ{}
  let _t0 = * x 3  ; Δ{}
  let _t0 = + i 1  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = call <=$Int n 1  ; Δ{}
  let _t0 = call >=$Int j n  ; Δ{}
  let _t0 = call pick w i  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes Closure
  let _t0 = mod i 7  ; Δ{}
  let _t0 = mod k 9  ; Δ{}
  let _t0 = newArray r 1  ; Δ{} · makes Array
  let _t0 = rtcall axion_array_len a  ; Δ{}
  let _t0 = rtcall axion_array_len a  ; Δ{}
  let _t0 = rtcall axion_array_len a  ; Δ{}
  let _t0 = toFloat j  ; Δ{}
  let _t1 = + i off  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call mix$h i  ; Δ{}
  let _t1 = closure lam$10  ; Δ{_t0} · makes Closure
  let _t1 = newArray _t0 0f  ; Δ{} · makes Array
  let _t1 = rtcall axion_gpu_for a _t0  ; Δ{_t0}
  let _t1 = toFloat _t0  ; Δ{}
  let _t10 = _t7  ; Δ{_t7} · moves{_t7}
  let _t11 = call sumF _t10 0 0f  ; Δ{}
  let _t12 = rtcall axion_show_float _t11  ; Δ{} · makes String
  let _t13 = if _t4 then
  let _t13 = putStrLn _t12  ; Δ{_t12}
  let _t2 = call <=$Int 0 contract$a1  ; Δ{}
  let _t2 = closure lam$1  ; Δ{_t1} · makes Closure
  let _t2 = rtcall axion_gpu_for _t0 _t1  ; Δ{_t0 _t1}
  let _t3 = _t0  ; Δ{_t0} · moves{_t0}
  let _t3 = rtcall axion_par_for _t1 _t2  ; Δ{_t1 _t2}
  let _t4 = if _t2 then
  let _t4 = newArray n 0f  ; Δ{} · makes Array
  let _t5 = closure lam$2  ; Δ{_t4} · makes Closure
  let _t6 = rtcall axion_par_for _t4 _t5  ; Δ{_t4 _t5}
  let _t7 = newArray n 0f  ; Δ{} · makes Array
  let _t8 = closure lam$3 m n v  ; Δ{_t7} · makes Closure
  let _t9 = rtcall axion_gpu_for _t7 _t8  ; Δ{_t7 _t8}
  let contract$a1 = mod _t1 64  ; Δ{}
  let m = _t1  ; Δ{_t1} · moves{_t1}
  let n = 200  ; Δ{}
  let v = _t4  ; Δ{_t4} · moves{_t4}
  ret * x 2  ; Δ{}
  ret *. _t0 0.25f  ; Δ{}
  ret + _t0 _t1  ; Δ{}
  ret + _t0 _t13  ; Δ{}
  ret + x i  ; Δ{}
  ret + x j  ; Δ{}
  ret -. _t1 4f  ; Δ{}
  ret 0  ; Δ{}
  ret == _t0 3  ; Δ{}
  ret _d1000000  ; Δ{}
  ret a  ; Δ{}
  ret call collatz _t0 0  ; Δ{}
  ret call dotRow m v n r 0 0f  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call mix eta$1 eta$2  ; Δ{}
  ret case _t13 of
  ret if $bce35 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret mod _t0 11  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_array_get_nobc a i  ; Δ{}
<=$Int x y  =
>=$Int x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
collatz n steps  =
countTrue a i acc  =
dotRow m v n r j acc  =
dotRow$bce m v n r j acc  =
doubleAll a  =
lam$0 [env ]_w0 x  =
lam$1 [env ]k _w1  =
lam$10 [env ]j x  =
lam$2 [env ]j _w1  =
lam$3 [env m n v]r _w1  =
lam$4 [env ]i _w1  =
lam$5 [env ]eta$1 eta$2  =
lam$6 [env off w]i _w1  =
lam$7 [env ]i _w1  =
lam$8 [env ]i x  =
lam$9 [env ]r _w1  =
le$Int x y  =
main  =
mix i x  =
mix$h i  =
pick a i  =
sumA a i acc  =
sumF a i acc  =
