


axion_drop_Array _p  =
axion_drop_List _p  =
  drop a : I8Array
    else
  else
  let a = rtcall axion_i8_set _t0 0 5  ; Δ{_t0} · moves{_t0} · makes I8Array
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = rtcall axion_i8_iota 20  ; Δ{} · makes I8Array
  let _t1 = rtcall axion_i8_get a 0  ; Δ{a}
  let _t2 = rtcall axion_i8_get a 3  ; Δ{a}
  let _t3 = + _t1 _t2  ; Δ{a}
  let _t4 = rtcall axion_i8_len a  ; Δ{a}
    let _tag = loadraw _p+0  ; Δ{}
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret + _t3 _t4  ; Δ{}
  ; Δ{}
  ; Δ{}
