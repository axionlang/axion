



























                      drop _t39
                      drop _t41 : Array
                      drop _t43 : String
                      let _d1000000 = putStrLn _t43  ; Δ{_t43}
                      let _t37 = 0  ; Δ{}
                      let _t38 = newArray 1000 _t37  ; Δ{} · makes Array
                      let _t39 = closure lam$8  ; Δ{_t38} · makes Closure
                      let _t40 = rtcall axion_par_for _t38 _t39  ; Δ{_t38 _t39}
                      let _t41 = _t38  ; Δ{_t38} · moves{_t38}
                      let _t42 = call countTrue _t41 0 0  ; Δ{}
                      let _t43 = showInt _t42  ; Δ{} · makes String
                      ret _d1000000  ; Δ{}
                    _ ->
                  drop _t31
                  drop _t33 : Array
                  drop _t35 : String
                  let _t30 = newArray 300 0  ; Δ{} · makes Array
                  let _t31 = closure lam$7  ; Δ{_t30} · makes Closure
                  let _t32 = rtcall axion_par_for _t30 _t31  ; Δ{_t30 _t31}
                  let _t33 = _t30  ; Δ{_t30} · moves{_t30}
                  let _t34 = call sumA _t33 0 0  ; Δ{}
                  let _t35 = showInt _t34  ; Δ{} · makes String
                  let _t36 = putStrLn _t35  ; Δ{_t35}
                  ret case _t36 of
                _ ->
              drop _t26 : Array
              drop _t28 : String
              let _t26 = call tabulate$$hoflamcap0 k 500  ; Δ{} · makes Array
              let _t27 = call sumA _t26 0 0  ; Δ{_t26}
              let _t28 = showInt _t27  ; Δ{} · makes String
              let _t29 = putStrLn _t28  ; Δ{_t28}
              let k = 7  ; Δ{}
              ret case _t29 of
            _ ->
          drop _t19
          drop _t22 : Array
          drop _t24 : String
          let _t18 = rtcall axion_array_iota 1000  ; Δ{} · makes Array
          let _t19 = closure lam$6  ; Δ{_t18} · makes Closure
          let _t20 = rtcall axion_par_for _t18 _t19  ; Δ{_t18 _t19}
          let _t21 = _t18  ; Δ{_t18} · moves{_t18}
          let _t22 = call scale _t21  ; Δ{} · makes Array
          let _t23 = call sumA _t22 0 0  ; Δ{_t22}
          let _t24 = showInt _t23  ; Δ{} · makes String
          let _t25 = putStrLn _t24  ; Δ{_t24}
          ret case _t25 of
        _ ->
      drop _t12
      drop _t14 : Array
      drop _t16 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t1 = + j 1  ; Δ{}
      let _t11 = newArray 20000 0  ; Δ{} · makes Array
      let _t12 = closure lam$5  ; Δ{_t11} · makes Closure
      let _t13 = rtcall axion_par_for _t11 _t12  ; Δ{_t11 _t12}
      let _t14 = _t11  ; Δ{_t11} · moves{_t11}
      let _t15 = call sumA _t14 0 0  ; Δ{}
      let _t16 = showInt _t15  ; Δ{} · makes String
      let _t17 = putStrLn _t16  ; Δ{_t16}
      let _t2 = * r n  ; Δ{}
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
      ret case _t17 of
    _ ->
    else
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t0 = call >=$Int j n  ; Δ{}
    let _t1 = + j 1  ; Δ{}
    let _t1 = mod n 2  ; Δ{}
    let _t2 = * r n  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = == _t1 0  ; Δ{}
    let _t3 = + _t2 j  ; Δ{}
    let _t3 = rtcall axion_array_get a i  ; Δ{}
    let _t3 = rtcall axion_array_get a i  ; Δ{}
    let _t3 = rtcall axion_array_get a i  ; Δ{}
    let _t4 = + acc _t3  ; Δ{}
    let _t4 = +. acc _t3  ; Δ{}
    let _t4 = if _t3 then
    let _t4 = rtcall axion_array_get_nobc m _t3  ; Δ{}
    let _t5 = rtcall axion_array_get_nobc v j  ; Δ{}
    let _t6 = *. _t4 _t5  ; Δ{}
    let _t7 = +. acc _t6  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret call countTrue a _t2 _t4  ; Δ{}
    ret call dotRow$bce m v n r _t1 _t7  ; Δ{}
    ret call dotRow$bce m v n r j acc  ; Δ{}
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
  drop _t0
  drop _t1
  drop _t1
  drop _t2
  drop _t2
  drop _t4 : Array
  drop _t5
  drop _t7 : Array
  drop _t9 : String
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
  let _d1000000 = call sumA _t4 0 0  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = * n n  ; Δ{}
  let _t0 = * x 2  ; Δ{}
  let _t0 = + i 1  ; Δ{}
  let _t0 = + r 1  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = call <=$Int n 1  ; Δ{}
  let _t0 = call >=$Int j n  ; Δ{}
  let _t0 = closure lam$1  ; Δ{} · makes Closure
  let _t0 = mod i 3  ; Δ{}
  let _t0 = mod k 7  ; Δ{}
  let _t0 = newArray n 0  ; Δ{} · makes Array
  let _t0 = newArray n 0f  ; Δ{} · makes Array
  let _t0 = rtcall axion_array_len a  ; Δ{}
  let _t0 = rtcall axion_array_len a  ; Δ{}
  let _t0 = rtcall axion_array_len a  ; Δ{}
  let _t0 = toFloat j  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = closure lam$0 m n v  ; Δ{_t0} · makes Closure
  let _t1 = closure lam$9 _cap0  ; Δ{_t0} · makes Closure
  let _t1 = newArray _t0 0  ; Δ{} · makes Array
  let _t1 = newArray _t0 0f  ; Δ{} · makes Array
  let _t1 = rtcall axion_par_for a _t0  ; Δ{_t0}
  let _t1 = toFloat _t0  ; Δ{}
  let _t10 = putStrLn _t9  ; Δ{_t9}
  let _t2 = closure lam$2  ; Δ{_t1} · makes Closure
  let _t2 = closure lam$3  ; Δ{_t1} · makes Closure
  let _t2 = rtcall axion_par_for _t0 _t1  ; Δ{_t0 _t1}
  let _t2 = rtcall axion_par_for _t0 _t1  ; Δ{_t0 _t1}
  let _t3 = rtcall axion_par_for _t1 _t2  ; Δ{_t1 _t2}
  let _t3 = rtcall axion_par_for _t1 _t2  ; Δ{_t1 _t2}
  let _t4 = _t1  ; Δ{_t1} · moves{_t1}
  let _t4 = newArray n 0f  ; Δ{} · makes Array
  let _t5 = closure lam$4  ; Δ{_t4} · makes Closure
  let _t6 = rtcall axion_par_for _t4 _t5  ; Δ{_t4 _t5}
  let _t7 = call matVec m v n  ; Δ{} · makes Array
  let _t8 = call sumF _t7 0 0f  ; Δ{_t7}
  let _t9 = rtcall axion_show_float _t8  ; Δ{} · makes String
  let m = _t1  ; Δ{_t1} · moves{_t1}
  let n = 120  ; Δ{}
  let v = _t4  ; Δ{_t4} · moves{_t4}
  ret * i k  ; Δ{}
  ret * x 3  ; Δ{}
  ret *. _t0 0.5f  ; Δ{}
  ret + _t0 i  ; Δ{}
  ret -. _t1 3f  ; Δ{}
  ret 0  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _t0  ; Δ{_t0} · moves{_t0}
  ret _t0  ; Δ{_t0} · moves{_t0}
  ret a  ; Δ{}
  ret call bump eta$1 eta$2  ; Δ{}
  ret call collatz _t0 0  ; Δ{}
  ret call dotRow m v n r 0 0f  ; Δ{}
  ret call hoflamcap0 _cap0 i  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call triangle r  ; Δ{}
  ret case _t10 of
  ret if $bce35 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret j  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
<=$Int x y  =
>=$Int x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
bump i x  =
collatz n steps  =
countTrue a i acc  =
dotRow m v n r j acc  =
dotRow$bce m v n r j acc  =
hoflamcap0 k i  =
lam$0 [env m n v]r _w1  =
lam$1 [env ]_w0 x  =
lam$2 [env ]j _w1  =
lam$3 [env ]k _w1  =
lam$4 [env ]j _w1  =
lam$5 [env ]i _w1  =
lam$6 [env ]eta$1 eta$2  =
lam$7 [env ]r _w1  =
lam$8 [env ]i _w1  =
lam$9 [env _cap0]i _w1  =
le$Int x y  =
main  =
matVec m v n  =
scale a  =
sumA a i acc  =
sumF a i acc  =
tabulate$$hoflamcap0 _cap0 n  =
triangle r  =
