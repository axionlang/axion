




      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
    False ->
    True ->
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
  drop _t0 : Integer
  drop _t0 : Integer
  drop _t1 : Integer
  drop _t2 : Integer
  else
  let _d1000000 = rtcall axion_bignum_mul x _t0  ; Δ{_t0} · makes Integer
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call sq x  ; Δ{} · makes Integer
  let _t0 = rtcall axion_bignum_from_i64 4  ; Δ{} · makes Integer
  let _t1 = call cube _t0  ; Δ{_t0} · makes Integer
  let _t2 = rtcall axion_bignum_from_i64 64  ; Δ{_t1} · makes Integer
  let _t3 = rtcall axion_bignum_eq _t1 _t2  ; Δ{_t1 _t2}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret case _t3 of
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_mul x x  ; Δ{} · makes Integer
axion_drop_Array _p  =
axion_drop_List _p  =
cube x  =
main  =
sq x  =
