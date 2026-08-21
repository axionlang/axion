




axion_drop_Array _p  =
axion_drop_Box _p  =
axion_drop_List _p  =
boxSum x  =
  drop _t1 : Box
    else
  else
  let _d1000000 = call boxSum _t1  ; Δ{_t1}
  let _dd0 = loadraw _p+0  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd1 = rtcall axion_free _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = field inner x  ; Δ{}
  let _t0 = record P { a = 3 b = 4}  ; Δ{} · makes P
  let _t1 = field a _t0  ; Δ{}
  let _t1 = record Box { inner = _t0 tag = 5}  ; Δ{_t0} · moves{_t0} · makes Box
  let _t2 = field inner x  ; Δ{}
  let _t3 = field b _t2  ; Δ{}
  let _t4 = + _t1 _t3  ; Δ{}
  let _t5 = field tag x  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret + _t4 _t5  ; Δ{}
  ; Δ{}
  ; Δ{}
