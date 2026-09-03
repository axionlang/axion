



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
  drop p : Pair
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let p = call mkPair 7 8  ; Δ{} · makes Pair
  ret 0  ; Δ{}
  ret 15  ; Δ{}
  ret record Pair { x = a y = b}  ; Δ{} · makes Pair
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
mkPair a b  =
