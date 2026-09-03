




      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    drop _t2 : Integer
    drop _t3 : Integer
    drop h : Integer
    else
    let _d1000000 = rtcall axion_bignum_add h h  ; Δ{h} · makes Integer
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t2 = rtcall axion_bignum_from_i64 1  ; Δ{} · makes Integer
    let _t3 = rtcall axion_bignum_sub n _t2  ; Δ{_t2} · makes Integer
    let _tag = loadraw _p+0  ; Δ{}
    let h = call slow _t3  ; Δ{_t3} · makes Integer
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret rtcall axion_bignum_from_i64 1  ; Δ{} · makes Integer
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : Integer
  drop _t0 : Integer
  drop _t1 : Integer
  drop _t2 : String
  else
  else
  let _d1000000 = putStrLn _t2  ; Δ{_t2}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = rtcall axion_bignum_from_i64 0  ; Δ{} · makes Integer
  let _t0 = rtcall axion_bignum_from_i64 20  ; Δ{} · makes Integer
  let _t1 = call slow _t0  ; Δ{_t0} · makes Integer
  let _t1 = rtcall axion_bignum_eq n _t0  ; Δ{_t0}
  let _t2 = call show$Integer _t1  ; Δ{_t1} · makes String
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_to_string x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
show$Integer x  =
slow n  =
