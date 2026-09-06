


      drop _t3 : String
      drop _t5 : String
      drop _t6 : String
      let _d1000000 = putStrLn _t6  ; Δ{_t6}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = rtcall axion_read_secret 0  ; Δ{} · makes String
      let _t4 = rtcall axion_str_len _t3  ; Δ{_t3}
      let _t5 = showInt _t4  ; Δ{} · makes String
      let _t6 = rtcall axion_strcat "secret-len:" _t5  ; Δ{_t5} · makes String
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
  drop _t1 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = rtcall axion_read_line 0  ; Δ{} · makes String
  let _t1 = rtcall axion_strcat "line:" _t0  ; Δ{_t0} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret 0  ; Δ{}
  ret case _t2 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
