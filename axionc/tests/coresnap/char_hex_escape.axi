


          drop _t5 : String
          drop _t6 : String
          let _d1000000 = putStr _t6  ; Δ{_t6}
          let _t5 = showInt 97  ; Δ{} · makes String
          let _t6 = rtcall axion_strcat " " _t5  ; Δ{_t5} · makes String
          ret _d1000000  ; Δ{}
        _ ->
      drop _t2 : String
      drop _t3 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = showInt 65  ; Δ{} · makes String
      let _t3 = rtcall axion_strcat " " _t2  ; Δ{_t2} · makes String
      let _t4 = putStr _t3  ; Δ{_t3}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t4 of
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
  drop _t0 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = showInt 27  ; Δ{} · makes String
  let _t1 = putStr _t0  ; Δ{_t0}
  ret 0  ; Δ{}
  ret case _t1 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
