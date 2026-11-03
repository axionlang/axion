
















                                          let _t45 = - py 60  ; Δ{}
                                          ret call loop win ren n idx z px _t45  ; Δ{}
                                          ret call loop win ren n idx z px py  ; Δ{}
                                        else
                                        let _t43 = + py 60  ; Δ{}
                                        let _t44 = == key 106  ; Δ{}
                                        ret call loop win ren n idx z px _t43  ; Δ{}
                                        ret if _t44 then
                                      else
                                      let _t41 = - px 60  ; Δ{}
                                      let _t42 = == key 107  ; Δ{}
                                      ret call loop win ren n idx z _t41 py  ; Δ{}
                                      ret if _t42 then
                                    else
                                    let _t39 = + px 60  ; Δ{}
                                    let _t40 = == key 108  ; Δ{}
                                    ret call loop win ren n idx z _t39 py  ; Δ{}
                                    ret if _t40 then
                                  else
                                  let _t38 = == key 104  ; Δ{}
                                  ret - curPct 10  ; Δ{}
                                  ret 10  ; Δ{}
                                  ret call loop win ren n idx 0 0 0  ; Δ{}
                                  ret if _t38 then
                                else
                                else
                                let _t34 = - curPct 10  ; Δ{}
                                let _t35 = < _t34 10  ; Δ{}
                                let _t36 = if _t35 then
                                let _t37 = == key 48  ; Δ{}
                                ret call loop win ren n idx _t36 px py  ; Δ{}
                                ret if _t37 then
                              else
                              let _t32 = + curPct 10  ; Δ{}
                              let _t33 = == key 45  ; Δ{}
                              ret call loop win ren n idx _t32 px py  ; Δ{}
                              ret if _t33 then
                            else
                            let _t30 = + curPct 10  ; Δ{}
                            let _t31 = == key 61  ; Δ{}
                            ret call loop win ren n idx _t30 px py  ; Δ{}
                            ret if _t31 then
                          else
                          let _t28 = - n 1  ; Δ{}
                          let _t29 = == key 43  ; Δ{}
                          ret call loop win ren n _t28 0 0 0  ; Δ{}
                          ret if _t29 then
                        else
                        let _t27 = == key 1073741901  ; Δ{}
                        ret call loop win ren n 0 0 0 0  ; Δ{}
                        ret if _t27 then
                      else
                      let _t26 = == key 1073741898  ; Δ{}
                      ret call loop win ren n 0 0 0 0  ; Δ{}
                      ret if _t26 then
                    else
                    let _t22 = + idx n  ; Δ{}
                    let _t23 = - _t22 1  ; Δ{}
                    let _t24 = mod _t23 n  ; Δ{}
                    let _t25 = == key 103  ; Δ{}
                    ret call loop win ren n _t24 0 0 0  ; Δ{}
                    ret if _t25 then
                  else
                  let _t18 = + idx n  ; Δ{}
                  let _t19 = - _t18 1  ; Δ{}
                  let _t20 = mod _t19 n  ; Δ{}
                  let _t21 = == key 1073741904  ; Δ{}
                  ret call loop win ren n _t20 0 0 0  ; Δ{}
                  ret if _t21 then
                else
                let _t15 = + idx 1  ; Δ{}
                let _t16 = mod _t15 n  ; Δ{}
                let _t17 = == key 112  ; Δ{}
                ret call loop win ren n _t16 0 0 0  ; Δ{}
                ret if _t17 then
              else
              let _t12 = + idx 1  ; Δ{}
              let _t13 = mod _t12 n  ; Δ{}
              let _t14 = == key 1073741903  ; Δ{}
              ret call loop win ren n _t13 0 0 0  ; Δ{}
              ret if _t14 then
            else
            let _t10 = mod _t9 n  ; Δ{}
            let _t11 = == key 32  ; Δ{}
            let _t9 = + idx 1  ; Δ{}
            ret call loop win ren n _t10 0 0 0  ; Δ{}
            ret if _t11 then
          else
          let _t7 = ffi SDL_Quit 0  ; Δ{}
          let _t8 = == key 110  ; Δ{}
          ret call quitWith _t7  ; Δ{}
          ret if _t8 then
        else
        let _t5 = ffi SDL_Quit 0  ; Δ{}
        let _t6 = == key 27  ; Δ{}
        ret call quitWith _t5  ; Δ{}
        ret if _t6 then
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = * ow 100  ; Δ{path}
      let _t3 = div _t2 tw  ; Δ{path}
      let _t4 = * oh 100  ; Δ{path}
      let _t4 = + i 1  ; Δ{}
      let _t4 = == key 113  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t5 = div _t4 th  ; Δ{path}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 100  ; Δ{path}
      ret call imin _t3 _t5  ; Δ{path}
      ret call lastIndex c s _t4 i  ; Δ{}
      ret call lastIndex c s _t5 best  ; Δ{}
      ret call loop win ren n idx z px py  ; Δ{}
      ret if _t4 then
    drop _t1 : String
    drop _t3 : String
    drop _t5 : String
    drop dst : String
    else
    else
    else
    else
    let _d1000000 = ffi SDL_RenderCopy ren tex 0 dst  ; Δ{dst}
    let _d1000000 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
    let _d1000001 = rtcall axion_strcat _t5 "%"  ; Δ{_t0 _t2 _t3 _t5} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + k 1  ; Δ{}
    let _t1 = - 0 1  ; Δ{}
    let _t1 = > th 0  ; Δ{path}
    let _t1 = rtcall axion_chr 1  ; Δ{} · makes String
    let _t10 = * th z  ; Δ{}
    let _t11 = - ow dw  ; Δ{}
    let _t12 = div _t11 2  ; Δ{}
    let _t13 = + _t12 px  ; Δ{}
    let _t14 = - oh dh  ; Δ{}
    let _t15 = div _t14 2  ; Δ{}
    let _t16 = + _t15 py  ; Δ{}
    let _t2 = * i 0  ; Δ{}
    let _t2 = - n 1  ; Δ{_t1}
    let _t2 = ffi SDL_Quit 0  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t3 = + i 1  ; Δ{}
    let _t3 = + win _t2  ; Δ{}
    let _t3 = - _t2 k  ; Δ{}
    let _t3 = == _t2 c  ; Δ{}
    let _t3 = == ty 768  ; Δ{}
    let _t3 = call fillBuf _t2  ; Δ{_t1} · makes String
    let _t4 = - _t3 1  ; Δ{}
    let _t5 = showInt z  ; Δ{_t0 _t2 _t3} · makes String
    let _t9 = * tw z  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let dh = div _t10 100  ; Δ{}
    let dst = call mkRect _t13 _t16 dw dh  ; Δ{} · makes String
    let dw = div _t9 100  ; Δ{}
    let i = ffi SDL_Init 32  ; Δ{}
    let ren = ffi SDL_CreateRenderer win _t1 0  ; Δ{}
    let win = ffi SDL_CreateWindow "imv" 805240832 805240832 1000 700 36  ; Δ{}
    ret ""  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 100  ; Δ{path}
    ret == x y  ; Δ{}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret _d1000000  ; Δ{}
    ret _d1000001  ; Δ{_d1000001 _t0 _t2 _t3} · moves{_d1000001}
    ret a  ; Δ{}
    ret b  ; Δ{b} · moves{b}
    ret b  ; Δ{b} · moves{b}
    ret b  ; Δ{}
    ret best  ; Δ{}
    ret call argCount _t3  ; Δ{}
    ret call loop _t3 ren n 0 0 0 0  ; Δ{}
    ret call quitWith _t2  ; Δ{}
    ret ffi SDL_RenderCopy ren tex 0 0  ; Δ{}
    ret ffi SDL_RenderSetLogicalSize ren 0 0  ; Δ{}
    ret ffi SDL_RenderSetLogicalSize ren tw th  ; Δ{}
    ret fitPct  ; Δ{}
    ret i  ; Δ{}
    ret if _t1 then
    ret if _t3 then
    ret if _t3 then
    ret putStrLn "usage: imv -- <image>..."  ; Δ{}
    ret rtcall axion_strcat "fit" ""  ; Δ{_t0 _t2 _t3} · makes String
    ret rtcall axion_strcat s ""  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 s  ; Δ{} · makes String
    ret z  ; Δ{}
  ; Δ{_t0 _t2 _t3}
  ; Δ{b}
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  drop _t0 : String
  drop _t1 : String
  drop _t10 : String
  drop _t11 : String
  drop _t12 : String
  drop _t2 : String
  drop _t2 : String
  drop _t3 : String
  drop _t6 : String
  drop _t6 : String
  drop _t7 : String
  drop _t8 : String
  drop _t9 : String
  drop ev : String
  drop hbuf : String
  drop ohb : String
  drop owb : String
  drop path : String
  drop wbuf : String
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
  else
  else
  else
  else
  let _d1000000 = putStrLn _t2  ; Δ{_t2}
  let _d1000000 = rtcall axion_strcat _t0 _t12  ; Δ{_t0 _t12} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = * q 0  ; Δ{}
  let _t0 = - 0 1  ; Δ{}
  let _t0 = < a b  ; Δ{}
  let _t0 = < k 0  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = == z 0  ; Δ{}
  let _t0 = > tw 0  ; Δ{path}
  let _t0 = call baseName path  ; Δ{} · makes String
  let _t0 = rtcall axion_getarg i  ; Δ{} · makes String
  let _t0 = rtcall axion_poke_u32 b 0 x  ; Δ{b}
  let _t0 = rtcall axion_str_at o s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = + idx 1  ; Δ{_t0}
  let _t1 = + o 1  ; Δ{}
  let _t1 = == ty 256  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = rtcall axion_poke_u32 b 4 y  ; Δ{b}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t10 = rtcall axion_str_at _t9 s  ; Δ{}
  let _t10 = rtcall axion_strcat "/" _t9  ; Δ{_t0 _t2 _t9} · makes String
  let _t11 = * _t10 16777216  ; Δ{}
  let _t11 = rtcall axion_strcat _t2 _t10  ; Δ{_t0 _t10 _t2} · makes String
  let _t12 = rtcall axion_strcat " (" _t11  ; Δ{_t0 _t11} · makes String
  let _t17 = + qt gos  ; Δ{ev}
  let _t18 = + _t17 a0  ; Δ{ev}
  let _t19 = + _t18 aL  ; Δ{ev}
  let _t2 = + _t0 _t1  ; Δ{b}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = rtcall axion_str_at _t1 s  ; Δ{}
  let _t2 = rtcall axion_strcat "bye " _t1  ; Δ{_t1} · makes String
  let _t2 = showInt _t1  ; Δ{_t0} · makes String
  let _t20 = + _t19 a1  ; Δ{ev}
  let _t21 = + _t20 a2  ; Δ{ev}
  let _t22 = + _t21 a3  ; Δ{ev}
  let _t23 = + _t22 a4  ; Δ{ev}
  let _t24 = + _t23 a5  ; Δ{ev}
  let _t25 = + _t24 a6  ; Δ{ev}
  let _t26 = + _t25 we  ; Δ{ev}
  let _t27 = call u32 ev 0  ; Δ{ev}
  let _t28 = call u32 ev 20  ; Δ{ev}
  let _t3 = * _t2 256  ; Δ{}
  let _t3 = rtcall axion_poke_u32 b 8 w  ; Δ{b}
  let _t3 = showInt n  ; Δ{_t0 _t2} · makes String
  let _t4 = + _t0 _t3  ; Δ{}
  let _t4 = + _t2 _t3  ; Δ{b}
  let _t4 = == z 0  ; Δ{_t0 _t2 _t3}
  let _t5 = + o 2  ; Δ{}
  let _t5 = rtcall axion_poke_u32 b 12 h  ; Δ{b}
  let _t6 = < t 1  ; Δ{b}
  let _t6 = call titleFor path idx n z  ; Δ{path} · makes String
  let _t6 = if _t4 then
  let _t6 = rtcall axion_str_at _t5 s  ; Δ{}
  let _t7 = * _t6 65536  ; Δ{}
  let _t7 = == z 0  ; Δ{}
  let _t7 = rtcall axion_strcat _t6 " — imv"  ; Δ{_t0 _t2 _t3} · makes String
  let _t8 = + _t4 _t7  ; Δ{}
  let _t8 = == z 0  ; Δ{}
  let _t8 = rtcall axion_strcat ") " _t7  ; Δ{_t0 _t2 _t3 _t7} · makes String
  let _t9 = + o 3  ; Δ{}
  let _t9 = rtcall axion_strcat _t3 _t8  ; Δ{_t0 _t2 _t3 _t8} · makes String
  let a0 = ffi SDL_SetWindowTitle win _t6  ; Δ{_t6}
  let a1 = ffi SDL_SetRenderDrawColor ren 0 0 0 255  ; Δ{}
  let a2 = ffi SDL_RenderClear ren  ; Δ{}
  let a3 = if _t8 then
  let a4 = ffi SDL_RenderPresent ren  ; Δ{}
  let a5 = ffi SDL_DestroyTexture tex  ; Δ{}
  let a6 = ffi SDL_FreeSurface surf  ; Δ{}
  let aL = if _t7 then
  let b = call fillBuf 16  ; Δ{} · makes String
  let curPct = if _t0 then
  let ev = call fillBuf 128  ; Δ{} · makes String
  let fitPct = if _t0 then
  let gos = ffi SDL_GetRendererOutputSize ren owb ohb  ; Δ{ohb owb path}
  let hbuf = call fillBuf 4  ; Δ{path wbuf} · makes String
  let n = call argCount 0  ; Δ{}
  let oh = call u32 ohb 0  ; Δ{ohb path}
  let ohb = call fillBuf 4  ; Δ{owb path} · makes String
  let ow = call u32 owb 0  ; Δ{ohb owb path}
  let owb = call fillBuf 4  ; Δ{path} · makes String
  let path = rtcall axion_getarg idx  ; Δ{} · makes String
  let qt = ffi SDL_QueryTexture tex 0 0 wbuf hbuf  ; Δ{hbuf path wbuf}
  let surf = ffi IMG_Load path  ; Δ{path}
  let t = + _t4 _t5  ; Δ{b}
  let tex = ffi SDL_CreateTextureFromSurface ren surf  ; Δ{path}
  let th = call u32 hbuf 0  ; Δ{hbuf path}
  let tok = * _t26 0  ; Δ{ev}
  let tw = call u32 wbuf 0  ; Δ{hbuf path wbuf}
  let ty = + _t27 tok  ; Δ{ev}
  let wbuf = call fillBuf 4  ; Δ{path} · makes String
  let we = ffi SDL_WaitEvent ev  ; Δ{ev}
  ret + _t8 _t11  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{}
  ret call baseAfter s _t1  ; Δ{} · makes String
  ret call dispatch win ren n idx z px py fitPct ty _t28  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t1 then
  ret if _t2 then
  ret if _t6 then
  ret rtcall axion_array_free _p  ; Δ{}
>=$Int x y  =
argCount i  =
axion_drop_Array _p  =
axion_drop_List _p  =
baseAfter s k  =
baseName s  =
dispatch win ren n idx z px py fitPct ty key  =
fillBuf n  =
imin a b  =
lastIndex c s i best  =
le$Int x y  =
loop win ren n idx z px py  =
main  =
mkRect x y w h  =
quitWith q  =
titleFor path idx n z  =
u32 s o  =
