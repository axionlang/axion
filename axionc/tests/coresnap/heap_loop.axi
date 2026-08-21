




    (a, b) ->
axion_drop_Array _p  =
axion_drop_List _p  =
      drop _t0
    else
  else
  else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let n = _p0  ; Δ{}
  let _t0 = == _p0 0  ; Δ{}
  let _t0 = tuple n n  ; Δ{} · makes heap
    let _t1 = call step n  ; Δ{}
    let _t2 = - n 1  ; Δ{}
    let _t3 = call sumTo _t2  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
      ret + a b  ; Δ{}
  ret call sumTo 300  ; Δ{}
  ret case _t0 of
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
    ret + _t1 _t3  ; Δ{}
step n  =
sumTo _p0  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{_t0}
