



      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret + a b  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    Point a b ->
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
  drop _t0 : Point
  else
  let _d1000000 = call sumP _t0  ; Δ{_t0}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = record Point { x = 3 y = 4}  ; Δ{} · makes Point
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case p of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
sumP p  =
