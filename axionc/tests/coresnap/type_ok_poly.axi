





      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = - k 1  ; Δ{}
    let _t2 = + acc k  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let acc = _p1  ; Δ{}
    let acc = _p1  ; Δ{}
    let k = _p0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret acc  ; Δ{}
    ret call sumTo$go _t1 _t2  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1 : String
  else
  else
  let _d1000000 = putStrLn _t1  ; Δ{_t1}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = == _p0 0  ; Δ{}
  let _t0 = call sumTo 10  ; Δ{}
  let _t1 = call show$Int _t0  ; Δ{} · makes String
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call sumTo$go n 0  ; Δ{}
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
show$Int x  =
sumTo n  =
sumTo$go _p0 _p1  =
