





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
  --> axionc/tests/fixtures/dropped_effect_where.axi:9:5
  ; Δ{}
  ; Δ{}
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call run$body  ; Δ{}
  ret 0  ; Δ{}
  ret 7  ; Δ{}
  ret _t0  ; Δ{}
  ret call run 0  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_system "true"  ; Δ{}
  |
  |     ^ move it into a `do` block or a `let` in the body to sequence the effect
9 |     _fx  = runStatus "true"
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
run d  =
run$_fx  =
run$body  =
warning[AX0920]: effectful binding `_fx` in `where` is never used — its effect will not run
