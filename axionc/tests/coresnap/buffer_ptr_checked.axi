


      drop _t11 : String
      drop b : Buffer
      let _d1000000 = putStrLn _t11  ; Δ{_t11}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t10 = + _t8 _t9  ; Δ{}
      let _t11 = showInt _t10  ; Δ{} · makes String
      let _t8 = rtcall axion_peek_u32 b 4  ; Δ{b}
      let _t9 = - p4 p4  ; Δ{}
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
  ; Δ{b}
  ; Δ{}
  ; Δ{}
  drop _t6 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = rtcall axion_poke_u32 b 0 11  ; Δ{b}
  let _t1 = rtcall axion_poke_u32 b 4 22  ; Δ{b}
  let _t2 = rtcall axion_peek_u32 b 0  ; Δ{b}
  let _t3 = + _t2 w  ; Δ{b}
  let _t4 = - p16 p16  ; Δ{b}
  let _t5 = + _t3 _t4  ; Δ{b}
  let _t6 = showInt _t5  ; Δ{b} · makes String
  let _t7 = putStrLn _t6  ; Δ{_t6 b}
  let b = rtcall axion_buf_new 16  ; Δ{} · makes Buffer
  let p16 = rtcall axion_buf_ptr_n b 16  ; Δ{b}
  let p4 = rtcall axion_buf_ptr_n b 4  ; Δ{b}
  let w = + _t0 _t1  ; Δ{b}
  ret 0  ; Δ{}
  ret case _t7 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
