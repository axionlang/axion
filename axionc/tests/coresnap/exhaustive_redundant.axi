



      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret 2  ; Δ{}
    Blue ->
    Red ->
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  --> axionc/tests/fixtures/exhaustive_redundant.axi:3:10
  ; Δ{}
  ; Δ{}
  ; Δ{}
  = help: remove the redundant arm, or the earlier wildcard.
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = con Red  ; Δ{}
  ret 0  ; Δ{}
  ret call rank _t0  ; Δ{}
  ret case c of
  ret rtcall axion_array_free _p  ; Δ{}
  |
  |          ^ this arm can never match
3 | rank c = case c of
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
rank c  =
warning[AX0203]: unreachable pattern after a catch-all
