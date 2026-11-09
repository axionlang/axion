




      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = - _p0 1  ; Δ{}
    let _t2 = + _p1 _p2  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret _p1  ; Δ{}
    ret call fibFast$go _t1 _p2 _t2  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = == _p0 0  ; Δ{}
  ret 0  ; Δ{}
  ret call fibFast 30  ; Δ{}
  ret call fibFast$go n 0 1  ; Δ{}
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
fibFast n  =
fibFast$go _p0 _p1 _p2  =
main  =
