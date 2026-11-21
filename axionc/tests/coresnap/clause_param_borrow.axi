




      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = - _p0 1  ; Δ{}
    let _t1 = rtcall axion_array_get _p1 0  ; Δ{}
    let _t2 = - _p0 1  ; Δ{}
    let _t3 = call sumK _t2 _p1  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret + _t1 _t3  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret _p1  ; Δ{}
    ret call idArr _t1 _p1  ; Δ{} · makes Array
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop b : Array
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = + x y  ; Δ{b}
  let _t0 = == _p0 0  ; Δ{}
  let _t0 = == _p0 0  ; Δ{}
  let _t1 = rtcall axion_array_get b 2  ; Δ{b}
  let a = newArray 4 3  ; Δ{} · makes Array
  let b = call idArr 2 a  ; Δ{a} · moves{a} · makes Array
  let x = call sumK 5 a  ; Δ{a}
  let y = rtcall axion_array_get_nobc a 1  ; Δ{a}
  ret + _t0 _t1  ; Δ{}
  ret 0  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
idArr _p0 _p1  =
main  =
sumK _p0 _p1  =
