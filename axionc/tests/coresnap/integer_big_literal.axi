



axion_drop_Array _p  =
axion_drop_List _p  =
  drop _t0 : Integer
  drop _t1 : Integer
  drop _t2 : Integer
  drop _t3 : String
    else
  else
  let _d1000000 = putStrLn _t3  ; Δ{_t3}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = rtcall axion_bignum_from_str "12345678901234567890"  ; Δ{} · makes Integer
  let _t1 = rtcall axion_bignum_from_str "12345678901234567890"  ; Δ{_t0} · makes Integer
  let _t2 = rtcall axion_bignum_mul _t0 _t1  ; Δ{_t0 _t1} · makes Integer
  let _t3 = call show$Integer _t2  ; Δ{_t2} · makes String
    let _tag = loadraw _p+0  ; Δ{}
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_to_string x  ; Δ{} · makes String
show$Integer x  =
  ; Δ{}
  ; Δ{}
