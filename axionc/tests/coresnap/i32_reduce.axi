


      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : I32Array
  drop _t1 : Array
  drop _t3 : I32Array
  drop _t4 : Array
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = rtcall axion_i32_iota 10  ; Δ{} · makes I32Array
  let _t1 = rtcall axion_array_iota 10  ; Δ{_t0} · makes Array
  let _t2 = rtcall axion_i32_dot _t0 _t1  ; Δ{_t0 _t1}
  let _t3 = rtcall axion_i32_iota 10  ; Δ{} · makes I32Array
  let _t4 = rtcall axion_array_iota 4  ; Δ{_t3} · makes Array
  let _t5 = rtcall axion_i32_matvec_sum _t3 _t4 4  ; Δ{_t3 _t4}
  ret + _t2 _t5  ; Δ{}
  ret 0  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
