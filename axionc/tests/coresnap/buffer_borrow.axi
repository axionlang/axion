



      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _t0  ; Δ{}
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
  drop _t2 : String
  else
  let _d1000000 = putStrLn _t2  ; Δ{_t2}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = - p p  ; Δ{}
  let _t0 = call useBuf b  ; Δ{b} · moves{b}
  let _t1 = + _t0 w  ; Δ{}
  let _t1 = rtcall axion_buf_free b  ; Δ{}
  let _t2 = showInt _t1  ; Δ{} · makes String
  let b = rtcall axion_buf_new 16  ; Δ{} · makes Buffer
  let p = rtcall axion_buf_ptr b  ; Δ{}
  let w = rtcall axion_poke_u32 b 0 777  ; Δ{b}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case _t1 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
useBuf b  =
