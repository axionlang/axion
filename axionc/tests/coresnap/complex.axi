













              drop _t15 : Complex
              drop _t16 : Complex
              drop _t17 : Complex
              drop _t18 : String
              let _d1000000 = putStrLn _t18  ; Δ{_t18}
              let _t15 = con Complex 1f 0f  ; Δ{} · makes Complex
              let _t16 = con Complex 2f 0f  ; Δ{_t15} · makes Complex
              let _t17 = call /$Complex _t15 _t16  ; Δ{_t15 _t16} · makes Complex
              let _t18 = call showC _t17  ; Δ{_t17} · makes String
              ret _d1000000  ; Δ{}
            _ ->
          drop _t10 : Complex
          drop _t11 : Complex
          drop _t12 : Complex
          drop _t13 : String
          let _t10 = con Complex 1f 2f  ; Δ{} · makes Complex
          let _t11 = con Complex 3f 4f  ; Δ{_t10} · makes Complex
          let _t12 = call *$Complex _t10 _t11  ; Δ{_t10 _t11} · makes Complex
          let _t13 = call showC _t12  ; Δ{_t12} · makes String
          let _t14 = putStrLn _t13  ; Δ{_t13}
          ret case _t14 of
        _ ->
      drop _t5 : Complex
      drop _t6 : Complex
      drop _t7 : Complex
      drop _t8 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t5 = con Complex 5f 6f  ; Δ{} · makes Complex
      let _t6 = con Complex 1f 2f  ; Δ{_t5} · makes Complex
      let _t7 = call -$Complex _t5 _t6  ; Δ{_t5 _t6} · makes Complex
      let _t8 = call showC _t7  ; Δ{_t7} · makes String
      let _t9 = putStrLn _t8  ; Δ{_t8}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t9 of
      ret i  ; Δ{}
      ret r  ; Δ{}
    Complex r i ->
    Complex r i ->
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : Complex
  drop _t1 : Complex
  drop _t1 : String
  drop _t2 : Complex
  drop _t3 : String
  drop _t3 : String
  drop _t4 : String
  drop _t5 : String
  else
  let _d1000000 = rtcall axion_strcat _t1 _t5  ; Δ{_t1 _t5} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call reC a  ; Δ{}
  let _t0 = call reC a  ; Δ{}
  let _t0 = call reC a  ; Δ{}
  let _t0 = call reC b  ; Δ{}
  let _t0 = call reC c  ; Δ{}
  let _t0 = con Complex 1f 2f  ; Δ{} · makes Complex
  let _t1 = call reC b  ; Δ{}
  let _t1 = call reC b  ; Δ{}
  let _t1 = call reC b  ; Δ{}
  let _t1 = call reC b  ; Δ{}
  let _t1 = con Complex 3f 4f  ; Δ{_t0} · makes Complex
  let _t1 = rtcall axion_show_float _t0  ; Δ{} · makes String
  let _t10 = call imC a  ; Δ{}
  let _t10 = call imC b  ; Δ{}
  let _t11 = *. _t9 _t10  ; Δ{}
  let _t11 = call reC b  ; Δ{}
  let _t12 = *. _t10 _t11  ; Δ{}
  let _t12 = +. _t8 _t11  ; Δ{}
  let _t13 = +. _t9 _t12  ; Δ{}
  let _t13 = /. _t12 d  ; Δ{}
  let _t14 = call imC a  ; Δ{}
  let _t15 = call reC b  ; Δ{}
  let _t16 = *. _t14 _t15  ; Δ{}
  let _t17 = call reC a  ; Δ{}
  let _t18 = call imC b  ; Δ{}
  let _t19 = *. _t17 _t18  ; Δ{}
  let _t2 = *. _t0 _t1  ; Δ{}
  let _t2 = *. _t0 _t1  ; Δ{}
  let _t2 = +. _t0 _t1  ; Δ{}
  let _t2 = -. _t0 _t1  ; Δ{}
  let _t2 = call +$Complex _t0 _t1  ; Δ{_t0 _t1} · makes Complex
  let _t2 = call imC c  ; Δ{_t1}
  let _t20 = -. _t16 _t19  ; Δ{}
  let _t21 = /. _t20 d  ; Δ{}
  let _t3 = call imC a  ; Δ{}
  let _t3 = call imC a  ; Δ{}
  let _t3 = call imC a  ; Δ{}
  let _t3 = call imC b  ; Δ{}
  let _t3 = call showC _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_show_float _t2  ; Δ{_t1} · makes String
  let _t4 = call imC b  ; Δ{}
  let _t4 = call imC b  ; Δ{}
  let _t4 = call imC b  ; Δ{}
  let _t4 = call imC b  ; Δ{}
  let _t4 = putStrLn _t3  ; Δ{_t3}
  let _t4 = rtcall axion_strcat _t3 "i"  ; Δ{_t1 _t3} · makes String
  let _t5 = *. _t3 _t4  ; Δ{}
  let _t5 = *. _t3 _t4  ; Δ{}
  let _t5 = +. _t3 _t4  ; Δ{}
  let _t5 = -. _t3 _t4  ; Δ{}
  let _t5 = rtcall axion_strcat " + " _t4  ; Δ{_t1 _t4} · makes String
  let _t6 = -. _t2 _t5  ; Δ{}
  let _t6 = call reC a  ; Δ{}
  let _t7 = call reC a  ; Δ{}
  let _t7 = call reC b  ; Δ{}
  let _t8 = *. _t6 _t7  ; Δ{}
  let _t8 = call imC b  ; Δ{}
  let _t9 = *. _t7 _t8  ; Δ{}
  let _t9 = call imC a  ; Δ{}
  let d = +. _t2 _t5  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret call addC a b  ; Δ{} · makes Complex
  ret call divC a b  ; Δ{} · makes Complex
  ret call mulC a b  ; Δ{} · makes Complex
  ret call subC a b  ; Δ{} · makes Complex
  ret case _t4 of
  ret case c of
  ret case c of
  ret con Complex _t13 _t21  ; Δ{} · makes Complex
  ret con Complex _t2 _t5  ; Δ{} · makes Complex
  ret con Complex _t2 _t5  ; Δ{} · makes Complex
  ret con Complex _t6 _t13  ; Δ{} · makes Complex
  ret rtcall axion_array_free _p  ; Δ{}
*$Complex a b  =
+$Complex a b  =
-$Complex a b  =
/$Complex a b  =
addC a b  =
axion_drop_Array _p  =
axion_drop_List _p  =
divC a b  =
imC c  =
main  =
mulC a b  =
reC c  =
showC c  =
subC a b  =
