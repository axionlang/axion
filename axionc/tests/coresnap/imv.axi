














                          let _t27 = - n 1  ; Δ{}
                          ret call loop win ren n _t27  ; Δ{}
                          ret call loop win ren n idx  ; Δ{}
                        else
                        let _t26 = == key 1073741901  ; Δ{}
                        ret call loop win ren n 0  ; Δ{}
                        ret if _t26 then
                      else
                      let _t25 = == key 1073741898  ; Δ{}
                      ret call loop win ren n 0  ; Δ{}
                      ret if _t25 then
                    else
                    let _t21 = + idx n  ; Δ{}
                    let _t22 = - _t21 1  ; Δ{}
                    let _t23 = mod _t22 n  ; Δ{}
                    let _t24 = == key 103  ; Δ{}
                    ret call loop win ren n _t23  ; Δ{}
                    ret if _t24 then
                  else
                  let _t17 = + idx n  ; Δ{}
                  let _t18 = - _t17 1  ; Δ{}
                  let _t19 = mod _t18 n  ; Δ{}
                  let _t20 = == key 1073741904  ; Δ{}
                  ret call loop win ren n _t19  ; Δ{}
                  ret if _t20 then
                else
                let _t14 = + idx 1  ; Δ{}
                let _t15 = mod _t14 n  ; Δ{}
                let _t16 = == key 112  ; Δ{}
                ret call loop win ren n _t15  ; Δ{}
                ret if _t16 then
              else
              let _t11 = + idx 1  ; Δ{}
              let _t12 = mod _t11 n  ; Δ{}
              let _t13 = == key 1073741903  ; Δ{}
              ret call loop win ren n _t12  ; Δ{}
              ret if _t13 then
            else
            let _t10 = == key 32  ; Δ{}
            let _t8 = + idx 1  ; Δ{}
            let _t9 = mod _t8 n  ; Δ{}
            ret call loop win ren n _t9  ; Δ{}
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
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret call lastIndex c s _t4 i  ; Δ{}
      ret call lastIndex c s _t5 best  ; Δ{}
      ret call loop win ren n idx  ; Δ{}
      ret if _t3 then
    drop _t1 : String
    drop _t3 : String
    else
    else
    else
    let _d1000000 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + k 1  ; Δ{}
    let _t1 = - 0 1  ; Δ{}
    let _t1 = ffi SDL_Quit 0  ; Δ{}
    let _t1 = rtcall axion_chr 1  ; Δ{} · makes String
    let _t2 = * i 0  ; Δ{}
    let _t2 = - n 1  ; Δ{_t1}
    let _t2 = == ty 768  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t3 = + i 1  ; Δ{}
    let _t3 = + win _t2  ; Δ{}
    let _t3 = - _t2 k  ; Δ{}
    let _t3 = == _t2 c  ; Δ{}
    let _t3 = call fillBuf _t2  ; Δ{_t1} · makes String
    let _t4 = - _t3 1  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let i = ffi SDL_Init 32  ; Δ{}
    let ren = ffi SDL_CreateRenderer win _t1 0  ; Δ{}
    let win = ffi SDL_CreateWindow "imv" 805240832 805240832 1000 700 36  ; Δ{}
    ret ""  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret best  ; Δ{}
    ret call argCount _t3  ; Δ{}
    ret call loop _t3 ren n 0  ; Δ{}
    ret call quitWith _t1  ; Δ{}
    ret ffi SDL_RenderSetLogicalSize ren tw th  ; Δ{}
    ret i  ; Δ{}
    ret if _t2 then
    ret if _t3 then
    ret putStrLn "usage: imv -- <image>..."  ; Δ{}
    ret rtcall axion_strcat s ""  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 s  ; Δ{} · makes String
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
  drop _t2 : String
  drop _t2 : String
  drop _t3 : String
  drop _t4 : String
  drop _t5 : String
  drop _t6 : String
  drop _t7 : String
  drop ev : String
  drop hbuf : String
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
  let _d1000000 = putStrLn _t2  ; Δ{_t2}
  let _d1000000 = rtcall axion_strcat _t0 _t7  ; Δ{_t0 _t7} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = * q 0  ; Δ{}
  let _t0 = - 0 1  ; Δ{}
  let _t0 = < k 0  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = == ty 256  ; Δ{}
  let _t0 = call baseName path  ; Δ{} · makes String
  let _t0 = call titleFor path idx n  ; Δ{path} · makes String
  let _t0 = rtcall axion_getarg i  ; Δ{} · makes String
  let _t0 = rtcall axion_str_at o s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = + idx 1  ; Δ{_t0}
  let _t1 = + o 1  ; Δ{}
  let _t1 = > tw 0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t10 = + _t9 we  ; Δ{ev}
  let _t10 = rtcall axion_str_at _t9 s  ; Δ{}
  let _t11 = * _t10 16777216  ; Δ{}
  let _t11 = call u32 ev 0  ; Δ{ev}
  let _t12 = call u32 ev 20  ; Δ{ev}
  let _t2 = + qt a0  ; Δ{ev}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = rtcall axion_str_at _t1 s  ; Δ{}
  let _t2 = rtcall axion_strcat "bye " _t1  ; Δ{_t1} · makes String
  let _t2 = showInt _t1  ; Δ{_t0} · makes String
  let _t3 = * _t2 256  ; Δ{}
  let _t3 = + _t2 aL  ; Δ{ev}
  let _t3 = showInt n  ; Δ{_t0 _t2} · makes String
  let _t4 = + _t0 _t3  ; Δ{}
  let _t4 = + _t3 a1  ; Δ{ev}
  let _t4 = rtcall axion_strcat _t3 ") — imv"  ; Δ{_t0 _t2 _t3} · makes String
  let _t5 = + _t4 a2  ; Δ{ev}
  let _t5 = + o 2  ; Δ{}
  let _t5 = rtcall axion_strcat "/" _t4  ; Δ{_t0 _t2 _t4} · makes String
  let _t6 = + _t5 a3  ; Δ{ev}
  let _t6 = rtcall axion_str_at _t5 s  ; Δ{}
  let _t6 = rtcall axion_strcat _t2 _t5  ; Δ{_t0 _t2 _t5} · makes String
  let _t7 = * _t6 65536  ; Δ{}
  let _t7 = + _t6 a4  ; Δ{ev}
  let _t7 = rtcall axion_strcat " (" _t6  ; Δ{_t0 _t6} · makes String
  let _t8 = + _t4 _t7  ; Δ{}
  let _t8 = + _t7 a5  ; Δ{ev}
  let _t9 = + _t8 a6  ; Δ{ev}
  let _t9 = + o 3  ; Δ{}
  let a0 = ffi SDL_SetWindowTitle win _t0  ; Δ{_t0}
  let a1 = ffi SDL_SetRenderDrawColor ren 0 0 0 255  ; Δ{}
  let a2 = ffi SDL_RenderClear ren  ; Δ{}
  let a3 = ffi SDL_RenderCopy ren tex 0 0  ; Δ{}
  let a4 = ffi SDL_RenderPresent ren  ; Δ{}
  let a5 = ffi SDL_DestroyTexture tex  ; Δ{}
  let a6 = ffi SDL_FreeSurface surf  ; Δ{}
  let aL = if _t1 then
  let ev = call fillBuf 128  ; Δ{} · makes String
  let hbuf = call fillBuf 4  ; Δ{path wbuf} · makes String
  let n = call argCount 0  ; Δ{}
  let path = rtcall axion_getarg idx  ; Δ{} · makes String
  let qt = ffi SDL_QueryTexture tex 0 0 wbuf hbuf  ; Δ{hbuf path wbuf}
  let surf = ffi IMG_Load path  ; Δ{path}
  let tex = ffi SDL_CreateTextureFromSurface ren surf  ; Δ{path}
  let th = call u32 hbuf 0  ; Δ{hbuf path}
  let tok = * _t10 0  ; Δ{ev}
  let tw = call u32 wbuf 0  ; Δ{hbuf path wbuf}
  let ty = + _t11 tok  ; Δ{ev}
  let wbuf = call fillBuf 4  ; Δ{path} · makes String
  let we = ffi SDL_WaitEvent ev  ; Δ{ev}
  ret + _t8 _t11  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{}
  ret call baseAfter s _t1  ; Δ{} · makes String
  ret call dispatch win ren n idx ty _t12  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t2 then
  ret rtcall axion_array_free _p  ; Δ{}
>=$Int x y  =
argCount i  =
axion_drop_Array _p  =
axion_drop_List _p  =
baseAfter s k  =
baseName s  =
dispatch win ren n idx ty key  =
fillBuf n  =
lastIndex c s i best  =
le$Int x y  =
loop win ren n idx  =
main  =
quitWith q  =
titleFor path idx n  =
u32 s o  =
