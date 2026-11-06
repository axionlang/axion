


























                                ret "gt"  ; Δ{}
                                ret "le"  ; Δ{}
                              drop _t35 : Rational
                              drop _t36 : Rational
                              else
                              let _t35 = call half  ; Δ{} · makes Rational
                              let _t36 = call half  ; Δ{_t35} · makes Rational
                              let _t37 = call <=$Rational _t35 _t36  ; Δ{_t35 _t36}
                              let _t38 = if _t37 then
                              ret putStrLn _t38  ; Δ{}
                            _ ->
                            ret "ge"  ; Δ{}
                            ret "lt"  ; Δ{}
                          drop _t30 : Rational
                          drop _t31 : Rational
                          else
                          let _t30 = call third  ; Δ{} · makes Rational
                          let _t31 = call half  ; Δ{_t30} · makes Rational
                          let _t32 = call lt$Rational _t30 _t31  ; Δ{_t30 _t31}
                          let _t33 = if _t32 then
                          let _t34 = putStrLn _t33  ; Δ{}
                          ret case _t34 of
                        _ ->
                        ret "eq"  ; Δ{}
                        ret "ne"  ; Δ{}
                      drop _t25 : Rational
                      drop _t26 : Rational
                      else
                      let _t25 = call half  ; Δ{} · makes Rational
                      let _t26 = con Rational 2 4  ; Δ{_t25} · makes Rational
                      let _t27 = call eq$Rational _t25 _t26  ; Δ{_t25 _t26}
                      let _t28 = if _t27 then
                      let _t29 = putStrLn _t28  ; Δ{}
                      ret case _t29 of
                    _ ->
                  drop _t20 : Rational
                  drop _t21 : Rational
                  drop _t22 : Rational
                  drop _t23 : String
                  let _t20 = call half  ; Δ{} · makes Rational
                  let _t21 = call third  ; Δ{_t20} · makes Rational
                  let _t22 = call -$Rational _t20 _t21  ; Δ{_t20 _t21} · makes Rational
                  let _t23 = call showR _t22  ; Δ{_t22} · makes String
                  let _t24 = putStrLn _t23  ; Δ{_t23}
                  ret case _t24 of
                _ ->
              drop _t15 : Rational
              drop _t16 : Rational
              drop _t17 : Rational
              drop _t18 : String
              let _t15 = call half  ; Δ{} · makes Rational
              let _t16 = call third  ; Δ{_t15} · makes Rational
              let _t17 = call /$Rational _t15 _t16  ; Δ{_t15 _t16} · makes Rational
              let _t18 = call showR _t17  ; Δ{_t17} · makes String
              let _t19 = putStrLn _t18  ; Δ{_t18}
              ret case _t19 of
            _ ->
          drop _t10 : Rational
          drop _t11 : Rational
          drop _t12 : Rational
          drop _t13 : String
          let _t10 = call half  ; Δ{} · makes Rational
          let _t11 = call third  ; Δ{_t10} · makes Rational
          let _t12 = call *$Rational _t10 _t11  ; Δ{_t10 _t11} · makes Rational
          let _t13 = call showR _t12  ; Δ{_t12} · makes String
          let _t14 = putStrLn _t13  ; Δ{_t13}
          ret case _t14 of
        _ ->
      drop _t5 : Rational
      drop _t6 : Rational
      drop _t7 : Rational
      drop _t8 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t5 = call half  ; Δ{} · makes Rational
      let _t6 = call third  ; Δ{_t5} · makes Rational
      let _t7 = call +$Rational _t5 _t6  ; Δ{_t5 _t6} · makes Rational
      let _t8 = call showR _t7  ; Δ{_t7} · makes String
      let _t9 = putStrLn _t8  ; Δ{_t8}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t9 of
      ret d  ; Δ{}
      ret n  ; Δ{}
    Rational n d ->
    Rational n d ->
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = mod a b  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret - 0 1  ; Δ{}
    ret - 0 x  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret a  ; Δ{}
    ret call gcdI b _t1  ; Δ{}
    ret g  ; Δ{}
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : Rational
  drop _t1 : Rational
  drop _t1 : String
  drop _t2 : Rational
  drop _t3 : String
  drop _t3 : String
  drop _t4 : String
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = < x 0  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == b 0  ; Δ{}
  let _t0 = call absI n  ; Δ{}
  let _t0 = call fromInteger$Rational 3  ; Δ{} · makes Rational
  let _t0 = call le$Rational y x  ; Δ{}
  let _t0 = call num a  ; Δ{}
  let _t0 = call num a  ; Δ{}
  let _t0 = call num a  ; Δ{}
  let _t0 = call num a  ; Δ{}
  let _t0 = call num a  ; Δ{}
  let _t0 = call num a  ; Δ{}
  let _t0 = call num r  ; Δ{}
  let _t1 = call absI d  ; Δ{}
  let _t1 = call den b  ; Δ{}
  let _t1 = call den b  ; Δ{}
  let _t1 = call den b  ; Δ{}
  let _t1 = call den b  ; Δ{}
  let _t1 = call den b  ; Δ{}
  let _t1 = call half  ; Δ{_t0} · makes Rational
  let _t1 = call num b  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = * _t0 _t1  ; Δ{}
  let _t2 = * _t0 _t1  ; Δ{}
  let _t2 = * _t0 _t1  ; Δ{}
  let _t2 = * _t0 _t1  ; Δ{}
  let _t2 = * _t0 _t1  ; Δ{}
  let _t2 = * _t0 _t1  ; Δ{}
  let _t2 = == g 0  ; Δ{}
  let _t2 = call +$Rational _t0 _t1  ; Δ{_t0 _t1} · makes Rational
  let _t2 = call den r  ; Δ{_t1}
  let _t3 = < d 0  ; Δ{}
  let _t3 = call den a  ; Δ{}
  let _t3 = call den a  ; Δ{}
  let _t3 = call num b  ; Δ{}
  let _t3 = call num b  ; Δ{}
  let _t3 = call num b  ; Δ{}
  let _t3 = call num b  ; Δ{}
  let _t3 = call showR _t2  ; Δ{_t2} · makes String
  let _t3 = showInt _t2  ; Δ{_t1} · makes String
  let _t4 = * s n  ; Δ{}
  let _t4 = call den a  ; Δ{}
  let _t4 = call den a  ; Δ{}
  let _t4 = call den a  ; Δ{}
  let _t4 = call den a  ; Δ{}
  let _t4 = call den b  ; Δ{}
  let _t4 = call num b  ; Δ{}
  let _t4 = putStrLn _t3  ; Δ{_t3}
  let _t4 = rtcall axion_strcat "/" _t3  ; Δ{_t1 _t3} · makes String
  let _t5 = * _t3 _t4  ; Δ{}
  let _t5 = * _t3 _t4  ; Δ{}
  let _t5 = * _t3 _t4  ; Δ{}
  let _t5 = * _t3 _t4  ; Δ{}
  let _t5 = * _t3 _t4  ; Δ{}
  let _t5 = * _t3 _t4  ; Δ{}
  let _t5 = div _t4 g2  ; Δ{}
  let _t6 = * s d  ; Δ{}
  let _t6 = + _t2 _t5  ; Δ{}
  let _t6 = - _t2 _t5  ; Δ{}
  let _t7 = call den a  ; Δ{}
  let _t7 = call den a  ; Δ{}
  let _t7 = div _t6 g2  ; Δ{}
  let _t8 = call den b  ; Δ{}
  let _t8 = call den b  ; Δ{}
  let _t9 = * _t7 _t8  ; Δ{}
  let _t9 = * _t7 _t8  ; Δ{}
  let g = call gcdI _t0 _t1  ; Δ{}
  let g2 = if _t2 then
  let s = if _t3 then
  ret 0  ; Δ{}
  ret == _t2 _t5  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret call <=$Int _t2 _t5  ; Δ{}
  ret call addR a b  ; Δ{} · makes Rational
  ret call divR a b  ; Δ{} · makes Rational
  ret call le$Int x y  ; Δ{}
  ret call le$Rational x y  ; Δ{}
  ret call mkR _t2 _t5  ; Δ{} · makes Rational
  ret call mkR _t2 _t5  ; Δ{} · makes Rational
  ret call mkR _t6 _t9  ; Δ{} · makes Rational
  ret call mkR _t6 _t9  ; Δ{} · makes Rational
  ret call mulR a b  ; Δ{} · makes Rational
  ret call not _t0  ; Δ{}
  ret call subR a b  ; Δ{} · makes Rational
  ret case _t4 of
  ret case r of
  ret case r of
  ret con Rational 1 2  ; Δ{} · makes Rational
  ret con Rational 1 3  ; Δ{} · makes Rational
  ret con Rational _t5 _t7  ; Δ{} · makes Rational
  ret con Rational n 1  ; Δ{} · makes Rational
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
*$Rational a b  =
+$Rational a b  =
-$Rational a b  =
/$Rational a b  =
<=$Int x y  =
<=$Rational x y  =
absI x  =
addR a b  =
axion_drop_Array _p  =
axion_drop_List _p  =
den r  =
divR a b  =
eq$Rational a b  =
fromInteger$Rational n  =
gcdI a b  =
half  =
le$Int x y  =
le$Rational a b  =
lt$Rational x y  =
main  =
mkR n d  =
mulR a b  =
not b  =
num r  =
showR r  =
subR a b  =
third  =
