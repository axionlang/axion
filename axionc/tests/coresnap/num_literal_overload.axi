







          let _t0 = * an bd  ; Δ{}
          let _t1 = * bn ad  ; Δ{}
          let _t2 = + _t0 _t1  ; Δ{}
          let _t3 = * ad bd  ; Δ{}
          ret con Rational _t2 _t3  ; Δ{} · makes Rational
        Rational bn bd ->
      drop _t0 : String
      drop _t1 : String
      drop _t2 : String
      drop _t5 : Rational
      drop _t6 : Rational
      drop _t7 : Rational
      drop _t8 : String
      let _d1000000 = putStrLn _t8  ; Δ{_t8}
      let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t0 = showInt n  ; Δ{} · makes String
      let _t1 = showInt d  ; Δ{_t0} · makes String
      let _t2 = rtcall axion_strcat "/" _t1  ; Δ{_t0 _t1} · makes String
      let _t5 = call half  ; Δ{} · makes Rational
      let _t6 = call fromInteger$Rational 1  ; Δ{_t5} · makes Rational
      let _t7 = call +$Rational _t5 _t6  ; Δ{_t5 _t6} · makes Rational
      let _t8 = call showR _t7  ; Δ{_t7} · makes String
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{}
      ret case b of
    Rational an ad ->
    Rational n d ->
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
  drop _t0 : Rational
  drop _t1 : Rational
  drop _t2 : Rational
  drop _t3 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call fromInteger$Rational 3  ; Δ{} · makes Rational
  let _t1 = call half  ; Δ{_t0} · makes Rational
  let _t2 = call +$Rational _t0 _t1  ; Δ{_t0 _t1} · makes Rational
  let _t3 = call showR _t2  ; Δ{_t2} · makes String
  let _t4 = putStrLn _t3  ; Δ{_t3}
  ret 0  ; Δ{}
  ret call addR a b  ; Δ{} · makes Rational
  ret case _t4 of
  ret case a of
  ret case r of
  ret con Rational 1 2  ; Δ{} · makes Rational
  ret con Rational n 1  ; Δ{} · makes Rational
  ret rtcall axion_array_free _p  ; Δ{}
+$Rational a b  =
addR a b  =
axion_drop_Array _p  =
axion_drop_List _p  =
fromInteger$Rational n  =
half  =
main  =
showR r  =
