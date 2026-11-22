


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
  drop _t0 : Array
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = newArray 6 1f  ; Δ{} · makes Array
  let _t1 = rtcall axion_array_range _t0 3 4  ; Δ{_t0}
  let _t10 = vec.sum.F64x4 _t9  ; Δ{}
  let _t2 = rtcall axion_array_get_nobc _t0 _t1  ; Δ{_t0}
  let _t3 = + _t1 1  ; Δ{_t0}
  let _t4 = rtcall axion_array_get_nobc _t0 _t3  ; Δ{_t0}
  let _t5 = + _t1 2  ; Δ{_t0}
  let _t6 = rtcall axion_array_get_nobc _t0 _t5  ; Δ{_t0}
  let _t7 = + _t1 3  ; Δ{_t0}
  let _t8 = rtcall axion_array_get_nobc _t0 _t7  ; Δ{_t0}
  let _t9 = vec.make.F64x4 _t2 _t4 _t6 _t8  ; Δ{}
  ret 0  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret truncate _t10  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
