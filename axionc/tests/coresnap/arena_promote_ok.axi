



axion_drop_Array _p  =
axion_drop_List _p  =
  drop _t0
    else
  else
lam$0 [env parent]sub  =
  let _d1000000 = withSubArena parent _t0  ; Δ{_t0}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let node2 = promote parent node  ; Δ{}
  let node = allocateCell sub  ; Δ{}
  let _t0 = closure lam$0 parent  ; Δ{} · makes heap
    let _tag = loadraw _p+0  ; Δ{}
ok parent  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret node2  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ; Δ{}
  ; Δ{}
