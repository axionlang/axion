




















                                              drop ev : Buffer
                                              let _t24 = rtcall axion_peek_u32 ev 0  ; Δ{ev}
                                              let _t25 = rtcall axion_peek_u32 ev 20  ; Δ{ev}
                                              ret call dispatch win ren n idx z px py fitPct _t24 _t25  ; Δ{}
                                            _ ->
                                          let _t22 = rtcall axion_buf_ptr_n ev 128  ; Δ{ev}
                                          let _t23 = ffi SDL_WaitEvent _t22  ; Δ{ev}
                                          let ev = rtcall axion_buf_new 128  ; Δ{} · makes Buffer
                                          ret case _t23 of
                                        _ ->
                                      let _t21 = ffi SDL_FreeSurface surf  ; Δ{}
                                      ret case _t21 of
                                    _ ->
                                  let _t20 = ffi SDL_DestroyTexture tex  ; Δ{}
                                  ret case _t20 of
                                _ ->
                              let _t19 = ffi SDL_RenderPresent ren  ; Δ{}
                              ret case _t19 of
                            _ ->
                          let _t18 = call renderAt ren tex z tw th ow oh px py  ; Δ{}
                          ret case _t18 of
                        _ ->
                      let _t17 = ffi SDL_RenderClear ren  ; Δ{}
                      ret case _t17 of
                    _ ->
                  let _t16 = ffi SDL_SetRenderDrawColor ren 0 0 0 255  ; Δ{}
                  ret case _t16 of
                _ ->
                ret ffi SDL_RenderSetLogicalSize ren 0 0  ; Δ{}
                ret ffi SDL_RenderSetLogicalSize ren tw th  ; Δ{}
              else
              let _t10 = * oh 100  ; Δ{path}
              let _t11 = div _t10 th  ; Δ{path}
              let _t14 = == z 0  ; Δ{}
              let _t15 = if _t14 then
              let _t8 = * ow 100  ; Δ{path}
              let _t9 = div _t8 tw  ; Δ{path}
              ret 100  ; Δ{path}
              ret call imin _t9 _t11  ; Δ{path}
              ret case _t15 of
              ret putStrLn "bye"  ; Δ{}
            _ ->
            _ ->
            else
            let _t7 = > th 0  ; Δ{path}
            ret 100  ; Δ{path}
            ret if _t7 then
          drop _t12 : String
          drop ohb : Buffer
          drop owb : Buffer
          drop path : String
          else
          let _t12 = call titleFor path idx n z  ; Δ{path} · makes String
          let _t13 = ffi SDL_SetWindowTitle win _t12  ; Δ{_t12}
          let _t2 = ffi SDL_Quit 0  ; Δ{}
          let _t6 = > tw 0  ; Δ{path}
          let fitPct = if _t6 then
          let oh = rtcall axion_peek_u32 ohb 0  ; Δ{ohb path}
          let ow = rtcall axion_peek_u32 owb 0  ; Δ{ohb owb path}
          ret case _t13 of
          ret case _t2 of
        _ ->
        _ ->
        let _t2 = - 0 1  ; Δ{}
        let ren = ffi SDL_CreateRenderer win _t2 0  ; Δ{}
        let win = ffi SDL_CreateWindow "imv" 805240832 805240832 1000 700 36  ; Δ{}
        ret - curPct 2  ; Δ{}
        ret 2  ; Δ{}
        ret _t9  ; Δ{}
        ret call loop win ren n 0 0 0 0  ; Δ{}
      _ ->
      _ ->
      drop hbuf : Buffer
      drop wbuf : Buffer
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t0 = + idx 1  ; Δ{}
      let _t1 = ffi SDL_DestroyWindow win [o]  ; Δ{}
      let _t1 = mod _t0 n  ; Δ{}
      let _t10 = - _t9 1  ; Δ{}
      let _t11 = mod _t10 n  ; Δ{}
      let _t12 = - n 1  ; Δ{}
      let _t13 = + curPct 2  ; Δ{}
      let _t14 = + curPct 2  ; Δ{}
      let _t15 = - curPct 2  ; Δ{}
      let _t16 = < _t15 2  ; Δ{}
      let _t17 = if _t16 then
      let _t18 = - px 10  ; Δ{}
      let _t19 = + px 10  ; Δ{}
      let _t2 = + idx 1  ; Δ{}
      let _t20 = - py 10  ; Δ{}
      let _t21 = + py 10  ; Δ{}
      let _t3 = mod _t2 n  ; Δ{}
      let _t3 = rtcall axion_buf_ptr_n owb 4  ; Δ{ohb owb path}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + idx 1  ; Δ{}
      let _t4 = rtcall axion_buf_ptr_n ohb 4  ; Δ{ohb owb path}
      let _t5 = + i 1  ; Δ{}
      let _t5 = ffi SDL_GetRendererOutputSize ren _t3 _t4  ; Δ{ohb owb path}
      let _t5 = mod _t4 n  ; Δ{}
      let _t6 = + idx n  ; Δ{}
      let _t7 = - _t6 1  ; Δ{}
      let _t8 = mod _t7 n  ; Δ{}
      let _t9 = + idx n  ; Δ{}
      let ohb = rtcall axion_buf_new 4  ; Δ{owb path} · makes Buffer
      let owb = rtcall axion_buf_new 4  ; Δ{path} · makes Buffer
      let th = rtcall axion_peek_u32 hbuf 0  ; Δ{hbuf path}
      let tw = rtcall axion_peek_u32 wbuf 0  ; Δ{hbuf path wbuf}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret call lastIndex c s _t4 i  ; Δ{}
      ret call lastIndex c s _t5 best  ; Δ{}
      ret call loop win ren n 0 0 0 0  ; Δ{}
      ret call loop win ren n 0 0 0 0  ; Δ{}
      ret call loop win ren n _t1 0 0 0  ; Δ{}
      ret call loop win ren n _t11 0 0 0  ; Δ{}
      ret call loop win ren n _t12 0 0 0  ; Δ{}
      ret call loop win ren n _t3 0 0 0  ; Δ{}
      ret call loop win ren n _t5 0 0 0  ; Δ{}
      ret call loop win ren n _t8 0 0 0  ; Δ{}
      ret call loop win ren n idx 0 0 0  ; Δ{}
      ret call loop win ren n idx _t13 px py  ; Δ{}
      ret call loop win ren n idx _t14 px py  ; Δ{}
      ret call loop win ren n idx _t17 px py  ; Δ{}
      ret call loop win ren n idx z _t18 py  ; Δ{}
      ret call loop win ren n idx z _t19 py  ; Δ{}
      ret call loop win ren n idx z px _t20  ; Δ{}
      ret call loop win ren n idx z px _t21  ; Δ{}
      ret call loop win ren n idx z px py  ; Δ{}
      ret call loop win ren n idx z px py  ; Δ{}
      ret call onKey win ren n idx z px py curPct key  ; Δ{}
      ret call quitWith win ren  ; Δ{}
      ret call quitWith win ren  ; Δ{}
      ret call quitWith win ren  ; Δ{}
      ret case _t1 of
      ret case _t5 of
    103 ->
    104 ->
    106 ->
    107 ->
    1073741898 ->
    1073741901 ->
    1073741903 ->
    1073741904 ->
    108 ->
    110 ->
    112 ->
    113 ->
    256 ->
    27 ->
    32 ->
    43 ->
    45 ->
    48 ->
    61 ->
    768 ->
    _ ->
    _ ->
    _ ->
    _ ->
    drop _t5 : String
    else
    else
    let _d1000001 = rtcall axion_strcat _t5 "%"  ; Δ{_t0 _t2 _t3 _t5} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = * tw z  ; Δ{}
    let _t1 = + k 1  ; Δ{}
    let _t1 = ffi SDL_Init 32  ; Δ{}
    let _t10 = rtcall axion_buf_free dst  ; Δ{dst} · moves{dst}
    let _t2 = * th z  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t3 = + i 1  ; Δ{}
    let _t3 = - _t2 k  ; Δ{}
    let _t3 = - ow dw  ; Δ{}
    let _t3 = == _t2 c  ; Δ{}
    let _t4 = - _t3 1  ; Δ{}
    let _t4 = div _t3 2  ; Δ{}
    let _t5 = + _t4 px  ; Δ{}
    let _t5 = showInt z  ; Δ{_t0 _t2 _t3} · makes String
    let _t6 = - oh dh  ; Δ{}
    let _t7 = div _t6 2  ; Δ{}
    let _t8 = + _t7 py  ; Δ{}
    let _t9 = ffi SDL_RenderCopy ren tex 0 p  ; Δ{dst}
    let _tag = loadraw _p+0  ; Δ{}
    let dh = div _t2 100  ; Δ{}
    let dst = call mk__SDL_Rect _t5 _t8 dw dh  ; Δ{} · makes Buffer
    let dw = div _t1 100  ; Δ{}
    let p = rtcall axion_buf_ptr dst  ; Δ{dst}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret _d1000001  ; Δ{_d1000001 _t0 _t2 _t3} · moves{_d1000001}
    ret a  ; Δ{}
    ret axsb  ; Δ{axsb} · moves{axsb}
    ret axsb  ; Δ{axsb} · moves{axsb}
    ret b  ; Δ{}
    ret best  ; Δ{}
    ret call argCount _t3  ; Δ{}
    ret case _t1 of
    ret case _t10 of
    ret ffi SDL_RenderCopy ren tex 0 0  ; Δ{}
    ret fitPct  ; Δ{}
    ret i  ; Δ{}
    ret if _t3 then
    ret putStrLn "usage: imv -- <image>..."  ; Δ{}
    ret rtcall axion_strcat "fit" ""  ; Δ{_t0 _t2 _t3} · makes String
    ret rtcall axion_strcat s ""  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 s  ; Δ{} · makes String
    ret z  ; Δ{}
  ; Δ{_t0 _t2 _t3}
  ; Δ{axsb}
  ; Δ{ev}
  ; Δ{hbuf path wbuf}
  ; Δ{ohb owb path}
  ; Δ{path}
  ; Δ{path}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  drop _t0 : String
  drop _t10 : String
  drop _t11 : String
  drop _t12 : String
  drop _t2 : String
  drop _t3 : String
  drop _t6 : String
  drop _t7 : String
  drop _t8 : String
  drop _t9 : String
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = rtcall axion_strcat _t0 _t12  ; Δ{_t0 _t12} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = - 0 1  ; Δ{}
  let _t0 = < a b  ; Δ{}
  let _t0 = < k 0  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = == z 0  ; Δ{}
  let _t0 = == z 0  ; Δ{}
  let _t0 = call baseName path  ; Δ{} · makes String
  let _t0 = ffi SDL_DestroyRenderer ren [o]  ; Δ{}
  let _t0 = rtcall axion_buf_ptr_n wbuf 4  ; Δ{hbuf path wbuf}
  let _t0 = rtcall axion_getarg i  ; Δ{} · makes String
  let _t0 = rtcall axion_poke_u32 axsb 0 x  ; Δ{axsb}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = + idx 1  ; Δ{_t0}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = rtcall axion_buf_ptr_n hbuf 4  ; Δ{hbuf path wbuf}
  let _t1 = rtcall axion_poke_u32 axsb 4 y  ; Δ{axsb}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t10 = rtcall axion_strcat "/" _t9  ; Δ{_t0 _t2 _t9} · makes String
  let _t11 = rtcall axion_strcat _t2 _t10  ; Δ{_t0 _t10 _t2} · makes String
  let _t12 = rtcall axion_strcat " (" _t11  ; Δ{_t0 _t11} · makes String
  let _t2 = + _t0 _t1  ; Δ{axsb}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = ffi SDL_QueryTexture tex 0 0 _t0 _t1  ; Δ{hbuf path wbuf}
  let _t2 = showInt _t1  ; Δ{_t0} · makes String
  let _t3 = rtcall axion_poke_u32 axsb 8 w  ; Δ{axsb}
  let _t3 = showInt n  ; Δ{_t0 _t2} · makes String
  let _t4 = + _t2 _t3  ; Δ{axsb}
  let _t4 = == z 0  ; Δ{_t0 _t2 _t3}
  let _t5 = rtcall axion_poke_u32 axsb 12 h  ; Δ{axsb}
  let _t6 = < axst 1  ; Δ{axsb}
  let _t6 = if _t4 then
  let _t7 = rtcall axion_strcat _t6 " — imv"  ; Δ{_t0 _t2 _t3} · makes String
  let _t8 = rtcall axion_strcat ") " _t7  ; Δ{_t0 _t2 _t3 _t7} · makes String
  let _t9 = rtcall axion_strcat _t3 _t8  ; Δ{_t0 _t2 _t3 _t8} · makes String
  let axsb = rtcall axion_buf_new 16  ; Δ{} · makes Buffer
  let axst = + _t4 _t5  ; Δ{axsb}
  let curPct = if _t0 then
  let hbuf = rtcall axion_buf_new 4  ; Δ{path wbuf} · makes Buffer
  let n = call argCount 0  ; Δ{}
  let path = rtcall axion_getarg idx  ; Δ{} · makes String
  let surf = ffi IMG_Load path  ; Δ{path}
  let tex = ffi SDL_CreateTextureFromSurface ren surf  ; Δ{path}
  let wbuf = rtcall axion_buf_new 4  ; Δ{path} · makes Buffer
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret call baseAfter s _t1  ; Δ{} · makes String
  ret call le$Int y x  ; Δ{}
  ret case _t0 of
  ret case _t2 of
  ret case key of
  ret case ty of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t2 then
  ret if _t6 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_peek_u32 axsr 0  ; Δ{}
  ret rtcall axion_peek_u32 axsr 12  ; Δ{}
  ret rtcall axion_peek_u32 axsr 4  ; Δ{}
  ret rtcall axion_peek_u32 axsr 8  ; Δ{}
>=$Int x y  =
argCount i  =
axion_drop_Array _p  =
axion_drop_List _p  =
baseAfter s k  =
baseName s  =
dispatch win ren n idx z px py fitPct ty key  =
h axsr  =
imin a b  =
lastIndex c s i best  =
le$Int x y  =
loop win ren n idx z px py  =
main  =
mk__SDL_Rect x y w h  =
onKey win ren n idx z px py curPct key  =
quitWith win ren  =
renderAt ren tex z tw th ow oh px py  =
titleFor path idx n z  =
w axsr  =
x axsr  =
y axsr  =
