


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
  drop _t5 : Array
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = newArray 5 0  ; Δ{} · makes Array
  let _t1 = rtcall axion_array_set _t0 0 10  ; Δ{_t0} · moves{_t0} · makes Array
  let _t10 = + _t8 _t9  ; Δ{_t5}
  let _t11 = rtcall axion_array_get _t5 3  ; Δ{_t5}
  let _t12 = + _t10 _t11  ; Δ{_t5}
  let _t13 = rtcall axion_array_get _t5 4  ; Δ{_t5}
  let _t14 = + _t12 _t13  ; Δ{}
  let _t2 = rtcall axion_array_set _t1 1 20  ; Δ{_t1} · moves{_t1} · makes Array
  let _t3 = rtcall axion_array_set _t2 2 30  ; Δ{_t2} · moves{_t2} · makes Array
  let _t4 = rtcall axion_array_set _t3 3 40  ; Δ{_t3} · moves{_t3} · makes Array
  let _t5 = rtcall axion_array_set _t4 4 50  ; Δ{_t4} · moves{_t4} · makes Array
  let _t6 = rtcall axion_array_get _t5 0  ; Δ{_t5}
  let _t7 = rtcall axion_array_get _t5 1  ; Δ{_t5}
  let _t8 = + _t6 _t7  ; Δ{_t5}
  let _t9 = rtcall axion_array_get _t5 2  ; Δ{_t5}
  ret 0  ; Δ{}
  ret _t14  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
