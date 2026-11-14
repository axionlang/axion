











      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t0 = rtcall axion_str_len s  ; Δ{}
      ret + _t0 n  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    Pair s n ->
    drop x : Pair
    drop x : String
    drop y : Pair
    drop y : String
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret x  ; Δ{}
    ret x  ; Δ{}
    ret x  ; Δ{}
    ret y  ; Δ{}
    ret y  ; Δ{}
    ret y  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t12 : Integer
  drop _t13 : Integer
  drop _t14 : Integer
  drop _t15 : Integer
  drop _t16 : String
  drop _t24 : Pair
  drop _t29 : String
  drop _t3 : String
  drop _t8 : String
  else
  else
  else
  else
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = 1  ; Δ{}
  let _t0 = > n 2  ; Δ{}
  let _t0 = > n 2  ; Δ{}
  let _t1 = showInt 12  ; Δ{} · makes String
  let _t10 = + _t4 _t9  ; Δ{}
  let _t11 = rtcall axion_bignum_from_i64 77  ; Δ{} · makes Integer
  let _t12 = rtcall axion_bignum_from_i64 1  ; Δ{_t11} · makes Integer
  let _t13 = rtcall axion_bignum_from_i64 2  ; Δ{_t11 _t12} · makes Integer
  let _t14 = rtcall axion_bignum_mul _t12 _t13  ; Δ{_t11 _t12 _t13} · makes Integer
  let _t15 = call konst$Integer _t11 _t14  ; Δ{_t11 _t14} · moves{_t11} · makes Integer
  let _t16 = rtcall axion_bignum_to_string _t15  ; Δ{_t15} · makes String
  let _t17 = rtcall axion_str_len _t16  ; Δ{_t16}
  let _t18 = + _t10 _t17  ; Δ{}
  let _t19 = 1  ; Δ{}
  let _t2 = showInt 345  ; Δ{_t1} · makes String
  let _t20 = showInt 9  ; Δ{} · makes String
  let _t21 = con Pair _t20 1  ; Δ{_t20} · moves{_t20} · makes Pair
  let _t22 = showInt 10  ; Δ{_t21} · makes String
  let _t23 = con Pair _t22 2  ; Δ{_t21 _t22} · moves{_t22} · makes Pair
  let _t24 = call pickG$Pair _t19 _t21 _t23  ; Δ{_t21 _t23} · moves{_t21 _t23} · makes Pair
  let _t25 = call pairLen _t24  ; Δ{_t24}
  let _t26 = + _t18 _t25  ; Δ{}
  let _t27 = showInt 1000  ; Δ{} · makes String
  let _t28 = showInt 7  ; Δ{_t27} · makes String
  let _t29 = call choose$String 5 _t27 _t28  ; Δ{_t27 _t28} · moves{_t27 _t28} · makes String
  let _t3 = call pickG$String _t0 _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes String
  let _t30 = rtcall axion_str_len _t29  ; Δ{_t29}
  let _t31 = + _t26 _t30  ; Δ{}
  let _t32 = 1  ; Δ{}
  let _t33 = call pickG _t32 1 2  ; Δ{}
  let _t4 = rtcall axion_str_len _t3  ; Δ{_t3}
  let _t5 = 0  ; Δ{}
  let _t6 = showInt 6  ; Δ{} · makes String
  let _t7 = rtcall axion_strcat "a" "b"  ; Δ{_t6} · makes String
  let _t8 = call pickG$String _t5 _t6 _t7  ; Δ{_t6 _t7} · moves{_t6 _t7} · makes String
  let _t9 = rtcall axion_str_len _t8  ; Δ{_t8}
  ret + _t31 _t33  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call pickG _t0 x y  ; Δ{}
  ret call pickG$String _t0 x y  ; Δ{} · makes String
  ret case p of
  ret if b then
  ret if b then
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
  ret x  ; Δ{}
  ret x  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Pair _p  =
choose n x y  =
choose$String n x y  =
konst x y  =
konst$Integer x y  =
main  =
pairLen p  =
pickG b x y  =
pickG$Pair b x y  =
pickG$String b x y  =
