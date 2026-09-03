




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
  drop p0 : Point
  drop p1 : Point
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call sumP p0  ; Δ{p0 p1}
  let _t0 = field x p  ; Δ{}
  let _t1 = call sumP p1  ; Δ{p1}
  let _t1 = field y p  ; Δ{}
  let p0 = record Point { x = 1 y = 2}  ; Δ{} · makes Point
  let p1 = call shiftX p0  ; Δ{p0} · makes Point
  ret + _t0 _t1  ; Δ{}
  ret + _t0 _t1  ; Δ{}
  ret 0  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret update p { x = 99}  ; Δ{} · makes heap
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
shiftX p  =
sumP p  =
