








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
   --> axionc/tests/fixtures/ffi_effects.axi:22:5
   --> axionc/tests/fixtures/ffi_effects.axi:23:5
   |
   |
   |     ^ move it into a `do` block or a `let` in the body to sequence the effect
   |     ^ move it into a `do` block or a `let` in the body to sequence the effect
  ; Δ{}
  ; Δ{}
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = - 0 7  ; Δ{}
  let _t1 = call apply cabs _t0  ; Δ{}
  let _t2 = call shadowed 1  ; Δ{}
  ret + _t1 _t2  ; Δ{}
  ret + cabs 1  ; Δ{}
  ret 0  ; Δ{}
  ret call logLine "wrapped"  ; Δ{}
  ret callclo f x  ; Δ{}
  ret ffi puts "direct"  ; Δ{}
  ret ffi puts s  ; Δ{}
  ret ffi sqrt 2f [f->f]  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
22 |     direct = cputs "direct"
23 |     wrapped = logLine "wrapped"
apply f x  =
axion_drop_Array _p  =
axion_drop_List _p  =
logLine s  =
main  =
main$direct cputs csqrt  =
main$root cputs csqrt  =
main$wrapped cputs csqrt  =
shadowed cabs  =
warning[AX0920]: effectful binding `direct` in `where` is never used — its effect will not run
warning[AX0920]: effectful binding `wrapped` in `where` is never used — its effect will not run
