





allocN _p0 _p1  =
axion_drop_Array _p  =
axion_drop_List _p  =
  drop _t0
    else
  else
  else
lam$0 [env ]a  =
    let a = _p0  ; Δ{}
    let a = _p0  ; Δ{}
    let c = allocateCell a  ; Δ{}
  let _d1000000 = withArena _t0  ; Δ{_t0}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let n = _p1  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = == _p1 0  ; Δ{}
    let _t1 = - n 1  ; Δ{}
    let _t2 = call allocN a _t1  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let u = call useCell c  ; Δ{}
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
    ret + 1 _t2  ; Δ{}
  ret call allocN a 100  ; Δ{}
  ret _d1000000  ; Δ{}
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
useCell c  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
