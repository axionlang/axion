







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
  drop _t2 : String
  else
  let _d1000000 = putStrLn _t2  ; Δ{_t2}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call apply$$hoflam10 20  ; Δ{}
  let _t1 = call add _t0 21  ; Δ{}
  let _t2 = call show$Int _t1  ; Δ{} · makes String
  ret + n 1  ; Δ{}
  ret + x y  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call hoflam10 x  ; Δ{}
  ret callclo f x  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
add x y  =
apply f x  =
apply$$hoflam10 x  =
axion_drop_Array _p  =
axion_drop_List _p  =
hoflam10 n  =
main  =
show$Int x  =
