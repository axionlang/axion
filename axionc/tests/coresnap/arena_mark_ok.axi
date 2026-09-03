



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
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let done = arena_release mark  ; Δ{}
  let mark = arena_mark arena  ; Δ{}
  let n = call useCell tmp  ; Δ{}
  let tmp = allocateCell arena  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret n  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
okMark arena  =
useCell c  =
