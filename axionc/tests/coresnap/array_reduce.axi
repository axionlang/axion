


axion_drop_Array _p  =
axion_drop_List _p  =
  drop _t0 : Array
  drop _t2 : Array
  drop _t3 : Array
    else
  else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = rtcall axion_array_iota 10  ; Δ{} · makes Array
  let _t1 = rtcall axion_array_sum _t0  ; Δ{_t0}
  let _t2 = rtcall axion_array_iota 10  ; Δ{} · makes Array
  let _t3 = rtcall axion_array_iota 10  ; Δ{_t2} · makes Array
  let _t4 = rtcall axion_array_dot _t2 _t3  ; Δ{_t2 _t3}
    let _tag = loadraw _p+0  ; Δ{}
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret + _t1 _t4  ; Δ{}
  ; Δ{}
  ; Δ{}
