



      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret con East  ; Δ{}
      ret con North  ; Δ{}
      ret con South  ; Δ{}
      ret con West  ; Δ{}
    East ->
    North ->
    South ->
    South ->
    West ->
    _ ->
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
  ; Δ{}
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = con North  ; Δ{}
  let _t1 = call turn _t0  ; Δ{}
  let _t2 = call turn _t1  ; Δ{}
  ret 0  ; Δ{}
  ret case _t2 of
  ret case d of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
turn d  =
