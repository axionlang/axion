



      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
    False ->
    True ->
    drop _t2 : Integer
    drop acc : Integer
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = - k 1  ; Δ{}
    let _t2 = rtcall axion_bignum_from_i64 2  ; Δ{} · makes Integer
    let _t3 = rtcall axion_bignum_mul acc _t2  ; Δ{_t2} · makes Integer
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret acc  ; Δ{}
    ret call countDown _t1 _t3  ; Δ{_t3} · moves{_t3} · makes Integer
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1 : Integer
  drop _t2 : Integer
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = < k 1  ; Δ{}
  let _t0 = rtcall axion_bignum_from_i64 1  ; Δ{} · makes Integer
  let _t1 = call countDown 8 _t0  ; Δ{_t0} · moves{_t0} · makes Integer
  let _t2 = rtcall axion_bignum_from_i64 256  ; Δ{_t1} · makes Integer
  let _t3 = rtcall axion_bignum_eq _t1 _t2  ; Δ{_t1 _t2}
  ret 0  ; Δ{}
  ret case _t3 of
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
countDown k acc  =
main  =
