

















                                          let _t42 = - py 60  ; Δ{}
                                          ret call loop win ren n idx z px _t42  ; Δ{}
                                          ret call loop win ren n idx z px py  ; Δ{}
                                        else
                                        let _t40 = + py 60  ; Δ{}
                                        let _t41 = == key 106  ; Δ{}
                                        ret call loop win ren n idx z px _t40  ; Δ{}
                                        ret if _t41 then
                                      else
                                      let _t38 = - px 60  ; Δ{}
                                      let _t39 = == key 107  ; Δ{}
                                      ret call loop win ren n idx z _t38 py  ; Δ{}
                                      ret if _t39 then
                                    else
                                    let _t36 = + px 60  ; Δ{}
                                    let _t37 = == key 108  ; Δ{}
                                    ret call loop win ren n idx z _t36 py  ; Δ{}
                                    ret if _t37 then
                                  else
                                  let _t35 = == key 104  ; Δ{}
                                  ret call loop win ren n idx 0 0 0  ; Δ{}
                                  ret if _t35 then
                                else
                                let _t33 = call zoomOut z  ; Δ{}
                                let _t34 = == key 48  ; Δ{}
                                ret call loop win ren n idx _t33 px py  ; Δ{}
                                ret if _t34 then
                              else
                              let _t31 = call zoomIn z  ; Δ{}
                              let _t32 = == key 45  ; Δ{}
                              ret call loop win ren n idx _t31 px py  ; Δ{}
                              ret if _t32 then
                            else
                            let _t29 = call zoomIn z  ; Δ{}
                            let _t30 = == key 61  ; Δ{}
                            ret call loop win ren n idx _t29 px py  ; Δ{}
                            ret if _t30 then
                          else
                          let _t27 = - n 1  ; Δ{}
                          let _t28 = == key 43  ; Δ{}
                          ret call loop win ren n _t27 0 0 0  ; Δ{}
                          ret if _t28 then
                        else
                        let _t26 = == key 1073741901  ; Δ{}
                        ret call loop win ren n 0 0 0 0  ; Δ{}
                        ret if _t26 then
                      else
                      let _t25 = == key 1073741898  ; Δ{}
                      ret call loop win ren n 0 0 0 0  ; Δ{}
                      ret if _t25 then
                    else
                    let _t21 = + idx n  ; Δ{}
                    let _t22 = - _t21 1  ; Δ{}
                    let _t23 = mod _t22 n  ; Δ{}
                    let _t24 = == key 103  ; Δ{}
                    ret call loop win ren n _t23 0 0 0  ; Δ{}
                    ret if _t24 then
                  else
                  let _t17 = + idx n  ; Δ{}
                  let _t18 = - _t17 1  ; Δ{}
                  let _t19 = mod _t18 n  ; Δ{}
                  let _t20 = == key 1073741904  ; Δ{}
                  ret call loop win ren n _t19 0 0 0  ; Δ{}
                  ret if _t20 then
                else
                let _t14 = + idx 1  ; Δ{}
                let _t15 = mod _t14 n  ; Δ{}
                let _t16 = == key 112  ; Δ{}
                ret call loop win ren n _t15 0 0 0  ; Δ{}
                ret if _t16 then
              else
              let _t11 = + idx 1  ; Δ{}
              let _t12 = mod _t11 n  ; Δ{}
              let _t13 = == key 1073741903  ; Δ{}
              ret call loop win ren n _t12 0 0 0  ; Δ{}
              ret if _t13 then
            else
            let _t10 = == key 32  ; Δ{}
            let _t8 = + idx 1  ; Δ{}
            let _t9 = mod _t8 n  ; Δ{}
            ret call loop win ren n _t9 0 0 0  ; Δ{}
            ret if _t10 then
          else
          let _t6 = ffi SDL_Quit 0  ; Δ{}
          let _t7 = == key 110  ; Δ{}
          ret call quitWith _t6  ; Δ{}
          ret if _t7 then
        else
        let _t4 = ffi SDL_Quit 0  ; Δ{}
        let _t5 = == key 27  ; Δ{}
        ret call quitWith _t4  ; Δ{}
        ret if _t5 then
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = == key 113  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      ret - z 10  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 10  ; Δ{}
      ret call lastIndex c s _t4 i  ; Δ{}
      ret call lastIndex c s _t5 best  ; Δ{}
      ret call loop win ren n idx z px py  ; Δ{}
      ret if _t3 then
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
    let _t1 = - z 10  ; Δ{}
    let _t1 = ffi SDL_Quit 0  ; Δ{}
    let _t1 = rtcall axion_chr 1  ; Δ{} · makes String
    let _t10 = + _t9 py  ; Δ{}
    let _t2 = * i 0  ; Δ{}
    let _t2 = - n 1  ; Δ{_t1}
    let _t2 = < _t1 10  ; Δ{}
    let _t2 = == ty 768  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t3 = * tw z  ; Δ{}
    let _t3 = + i 1  ; Δ{}
    let _t3 = + win _t2  ; Δ{}
    let _t3 = - _t2 k  ; Δ{}
    let _t3 = == _t2 c  ; Δ{}
    let _t3 = call fillBuf _t2  ; Δ{_t1} · makes String
    let _t4 = * th z  ; Δ{}
    let _t4 = - _t3 1  ; Δ{}
    let _t5 = - ow dw  ; Δ{}
    let _t5 = showInt z  ; Δ{_t0 _t2 _t3} · makes String
    let _t6 = div _t5 2  ; Δ{}
    let _t7 = + _t6 px  ; Δ{}
    let _t8 = - oh dh  ; Δ{}
    let _t9 = div _t8 2  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let dh = div _t4 100  ; Δ{}
    let dst = call mkRect _t7 _t10 dw dh  ; Δ{} · makes String
    let dw = div _t3 100  ; Δ{}
    let i = ffi SDL_Init 32  ; Δ{}
    let ren = ffi SDL_CreateRenderer win _t1 0  ; Δ{}
    let win = ffi SDL_CreateWindow "imv" 805240832 805240832 1000 700 36  ; Δ{}
    ret ""  ; Δ{}
    ret + z 10  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 100  ; Δ{}
    ret 90  ; Δ{}
    ret == x y  ; Δ{}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret _d1000000  ; Δ{}
    ret _d1000001  ; Δ{_d1000001 _t0 _t2 _t3} · moves{_d1000001}
    ret b  ; Δ{b} · moves{b}
    ret b  ; Δ{b} · moves{b}
    ret best  ; Δ{}
    ret call argCount _t3  ; Δ{}
    ret call loop _t3 ren n 0 0 0 0  ; Δ{}
    ret call quitWith _t1  ; Δ{}
    ret ffi SDL_RenderCopy ren tex 0 0  ; Δ{}
    ret ffi SDL_RenderSetLogicalSize ren 0 0  ; Δ{}
    ret ffi SDL_RenderSetLogicalSize ren tw th  ; Δ{}
    ret i  ; Δ{}
    ret if _t2 then
    ret if _t2 then
    ret if _t3 then
    ret putStrLn "usage: imv -- <image>..."  ; Δ{}
    ret rtcall axion_strcat "fit" ""  ; Δ{_t0 _t2 _t3} · makes String
    ret rtcall axion_strcat s ""  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 s  ; Δ{} · makes String
  ; Δ{_t0 _t2 _t3}
  ; Δ{b}
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
  drop _t0 : String
  drop _t1 : String
  drop _t10 : String
  drop _t11 : String
  drop _t12 : String
  drop _t2 : String
  drop _t2 : String
  drop _t3 : String
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
  let _d1000000 = putStrLn _t2  ; Δ{_t2}
  let _d1000000 = rtcall axion_strcat _t0 _t12  ; Δ{_t0 _t12} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = * q 0  ; Δ{}
  let _t0 = - 0 1  ; Δ{}
  let _t0 = < k 0  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = == ty 256  ; Δ{}
  let _t0 = == z 0  ; Δ{}
  let _t0 = == z 0  ; Δ{}
  let _t0 = call baseName path  ; Δ{} · makes String
  let _t0 = call titleFor path idx n z  ; Δ{path} · makes String
  let _t0 = rtcall axion_getarg i  ; Δ{} · makes String
  let _t0 = rtcall axion_poke_u32 b 0 x  ; Δ{b}
  let _t0 = rtcall axion_str_at o s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = + idx 1  ; Δ{_t0}
  let _t1 = + o 1  ; Δ{}
  let _t1 = == z 0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = rtcall axion_poke_u32 b 4 y  ; Δ{b}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t10 = rtcall axion_str_at _t9 s  ; Δ{}
  let _t10 = rtcall axion_strcat "/" _t9  ; Δ{_t0 _t2 _t9} · makes String
  let _t11 = * _t10 16777216  ; Δ{}
  let _t11 = + qt gos  ; Δ{ev}
  let _t11 = rtcall axion_strcat _t2 _t10  ; Δ{_t0 _t10 _t2} · makes String
  let _t12 = + _t11 a0  ; Δ{ev}
  let _t12 = rtcall axion_strcat " (" _t11  ; Δ{_t0 _t11} · makes String
  let _t13 = + _t12 aL  ; Δ{ev}
  let _t14 = + _t13 a1  ; Δ{ev}
  let _t15 = + _t14 a2  ; Δ{ev}
  let _t16 = + _t15 a3  ; Δ{ev}
  let _t17 = + _t16 a4  ; Δ{ev}
  let _t18 = + _t17 a5  ; Δ{ev}
  let _t19 = + _t18 a6  ; Δ{ev}
  let _t2 = + _t0 _t1  ; Δ{b}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = == z 0  ; Δ{}
  let _t2 = rtcall axion_str_at _t1 s  ; Δ{}
  let _t2 = rtcall axion_strcat "bye " _t1  ; Δ{_t1} · makes String
  let _t2 = showInt _t1  ; Δ{_t0} · makes String
  let _t20 = + _t19 we  ; Δ{ev}
  let _t21 = call u32 ev 0  ; Δ{ev}
  let _t22 = call u32 ev 20  ; Δ{ev}
  let _t3 = * _t2 256  ; Δ{}
  let _t3 = rtcall axion_poke_u32 b 8 w  ; Δ{b}
  let _t3 = showInt n  ; Δ{_t0 _t2} · makes String
  let _t4 = + _t0 _t3  ; Δ{}
  let _t4 = + _t2 _t3  ; Δ{b}
  let _t4 = == z 0  ; Δ{_t0 _t2 _t3}
  let _t5 = + o 2  ; Δ{}
  let _t5 = rtcall axion_poke_u32 b 12 h  ; Δ{b}
  let _t6 = < t 1  ; Δ{b}
  let _t6 = if _t4 then
  let _t6 = rtcall axion_str_at _t5 s  ; Δ{}
  let _t7 = * _t6 65536  ; Δ{}
  let _t7 = rtcall axion_strcat _t6 " — imv"  ; Δ{_t0 _t2 _t3} · makes String
  let _t8 = + _t4 _t7  ; Δ{}
  let _t8 = rtcall axion_strcat ") " _t7  ; Δ{_t0 _t2 _t3 _t7} · makes String
  let _t9 = + o 3  ; Δ{}
  let _t9 = rtcall axion_strcat _t3 _t8  ; Δ{_t0 _t2 _t3 _t8} · makes String
  let a0 = ffi SDL_SetWindowTitle win _t0  ; Δ{_t0}
  let a1 = ffi SDL_SetRenderDrawColor ren 0 0 0 255  ; Δ{}
  let a2 = ffi SDL_RenderClear ren  ; Δ{}
  let a3 = if _t2 then
  let a4 = ffi SDL_RenderPresent ren  ; Δ{}
  let a5 = ffi SDL_DestroyTexture tex  ; Δ{}
  let a6 = ffi SDL_FreeSurface surf  ; Δ{}
  let aL = if _t1 then
  let b = call fillBuf 16  ; Δ{} · makes String
  let ev = call fillBuf 128  ; Δ{} · makes String
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
  let tok = * _t20 0  ; Δ{ev}
  let tw = call u32 wbuf 0  ; Δ{hbuf path wbuf}
  let ty = + _t21 tok  ; Δ{ev}
  let wbuf = call fillBuf 4  ; Δ{path} · makes String
  let we = ffi SDL_WaitEvent ev  ; Δ{ev}
  ret + _t8 _t11  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{}
  ret call baseAfter s _t1  ; Δ{} · makes String
  ret call dispatch win ren n idx z px py ty _t22  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
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
dispatch win ren n idx z px py ty key  =
fillBuf n  =
lastIndex c s i best  =
le$Int x y  =
loop win ren n idx z px py  =
main  =
mkRect x y w h  =
quitWith q  =
titleFor path idx n z  =
u32 s o  =
zoomIn z  =
zoomOut z  =
