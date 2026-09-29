


      drop _t1 : String
      let _d1000000 = putStr _t1  ; Δ{_t1}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{}
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{_t1}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = rtcall axion_read_key 0  ; Δ{} · makes String
  let _t1 = rtcall axion_read_key 0  ; Δ{_t0} · makes String
  let _t2 = putStr _t0  ; Δ{_t0 _t1}
  ret 0  ; Δ{}
  ret case _t2 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
