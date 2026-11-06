


      drop _t2 : String
      let _d1000000 = putStrLn _t2  ; Δ{_t2}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = showInt s  ; Δ{} · makes String
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{}
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
  drop _t0 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = showInt r  ; Δ{} · makes String
  let _t1 = putStrLn _t0  ; Δ{_t0}
  let a = 2  ; Δ{}
  let b = 3  ; Δ{}
  let r = + x 1  ; Δ{}
  let s = * a b  ; Δ{}
  let x = 10  ; Δ{}
  ret 0  ; Δ{}
  ret case _t1 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
