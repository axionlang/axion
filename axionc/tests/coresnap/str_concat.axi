



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
  drop _t0 : String
  drop _t1 : String
  drop _t2 : String
  else
  let _d1000000 = putStrLn _t2  ; Δ{_t2}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call show$Int 42  ; Δ{} · makes String
  let _t1 = rtcall axion_strcat _t0 "!"  ; Δ{_t0} · makes String
  let _t2 = rtcall axion_strcat "n=" _t1  ; Δ{_t1} · makes String
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
show$Int x  =
