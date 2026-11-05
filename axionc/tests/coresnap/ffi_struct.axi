











              drop _t16 : String
              drop p : Buffer
              let _d1000000 = putStrLn _t16  ; Δ{_t16}
              let _t15 = call c p  ; Δ{p}
              let _t16 = showInt _t15  ; Δ{} · makes String
              ret _d1000000  ; Δ{}
            _ ->
          drop _t13 : String
          let _t12 = call b p  ; Δ{p}
          let _t13 = showInt _t12  ; Δ{p} · makes String
          let _t14 = putStrLn _t13  ; Δ{_t13 p}
          ret case _t14 of
        _ ->
      drop _t10 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t10 = showInt _t9  ; Δ{p} · makes String
      let _t11 = putStrLn _t10  ; Δ{_t10 p}
      let _t9 = call a p  ; Δ{p}
      let p = call mk__Pad 1 777 9  ; Δ{} · makes Buffer
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t11 of
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret axsb  ; Δ{axsb} · moves{axsb}
    ret axsb  ; Δ{axsb} · moves{axsb}
    ret axsb  ; Δ{axsb} · moves{axsb}
    ret axsb  ; Δ{axsb} · moves{axsb}
  ; Δ{axsb}
  ; Δ{axsb}
  ; Δ{p}
  ; Δ{p}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t7 : String
  drop r : Buffer
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call x r  ; Δ{r}
  let _t0 = rtcall axion_poke_u32 axsb 0 x  ; Δ{axsb}
  let _t0 = rtcall axion_poke_u8 axsb 0 a  ; Δ{axsb}
  let _t1 = call y r  ; Δ{r}
  let _t1 = rtcall axion_poke_u32 axsb 4 b  ; Δ{axsb}
  let _t1 = rtcall axion_poke_u32 axsb 4 y  ; Δ{axsb}
  let _t2 = + _t0 _t1  ; Δ{axsb}
  let _t2 = + _t0 _t1  ; Δ{axsb}
  let _t2 = + _t0 _t1  ; Δ{r}
  let _t3 = call w r  ; Δ{r}
  let _t3 = rtcall axion_poke_u32 axsb 8 w  ; Δ{axsb}
  let _t3 = rtcall axion_poke_u8 axsb 8 c  ; Δ{axsb}
  let _t4 = + _t2 _t3  ; Δ{axsb}
  let _t4 = + _t2 _t3  ; Δ{r}
  let _t4 = < axst 1  ; Δ{axsb}
  let _t5 = call h r  ; Δ{r}
  let _t5 = rtcall axion_poke_u32 axsb 12 h  ; Δ{axsb}
  let _t6 = + _t4 _t5  ; Δ{}
  let _t6 = < axst 1  ; Δ{axsb}
  let _t7 = showInt _t6  ; Δ{} · makes String
  let _t8 = putStrLn _t7  ; Δ{_t7}
  let axsb = rtcall axion_buf_new 12  ; Δ{} · makes Buffer
  let axsb = rtcall axion_buf_new 16  ; Δ{} · makes Buffer
  let axst = + _t2 _t3  ; Δ{axsb}
  let axst = + _t4 _t5  ; Δ{axsb}
  let r = call mk__SDL_Rect 10 20 640 480  ; Δ{} · makes Buffer
  ret 0  ; Δ{}
  ret case _t8 of
  ret if _t4 then
  ret if _t6 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_peek_u32 axsr 0  ; Δ{}
  ret rtcall axion_peek_u32 axsr 12  ; Δ{}
  ret rtcall axion_peek_u32 axsr 4  ; Δ{}
  ret rtcall axion_peek_u32 axsr 4  ; Δ{}
  ret rtcall axion_peek_u32 axsr 8  ; Δ{}
  ret rtcall axion_peek_u8 axsr 0  ; Δ{}
  ret rtcall axion_peek_u8 axsr 8  ; Δ{}
a axsr  =
axion_drop_Array _p  =
axion_drop_List _p  =
b axsr  =
c axsr  =
h axsr  =
main  =
mk__Pad a b c  =
mk__SDL_Rect x y w h  =
w axsr  =
x axsr  =
y axsr  =
