


      drop _t2 : String
      drop _t3 : String
      let _d1000000 = putStr _t3  ; Δ{_t3}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = rtcall axion_chr 27  ; Δ{} · makes String
      let _t3 = rtcall axion_strcat _t2 "[2J"  ; Δ{_t2} · makes String
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
  let _t0 = rtcall axion_chr 65  ; Δ{} · makes String
  let _t1 = putStr _t0  ; Δ{_t0}
  ret 0  ; Δ{}
  ret case _t1 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
