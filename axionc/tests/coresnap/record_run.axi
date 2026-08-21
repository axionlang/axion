




axion_drop_Array _p  =
axion_drop_List _p  =
  drop _t0 : Point
  drop _t1 : Point
  drop _t3 : String
    else
  else
  let _d1000000 = putStrLn _t3  ; Δ{_t3}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = record Point { x = 1 y = 2}  ; Δ{} · makes Point
  let _t1 = call shiftX _t0  ; Δ{_t0} · makes Point
  let _t2 = field x _t1  ; Δ{_t1}
  let _t3 = call show$Int _t2  ; Δ{} · makes String
    let _tag = loadraw _p+0  ; Δ{}
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret update p { x = 99}  ; Δ{} · makes heap
shiftX p  =
show$Int x  =
  ; Δ{}
  ; Δ{}
