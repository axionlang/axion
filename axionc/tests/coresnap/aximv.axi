




































































































                                                let _t33 = + fi 1  ; Δ{}
                                                let _t34 = mod _t33 nf  ; Δ{}
                                                ret call animAct win ren n idx anim nf fp dp fi ty key md  ; Δ{}
                                                ret call animPlay win ren n idx anim nf fp dp _t34  ; Δ{}
                                              drop ev : Buffer
                                              else
                                              let _t32 = == got 0  ; Δ{}
                                              let key = rtcall axion_peek_u32 ev 20  ; Δ{ev}
                                              let md = rtcall axion_peek_u16 ev 24  ; Δ{ev}
                                              let ty = rtcall axion_peek_u32 ev 0  ; Δ{ev}
                                              ret ")"  ; Δ{}
                                              ret if _t32 then
                                              ret rtcall axion_chr key  ; Δ{} · makes String
                                            _ ->
                                            else
                                            let _t23 = == key 48  ; Δ{}
                                            ret "("  ; Δ{}
                                            ret if _t23 then
                                          else
                                          let _t22 = == key 57  ; Δ{}
                                          let _t31 = ffi SDL_DestroyTexture tex [o]  ; Δ{ev}
                                          ret "*"  ; Δ{}
                                          ret case _t31 of
                                          ret if _t22 then
                                        _ ->
                                        drop _t33 : String
                                        drop _t34 : String
                                        drop acc2 : String
                                        drop acc2 : String
                                        else
                                        let _d1000002 = call isProperPrefix _t34 acc2  ; Δ{_t34}
                                        let _rcl2000001 = call frame win ren n idx tex tw th z px py rot acc2  ; Δ{}
                                        let _t21 = == key 56  ; Δ{}
                                        let _t33 = call keymapFile 0  ; Δ{} · makes String
                                        let _t34 = rtcall axion_read_file _t33  ; Δ{_t33} · makes String
                                        ret "&"  ; Δ{}
                                        ret 0  ; Δ{}
                                        ret 100  ; Δ{ev}
                                        ret _d1000002  ; Δ{}
                                        ret _rcl2000001  ; Δ{}
                                        ret call dispatch win ren n idx tex tw th z px py rot fitPct ty key md  ; Δ{}
                                        ret if _t21 then
                                        ret ms  ; Δ{ev}
                                      drop acc2 : String
                                      drop act : String
                                      drop act : String
                                      else
                                      else
                                      else
                                      else
                                      let _d1000001 = call runNamed win ren n idx tex tw th z px py rot curPct act  ; Δ{act}
                                      let _t20 = == key 55  ; Δ{}
                                      let _t27 = rtcall axion_buf_ptr_n ev 128  ; Δ{ev}
                                      let _t28 = call <=$Int ms 0  ; Δ{ev}
                                      let _t29 = if _t28 then
                                      let _t30 = ffi SDL_FlushEvent 768  ; Δ{ev}
                                      let _t31 = rtcall axion_str_len acc2  ; Δ{}
                                      let _t32 = > _t31 0  ; Δ{}
                                      let _t35 = if _t32 then
                                      let ev = rtcall axion_buf_new 128  ; Δ{} · makes Buffer
                                      let got = ffi SDL_WaitEventTimeout _t27 _t29  ; Δ{ev}
                                      ret "^"  ; Δ{}
                                      ret _d1000001  ; Δ{}
                                      ret case _t30 of
                                      ret if _t20 then
                                      ret if _t35 then
                                    _ ->
                                    drop _t25 : String
                                    drop acc2 : String
                                    drop act : String
                                    else
                                    else
                                    let _d1000000 = call runConfigCmd win ren n idx tex act  ; Δ{act}
                                    let _d1000003 = rtcall axion_strcat acc _t25  ; Δ{_t25} · makes String
                                    let _t19 = == key 54  ; Δ{}
                                    let _t25 = call keyToken key md  ; Δ{} · makes String
                                    let _t29 = rtcall axion_str_len act  ; Δ{act}
                                    let _t30 = > _t29 0  ; Δ{act}
                                    ret "%"  ; Δ{}
                                    ret _d1000000  ; Δ{}
                                    ret _d1000003  ; Δ{_d1000003} · moves{_d1000003}
                                    ret if _t19 then
                                    ret if _t30 then
                                    ret rtcall axion_strcat "" ""  ; Δ{} · makes String
                                  drop _t26 : String
                                  drop _t27 : String
                                  drop ev : Buffer
                                  else
                                  else
                                  else
                                  let _t18 = == key 53  ; Δ{}
                                  let _t24 = == ty 768  ; Δ{}
                                  let _t26 = call keymapFile 0  ; Δ{} · makes String
                                  let _t26 = ffi SDL_RenderPresent ren  ; Δ{}
                                  let _t27 = rtcall axion_read_file _t26  ; Δ{_t26} · makes String
                                  let _t28 = call hasPrefix "!" act  ; Δ{act}
                                  let acc2 = if _t24 then
                                  let act = call lookupAction _t27 acc2  ; Δ{_t27} · makes String
                                  let key = rtcall axion_peek_u32 ev 20  ; Δ{ev}
                                  let md = rtcall axion_peek_u16 ev 24  ; Δ{ev}
                                  let ty = rtcall axion_peek_u32 ev 0  ; Δ{ev}
                                  ret "$"  ; Δ{}
                                  ret case _t26 of
                                  ret if _t18 then
                                  ret if _t28 then
                                _ ->
                                _ ->
                                else
                                let _t17 = == key 52  ; Δ{}
                                ret "#"  ; Δ{}
                                ret if _t17 then
                              else
                              let _t16 = == key 51  ; Δ{}
                              let _t23 = ffi SDL_FlushEvent 768  ; Δ{ev}
                              let _t25 = call renderAt ren tex 0 fitPct tw th ow oh 0 0  ; Δ{}
                              let _t47 = call panPx ren 1  ; Δ{}
                              let _t48 = + py _t47  ; Δ{}
                              ret "@"  ; Δ{}
                              ret call frame win ren n idx tex tw th panZ px _t48 rot ""  ; Δ{}
                              ret call frame win ren n idx tex tw th z px py rot ""  ; Δ{}
                              ret case _t23 of
                              ret case _t25 of
                              ret if _t16 then
                            _ ->
                            _ ->
                            else
                            else
                            let _t15 = == key 50  ; Δ{}
                            let _t43 = call panPx ren 1  ; Δ{}
                            let _t44 = - py _t43  ; Δ{}
                            let _t45 = rtcall axion_str_cmp act "pan_down"  ; Δ{}
                            let _t46 = == _t45 0  ; Δ{}
                            ret "!"  ; Δ{}
                            ret call frame win ren n idx tex tw th panZ px _t44 rot ""  ; Δ{}
                            ret if _t15 then
                            ret if _t46 then
                          else
                          else
                          let _t14 = == key 49  ; Δ{}
                          let _t21 = rtcall axion_buf_ptr_n ev 128  ; Δ{ev}
                          let _t22 = ffi SDL_WaitEvent _t21  ; Δ{ev}
                          let _t24 = ffi SDL_RenderClear ren  ; Δ{}
                          let _t39 = call panPx ren 0  ; Δ{}
                          let _t40 = + px _t39  ; Δ{}
                          let _t41 = rtcall axion_str_cmp act "pan_up"  ; Δ{}
                          let _t42 = == _t41 0  ; Δ{}
                          let ev = rtcall axion_buf_new 128  ; Δ{} · makes Buffer
                          ret "~"  ; Δ{}
                          ret call frame win ren n idx tex tw th panZ _t40 py rot ""  ; Δ{}
                          ret case _t22 of
                          ret case _t24 of
                          ret if _t14 then
                          ret if _t42 then
                        _ ->
                        _ ->
                        else
                        else
                        let _t13 = == key 96  ; Δ{}
                        let _t35 = call panPx ren 0  ; Δ{}
                        let _t36 = - px _t35  ; Δ{}
                        let _t37 = rtcall axion_str_cmp act "pan_right"  ; Δ{}
                        let _t38 = == _t37 0  ; Δ{}
                        ret "|"  ; Δ{}
                        ret call frame win ren n idx tex tw th panZ _t36 py rot ""  ; Δ{}
                        ret if _t13 then
                        ret if _t38 then
                      else
                      else
                      let _t12 = == key 92  ; Δ{}
                      let _t16 = * ow 100  ; Δ{}
                      let _t17 = div _t16 tw  ; Δ{}
                      let _t18 = * oh 100  ; Δ{}
                      let _t19 = div _t18 th  ; Δ{}
                      let _t20 = ffi SDL_RenderPresent ren  ; Δ{}
                      let _t23 = ffi SDL_SetRenderDrawColor ren 0 0 0 255  ; Δ{}
                      let _t31 = + rot 270  ; Δ{}
                      let _t32 = mod _t31 360  ; Δ{}
                      let _t33 = rtcall axion_str_cmp act "pan_left"  ; Δ{}
                      let _t34 = == _t33 0  ; Δ{}
                      ret "}"  ; Δ{}
                      ret 100  ; Δ{}
                      ret call frame win ren n idx tex tw th z px py _t32 ""  ; Δ{}
                      ret call imin _t17 _t19  ; Δ{}
                      ret case _t20 of
                      ret case _t23 of
                      ret if _t12 then
                      ret if _t34 then
                    _ ->
                    _ ->
                    else
                    else
                    else
                    let _t11 = == key 93  ; Δ{}
                    let _t15 = > th 0  ; Δ{}
                    let _t27 = + rot 90  ; Δ{}
                    let _t28 = mod _t27 360  ; Δ{}
                    let _t29 = rtcall axion_str_cmp act "rotate_ccw"  ; Δ{}
                    let _t30 = == _t29 0  ; Δ{}
                    ret ""  ; Δ{}
                    ret "{"  ; Δ{}
                    ret 0  ; Δ{}
                    ret 100  ; Δ{}
                    ret < key 127  ; Δ{}
                    ret call frame win ren n idx tex tw th z px py _t28 ""  ; Δ{}
                    ret if _t11 then
                    ret if _t15 then
                    ret if _t30 then
                    ret rtcall axion_chr key  ; Δ{} · makes String
                  drop _t20 : String
                  drop _t21 : String
                  drop _t8 : String
                  drop ohb : Buffer
                  drop owb : Buffer
                  else
                  else
                  else
                  else
                  else
                  let _d1000000 = call startIndex _t8  ; Δ{_t8}
                  let _t10 = == key 91  ; Δ{}
                  let _t14 = > tw 0  ; Δ{}
                  let _t19 = call renderAt ren tex rot curPct tw th ow oh px py  ; Δ{}
                  let _t20 = call imagePath idx  ; Δ{} · makes String
                  let _t21 = call titleFor _t20 idx n 0  ; Δ{_t20} · makes String
                  let _t22 = ffi SDL_SetWindowTitle win _t21  ; Δ{_t21}
                  let _t25 = rtcall axion_str_cmp act "rotate"  ; Δ{}
                  let _t26 = == _t25 0  ; Δ{}
                  let _t8 = > key 32  ; Δ{}
                  let _t8 = rtcall axion_getarg 0  ; Δ{} · makes String
                  let _t9 = if _t8 then
                  let fitPct = if _t14 then
                  let oh = rtcall axion_peek_u32 ohb 0  ; Δ{ohb}
                  let ow = rtcall axion_peek_u32 owb 0  ; Δ{ohb owb}
                  ret "<Space>"  ; Δ{}
                  ret "\""  ; Δ{}
                  ret 0  ; Δ{}
                  ret _d1000000  ; Δ{}
                  ret call frame win ren n idx tex tw th 0 0 0 rot ""  ; Δ{}
                  ret case _t19 of
                  ret case _t22 of
                  ret if _t10 then
                  ret if _t26 then
                  ret if _t9 then
                _ ->
                _ ->
                drop _t1 : String
                else
                else
                else
                else
                let _t22 = call zoomedOut curPct  ; Δ{}
                let _t23 = rtcall axion_str_cmp act "fit"  ; Δ{}
                let _t24 = == _t23 0  ; Δ{}
                let _t6 = - 0 1  ; Δ{}
                let _t7 = == ac 0  ; Δ{}
                let _t7 = == key 32  ; Δ{}
                let _t9 = == key 39  ; Δ{}
                let _t9 = if _t7 then
                let ren = ffi SDL_CreateRenderer win _t6 0  ; Δ{}
                let win = ffi SDL_CreateWindow "aximv" 805240832 805240832 1000 700 36  ; Δ{}
                ret ":"  ; Δ{}
                ret "<Esc>"  ; Δ{}
                ret call frame win ren n idx tex tw th _t22 px py rot ""  ; Δ{}
                ret call openImage win ren n _t9 0 0 0 0  ; Δ{}
                ret if _t24 then
                ret if _t7 then
                ret if _t9 then
              _ ->
              drop hbuf : Buffer
              drop wbuf : Buffer
              else
              else
              else
              let _t11 = rtcall axion_buf_ptr_n owb 4  ; Δ{ohb owb}
              let _t12 = rtcall axion_buf_ptr_n ohb 4  ; Δ{ohb owb}
              let _t13 = ffi SDL_GetRendererOutputSize ren _t11 _t12  ; Δ{ohb owb}
              let _t18 = ffi SDL_RenderClear ren  ; Δ{}
              let _t19 = call zoomedIn curPct  ; Δ{}
              let _t20 = rtcall axion_str_cmp act "zoom_out"  ; Δ{}
              let _t21 = == _t20 0  ; Δ{}
              let _t6 = == key 27  ; Δ{}
              let _t8 = == key 59  ; Δ{}
              let ohb = rtcall axion_buf_new 4  ; Δ{owb} · makes Buffer
              let owb = rtcall axion_buf_new 4  ; Δ{} · makes Buffer
              let th = rtcall axion_peek_u32 hbuf 0  ; Δ{hbuf}
              let tw = rtcall axion_peek_u32 wbuf 0  ; Δ{hbuf wbuf}
              ret "+"  ; Δ{}
              ret "<End>"  ; Δ{}
              ret call frame win ren n idx tex tw th _t19 px py rot ""  ; Δ{}
              ret call staticTry win ren n idx 0 0 0 0 tries  ; Δ{}
              ret case _t13 of
              ret case _t18 of
              ret if _t21 then
              ret if _t6 then
              ret if _t8 then
              ret putStrLn "bye"  ; Δ{}
            _ ->
            _ ->
            _ ->
            _ ->
            drop hbuf : Buffer
            drop wbuf : Buffer
            else
            else
            else
            let _t12 = rtcall axion_peek_u32 wbuf 0  ; Δ{hbuf wbuf}
            let _t13 = rtcall axion_peek_u32 hbuf 0  ; Δ{hbuf}
            let _t15 = - n 1  ; Δ{}
            let _t16 = - n 1  ; Δ{}
            let _t17 = rtcall axion_str_cmp act "zoom_in"  ; Δ{}
            let _t18 = == _t17 0  ; Δ{}
            let _t5 = == key 1073741901  ; Δ{}
            let _t5 = ffi SDL_Init 32  ; Δ{}
            let _t7 = == key 61  ; Δ{}
            ret "<Home>"  ; Δ{}
            ret "_"  ; Δ{}
            ret call animPlay win ren n idx anim nf fp dp fi  ; Δ{}
            ret call animReopen win ren anim n _t15  ; Δ{}
            ret call frame win ren n idx tex _t12 _t13 z px py rot ""  ; Δ{}
            ret call reopen win ren tex n _t16  ; Δ{}
            ret case _t5 of
            ret if _t18 then
            ret if _t5 then
            ret if _t7 then
          _ ->
          _ ->
          drop cact : String
          drop cact : String
          drop db : Buffer
          drop hdr : Buffer
          drop hdr : Buffer
          else
          else
          else
          else
          let _d1000001 = rtcall axion_strcat cact ""  ; Δ{cact} · makes String
          let _t10 = div _t9 ew  ; Δ{}
          let _t10 = ffi IMG_FreeAnimation anim [o]  ; Δ{}
          let _t10 = ffi SDL_QueryTexture tex 0 0 _t8 _t9  ; Δ{hbuf wbuf}
          let _t11 = * oh 100  ; Δ{}
          let _t11 = rtcall axion_peek_u64 hdr 16  ; Δ{hdr}
          let _t12 = div _t11 eh  ; Δ{}
          let _t12 = rtcall axion_peek_u64 hdr 24  ; Δ{hdr}
          let _t13 = rtcall axion_str_cmp act "last"  ; Δ{}
          let _t14 = == _t13 0  ; Δ{}
          let _t14 = rtcall axion_str_cmp act "last"  ; Δ{}
          let _t15 = == _t14 0  ; Δ{}
          let _t17 = ffi SDL_SetRenderDrawColor ren 0 0 0 255  ; Δ{}
          let _t2 = ffi SDL_Quit 0  ; Δ{}
          let _t4 = + idx 1  ; Δ{}
          let _t4 = == key 1073741898  ; Δ{}
          let _t5 = + idx 1  ; Δ{}
          let _t5 = mod _t4 n  ; Δ{}
          let _t6 = - tries 1  ; Δ{}
          let _t6 = == key 45  ; Δ{}
          let _t6 = mod _t5 n  ; Δ{}
          let _t7 = - tries 1  ; Δ{}
          let _t8 = rtcall axion_buf_ptr_n wbuf 4  ; Δ{hbuf wbuf}
          let _t9 = * ow 100  ; Δ{}
          let _t9 = rtcall axion_buf_ptr_n hbuf 4  ; Δ{hbuf wbuf}
          let hbuf = rtcall axion_buf_new 4  ; Δ{wbuf} · makes Buffer
          let ms = rtcall axion_peek_u32 db 0  ; Δ{db}
          let tex = ffi SDL_CreateTextureFromSurface ren surf  ; Δ{}
          let wbuf = rtcall axion_buf_new 4  ; Δ{} · makes Buffer
          ret "<Down>"  ; Δ{}
          ret "?"  ; Δ{}
          ret 100  ; Δ{}
          ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
          ret call animPlay win ren n idx anim nf _t11 _t12 0  ; Δ{}
          ret call animReopen win ren anim n 0  ; Δ{}
          ret call imin _t10 _t12  ; Δ{}
          ret call keyName key md  ; Δ{} · makes String
          ret call openImage win ren n idx 0 0 0 0  ; Δ{}
          ret call openImage win ren n idx 0 0 0 0  ; Δ{}
          ret call openTry win ren n _t5 0 0 0 0 _t6  ; Δ{}
          ret call openTry win ren n _t6 z px py rot _t7  ; Δ{}
          ret call quitWith win ren  ; Δ{}
          ret call quitWith win ren  ; Δ{}
          ret call reopen win ren tex n 0  ; Δ{}
          ret case _t10 of
          ret case _t10 of
          ret case _t17 of
          ret case _t2 of
          ret if _t14 then
          ret if _t15 then
          ret if _t4 then
          ret if _t6 then
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        drop _t1 : String
        drop _t8 : String
        drop cact : String
        else
        else
        else
        else
        else
        else
        else
        else
        else
        let _d1000000 = call animCmd win ren n idx anim cact  ; Δ{cact}
        let _rcl2000000 = call animNamed win ren n idx anim nf fp dp fi _t8  ; Δ{}
        let _t1 = - i 1  ; Δ{}
        let _t10 = - _t9 1  ; Δ{}
        let _t10 = mod _t9 n  ; Δ{}
        let _t10 = rtcall axion_buf_ptr_n hbuf 4  ; Δ{hbuf wbuf}
        let _t11 = ffi SDL_QueryTexture tex 0 0 _t9 _t10  ; Δ{hbuf wbuf}
        let _t11 = mod _t10 n  ; Δ{}
        let _t11 = rtcall axion_str_cmp act "first"  ; Δ{}
        let _t12 = == _t11 0  ; Δ{}
        let _t12 = rtcall axion_str_cmp act "first"  ; Δ{}
        let _t13 = == _t12 0  ; Δ{}
        let _t3 = + i 1  ; Δ{}
        let _t3 = == key 1073741905  ; Δ{}
        let _t3 = > tries 0  ; Δ{}
        let _t4 = > tries 0  ; Δ{}
        let _t4 = call buildKeymap 0  ; Δ{}
        let _t5 = == key 47  ; Δ{}
        let _t6 = rtcall axion_str_len cact  ; Δ{cact}
        let _t7 = > _t6 0  ; Δ{cact}
        let _t8 = + idx n  ; Δ{}
        let _t8 = > eh 0  ; Δ{}
        let _t8 = if _t7 then
        let _t9 = + idx n  ; Δ{}
        let _t9 = - _t8 1  ; Δ{}
        let _t9 = call <=$Int nf 1  ; Δ{hdr}
        let _t9 = rtcall axion_buf_ptr_n wbuf 4  ; Δ{hbuf wbuf}
        let hbuf = rtcall axion_buf_new 4  ; Δ{wbuf} · makes Buffer
        let nf = rtcall axion_peek_u32 hdr 8  ; Δ{hdr}
        let wbuf = rtcall axion_buf_new 4  ; Δ{} · makes Buffer
        ret "<Up>"  ; Δ{}
        ret ">"  ; Δ{}
        ret "rotate"  ; Δ{}
        ret "rotate_ccw"  ; Δ{}
        ret 1  ; Δ{}
        ret 1  ; Δ{}
        ret 100  ; Δ{}
        ret == c 13  ; Δ{}
        ret _d1000000  ; Δ{}
        ret _rcl2000000  ; Δ{}
        ret call animReopen win ren anim n _t10  ; Δ{}
        ret call dup y  ; Δ{} · makes String
        ret call findByBase ys b _t3  ; Δ{}
        ret call ippGo ys acc  ; Δ{}
        ret call kmVal y  ; Δ{} · makes String
        ret call laGo ys k  ; Δ{} · makes String
        ret call nthLine ys _t1  ; Δ{} · makes String
        ret call reopen win ren tex n _t11  ; Δ{}
        ret case _t11 of
        ret case _t4 of
        ret fitPct  ; Δ{}
        ret i  ; Δ{}
        ret if _t12 then
        ret if _t13 then
        ret if _t3 then
        ret if _t3 then
        ret if _t4 then
        ret if _t5 then
        ret if _t8 then
        ret if _t9 then
        ret rtcall axion_eputs "aximv: no images in this folder"  ; Δ{}
        ret th  ; Δ{}
        ret th  ; Δ{}
        ret tw  ; Δ{}
        ret tw  ; Δ{}
        ret z  ; Δ{}
      _ ->
      _ ->
      _ ->
      _ ->
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t14 : String
      drop _t15 : String
      drop _t2 : String
      drop _t3 : String
      drop _t4 : String
      drop _t4 : String
      drop _t4 : String
      drop _t5 : String
      drop _t5 : String
      drop _t7 : String
      drop _t7 : String
      drop base : String
      drop base : String
      drop fb : Buffer
      drop m
      drop m
      drop ohb : Buffer
      drop owb : Buffer
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
      else
      let _d1000000 = rtcall axion_strcat "'\\''" _t4  ; Δ{_t4} · makes String
      let _d1000000 = rtcall axion_strcat rep _t4  ; Δ{_t4} · makes String
      let _d1000001 = rtcall axion_strcat _t5 _t7  ; Δ{_t5 _t7} · makes String
      let _d1000001 = rtcall axion_strcat _t5 _t7  ; Δ{_t5 _t7} · makes String
      let _d1000001 = rtcall axion_strcat base ""  ; Δ{base} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = == i 0  ; Δ{}
      let _t0 = call baseName y  ; Δ{} · makes String
      let _t0 = call kmKey y  ; Δ{} · makes String
      let _t0 = call kmKey y  ; Δ{} · makes String
      let _t0 = call length ys  ; Δ{}
      let _t0 = call shiftHeld md  ; Δ{}
      let _t1 = call seqStarts _t0 acc  ; Δ{_t0}
      let _t1 = ffi SDL_DestroyWindow win [o]  ; Δ{}
      let _t1 = rtcall axion_str_cmp _t0 b  ; Δ{_t0}
      let _t1 = rtcall axion_str_cmp _t0 k  ; Δ{_t0}
      let _t13 = == z 0  ; Δ{}
      let _t14 = call imagePath idx  ; Δ{} · makes String
      let _t15 = call titleFor _t14 idx n z  ; Δ{_t14} · makes String
      let _t16 = ffi SDL_SetWindowTitle win _t15  ; Δ{_t15}
      let _t2 = == _t1 0  ; Δ{}
      let _t2 = == _t1 0  ; Δ{}
      let _t2 = == c 10  ; Δ{}
      let _t2 = == key 1073741906  ; Δ{}
      let _t2 = call keymapFile 0  ; Δ{} · makes String
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 2  ; Δ{}
      let _t3 = == n 0  ; Δ{}
      let _t3 = mod rot 180  ; Δ{}
      let _t3 = rtcall axion_read_file _t2  ; Δ{_t2} · makes String
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + idx 1  ; Δ{}
      let _t4 = - j 1  ; Δ{}
      let _t4 = == _t3 90  ; Δ{}
      let _t4 = == key 46  ; Δ{}
      let _t4 = call keyToken key md  ; Δ{_t3} · makes String
      let _t4 = call shEsc s _t3 n  ; Δ{} · makes String
      let _t4 = call spGo cmd rep _t3  ; Δ{} · makes String
      let _t4 = rtcall axion_buf_ptr_n db 4  ; Δ{db}
      let _t5 = * acc 10  ; Δ{}
      let _t5 = * fi 4  ; Δ{db}
      let _t5 = + i 1  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t5 = + idx 1  ; Δ{}
      let _t5 = call hasPrefix "!" cact  ; Δ{cact}
      let _t5 = mod _t4 n  ; Δ{}
      let _t5 = mod rot 180  ; Δ{}
      let _t5 = rtcall axion_substr i 1 cmd  ; Δ{} · makes String
      let _t5 = rtcall axion_substr i 1 s  ; Δ{} · makes String
      let _t6 = + dp _t5  ; Δ{db}
      let _t6 = + i 1  ; Δ{_t5}
      let _t6 = + i 1  ; Δ{_t5}
      let _t6 = == _t5 90  ; Δ{}
      let _t6 = ffi IMG_FreeAnimation anim [o]  ; Δ{}
      let _t6 = ffi SDL_DestroyTexture tex [o]  ; Δ{}
      let _t6 = mod _t5 n  ; Δ{}
      let _t6 = rtcall axion_str_at _t5 cmd  ; Δ{}
      let _t6 = rtcall axion_str_at i s  ; Δ{}
      let _t6 = rtcall axion_str_cmp act "prev"  ; Δ{}
      let _t7 = - _t6 48  ; Δ{}
      let _t7 = == _t6 0  ; Δ{}
      let _t7 = > ew 0  ; Δ{}
      let _t7 = call shEsc s _t6 n  ; Δ{_t5} · makes String
      let _t7 = call spGo cmd rep _t6  ; Δ{_t5} · makes String
      let _t7 = ffi memcpy _t4 _t6 4  ; Δ{db}
      let _t7 = rtcall axion_str_cmp act "prev"  ; Δ{}
      let _t8 = + _t5 _t7  ; Δ{}
      let _t8 = == _t7 0  ; Δ{}
      let cact = call lookupAction _t3 _t4  ; Δ{_t3 _t4} · makes String
      let curPct = if _t13 then
      let db = rtcall axion_buf_new 4  ; Δ{} · makes Buffer
      let eh = if _t6 then
      let ew = if _t4 then
      let fitPct = if _t7 then
      let n = call imageCount 0  ; Δ{}
      let oh = rtcall axion_peek_u32 ohb 0  ; Δ{ohb}
      let ow = rtcall axion_peek_u32 owb 0  ; Δ{ohb owb}
      let surf = rtcall axion_peek_u64 fb 0  ; Δ{fb}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret "<"  ; Δ{}
      ret "<Left>"  ; Δ{}
      ret "C-"  ; Δ{}
      ret "M-"  ; Δ{}
      ret "first"  ; Δ{}
      ret "first"  ; Δ{}
      ret "fit"  ; Δ{}
      ret "last"  ; Δ{}
      ret "next"  ; Δ{}
      ret "next"  ; Δ{}
      ret "next"  ; Δ{}
      ret "pan_down"  ; Δ{}
      ret "pan_left"  ; Δ{}
      ret "pan_right"  ; Δ{}
      ret "pan_up"  ; Δ{}
      ret "prev"  ; Δ{}
      ret "prev"  ; Δ{}
      ret "quit"  ; Δ{}
      ret "quit"  ; Δ{}
      ret "redraw"  ; Δ{}
      ret "zoom_in"  ; Δ{}
      ret "zoom_in"  ; Δ{}
      ret "zoom_out"  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret + c 32  ; Δ{}
      ret 0  ; Δ{base}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret == _t6 115  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret _t9  ; Δ{}
      ret c  ; Δ{}
      ret call animPlay win ren n idx anim nf fp dp fi  ; Δ{}
      ret call animReopen win ren anim n _t5  ; Δ{}
      ret call findChar c s _t3 n  ; Δ{}
      ret call frame win ren n idx tex tw th z px py rot ""  ; Δ{}
      ret call lastIndex c s _t4 i  ; Δ{}
      ret call lastIndex c s _t5 best  ; Δ{}
      ret call onKey win ren n idx tex tw th z px py rot curPct key md  ; Δ{}
      ret call openImage win ren n idx 0 0 0 0  ; Δ{}
      ret call openImage win ren n idx 0 0 0 0  ; Δ{}
      ret call quitTex win ren tex  ; Δ{}
      ret call quitWith win ren  ; Δ{}
      ret call quitWith win ren  ; Δ{}
      ret call readIntGo s _t4 _t8  ; Δ{} · makes Maybe$Int
      ret call reopen win ren tex n _t6  ; Δ{}
      ret call shiftGlyph key  ; Δ{} · makes String
      ret call shiftHeld md  ; Δ{base}
      ret call tabScan s _t4  ; Δ{}
      ret call trimEnd s _t4  ; Δ{}
      ret call trimStart s _t4  ; Δ{}
      ret callclo f x  ; Δ{x} · moves{x}
      ret case _t1 of
      ret case _t16 of
      ret case _t6 of
      ret case _t6 of
      ret case _t7 of
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret d  ; Δ{}
      ret i  ; Δ{}
      ret i  ; Δ{}
      ret i  ; Δ{}
      ret if _t0 then
      ret if _t0 then
      ret if _t1 then
      ret if _t2 then
      ret if _t2 then
      ret if _t2 then
      ret if _t2 then
      ret if _t3 then
      ret if _t4 then
      ret if _t5 then
      ret if _t7 then
      ret if _t8 then
      ret j  ; Δ{}
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
    114 ->
    256 ->
    27 ->
    32 ->
    43 ->
    45 ->
    48 ->
    61 ->
    768 ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Just x ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nothing ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    drop _t2 : List$String
    drop _t2 : String
    drop _t3 : String
    drop _t3 : String
    drop _t4 : String
    drop _t5 : String
    drop _t5 : String
    drop _t7 : String
    drop _t9 : String
    drop base : String
    drop glyph : String
    drop v : String
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
    else
    else
    else
    else
    else
    else
    else
    let _d1000000 = call findByBase _t2 _t3 0  ; Δ{_t2 _t3}
    let _d1000000 = rtcall axion_strcat _t3 _t5  ; Δ{_t3 _t5} · makes String
    let _d1000000 = rtcall axion_strcat _t6 _t9  ; Δ{_t9} · makes String
    let _d1000001 = rtcall axion_strcat _t5 "%"  ; Δ{_t0 _t2 _t3 _t5} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + i 1  ; Δ{}
    let _t1 = + k 1  ; Δ{}
    let _t1 = - j 1  ; Δ{}
    let _t1 = == c 9  ; Δ{}
    let _t1 = == key 1073741904  ; Δ{}
    let _t1 = == ty 768  ; Δ{}
    let _t1 = call <=$Int c 90  ; Δ{}
    let _t1 = call findChar 10 s i n  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = - key 32  ; Δ{}
    let _t2 = == _t1 39  ; Δ{}
    let _t2 = == _t1 c  ; Δ{}
    let _t2 = call imagePath idx  ; Δ{} · makes String
    let _t2 = call imgLines 0  ; Δ{} · makes List$String
    let _t2 = call isPctS cmd i  ; Δ{}
    let _t2 = call lowerChar _t1  ; Δ{}
    let _t2 = ffi IMG_FreeAnimation anim [o]  ; Δ{}
    let _t2 = rtcall axion_str_at _t1 s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_cmp act "next"  ; Δ{}
    let _t2 = rtcall axion_str_len base  ; Δ{base}
    let _t2 = rtcall axion_str_len line  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t3 = + i 1  ; Δ{}
    let _t3 = - _t2 i  ; Δ{}
    let _t3 = - _t2 k  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = == _t2 1  ; Δ{base}
    let _t3 = == _t2 9  ; Δ{}
    let _t3 = == _t2 c  ; Δ{}
    let _t3 = == key 44  ; Δ{}
    let _t3 = call baseName seed  ; Δ{_t2} · makes String
    let _t3 = call isDigit _t2  ; Δ{}
    let _t3 = call isSpace _t2  ; Δ{}
    let _t3 = call isSpace _t2  ; Δ{}
    let _t3 = ffi IMG_LoadAnimation _t2  ; Δ{_t2}
    let _t3 = ffi SDL_FreeSurface surf [o]  ; Δ{}
    let _t3 = rtcall axion_chr _t2  ; Δ{} · makes String
    let _t3 = rtcall axion_str_at i cmd  ; Δ{}
    let _t3 = rtcall axion_str_cmp act "next"  ; Δ{}
    let _t3 = rtcall axion_str_len p  ; Δ{}
    let _t3 = rtcall axion_str_len s  ; Δ{}
    let _t4 = + i 1  ; Δ{_t3}
    let _t4 = - _t3 1  ; Δ{}
    let _t4 = - _t3 1  ; Δ{}
    let _t4 = == _t3 0  ; Δ{}
    let _t4 = == _t3 37  ; Δ{}
    let _t4 = if _t3 then
    let _t4 = rtcall axion_str_len q  ; Δ{}
    let _t4 = rtcall axion_substr 0 _t3 s  ; Δ{} · makes String
    let _t5 = - _t3 _t4  ; Δ{}
    let _t5 = call ctrlHeld md  ; Δ{}
    let _t5 = call toLowerGo s _t4 n  ; Δ{_t3} · makes String
    let _t5 = rtcall axion_str_cmp _t4 p  ; Δ{_t4}
    let _t5 = showInt z  ; Δ{_t0 _t2 _t3} · makes String
    let _t6 = if _t5 then
    let _t6 = rtcall axion_str_len q  ; Δ{}
    let _t7 = call altHeld md  ; Δ{}
    let _t7 = rtcall axion_buf_ptr_n hdr 32  ; Δ{hdr}
    let _t7 = rtcall axion_substr _t5 _t6 s  ; Δ{} · makes String
    let _t8 = ffi SDL_FreeSurface surf [o]  ; Δ{}
    let _t8 = ffi memcpy _t7 anim 32  ; Δ{hdr}
    let _t8 = if _t7 then
    let _t8 = rtcall axion_str_cmp _t7 q  ; Δ{_t7}
    let _t9 = rtcall axion_strcat _t8 glyph  ; Δ{} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let glyph = if _t4 then
    let hdr = rtcall axion_buf_new 32  ; Δ{} · makes Buffer
    let tex = ffi SDL_CreateTextureFromSurface ren surf  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret "<Right>"  ; Δ{}
    ret - 0 1  ; Δ{}
    ret 0  ; Δ{b}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 4  ; Δ{b}
    ret == _t5 0  ; Δ{}
    ret == _t8 0  ; Δ{}
    ret == x y  ; Δ{}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret _d1000000  ; Δ{}
    ret _d1000001  ; Δ{_d1000001 _t0 _t2 _t3} · moves{_d1000001}
    ret a  ; Δ{}
    ret a  ; Δ{}
    ret axsb  ; Δ{axsb} · moves{axsb}
    ret axsb  ; Δ{axsb} · moves{axsb}
    ret b  ; Δ{}
    ret b  ; Δ{}
    ret best  ; Δ{}
    ret c  ; Δ{}
    ret call <=$Int c 57  ; Δ{}
    ret call <=$Int key 122  ; Δ{}
    ret call animQuit win ren anim  ; Δ{}
    ret call animQuit win ren anim  ; Δ{}
    ret call animStart win ren n idx _t3 tries  ; Δ{}
    ret call argCount _t3  ; Δ{}
    ret call consLine s i n _t1  ; Δ{} · makes List$String
    ret call dup dflt  ; Δ{} · makes String
    ret call dup line  ; Δ{} · makes String
    ret call hasPrefix acc b  ; Δ{}
    ret call hasSuffix ".webp" q  ; Δ{}
    ret call quitTex win ren tex  ; Δ{}
    ret call readIntGo s 0 0  ; Δ{} · makes Maybe$Int
    ret call staticTry win ren n idx z px py rot tries  ; Δ{}
    ret case _t2 of
    ret case _t3 of
    ret case _t8 of
    ret case _t8 of
    ret con Just acc  ; Δ{} · makes Maybe$Int
    ret con Nil  ; Δ{} · makes List$String
    ret con Nothing  ; Δ{} · makes Maybe$Int
    ret curPct  ; Δ{}
    ret fitPct  ; Δ{}
    ret i  ; Δ{}
    ret i  ; Δ{}
    ret if _t1 then
    ret if _t1 then
    ret if _t1 then
    ret if _t1 then
    ret if _t2 then
    ret if _t2 then
    ret if _t2 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t4 then
    ret if _t4 then
    ret j  ; Δ{}
    ret n  ; Δ{}
    ret rtcall axion_chr _t2  ; Δ{} · makes String
    ret rtcall axion_getarg 0  ; Δ{} · makes String
    ret rtcall axion_strcat "." ""  ; Δ{} · makes String
    ret rtcall axion_strcat "fit" ""  ; Δ{_t0 _t2 _t3} · makes String
    ret rtcall axion_strcat s ""  ; Δ{} · makes String
    ret rtcall axion_substr 0 i line  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 line  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 s  ; Δ{} · makes String
    ret v  ; Δ{v} · moves{v}
    ret z  ; Δ{}
    ret z  ; Δ{}
  ; Δ{_t0 _t2 _t3}
  ; Δ{act}
  ; Δ{act}
  ; Δ{axsb}
  ; Δ{base}
  ; Δ{base}
  ; Δ{base}
  ; Δ{b}
  ; Δ{cact}
  ; Δ{cact}
  ; Δ{db}
  ; Δ{ev}
  ; Δ{ev}
  ; Δ{ev}
  ; Δ{ev}
  ; Δ{ev}
  ; Δ{fb}
  ; Δ{hbuf wbuf}
  ; Δ{hbuf wbuf}
  ; Δ{hdr}
  ; Δ{hdr}
  ; Δ{ohb owb}
  ; Δ{ohb owb}
  ; Δ{v}
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
  drop _t0
  drop _t0 : List$String
  drop _t0 : List$String
  drop _t0 : List$String
  drop _t0 : List$String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t10 : String
  drop _t10 : String
  drop _t10 : String
  drop _t11 : String
  drop _t11 : String
  drop _t11 : String
  drop _t12 : String
  drop _t12 : String
  drop _t13 : String
  drop _t14 : String
  drop _t15 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t3 : String
  drop _t3 : String
  drop _t3 : String
  drop _t3 : String
  drop _t3 : String
  drop _t3 : String
  drop _t3 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t5 : String
  drop _t5 : String
  drop _t6 : String
  drop _t6 : String
  drop _t6 : String
  drop _t7 : String
  drop _t7 : String
  drop _t7 : String
  drop _t8 : String
  drop _t8 : String
  drop _t8 : String
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop b : Buffer
  drop v : String
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
  else
  else
  let _d1000000 = call ippGo _t0 acc  ; Δ{_t0}
  let _d1000000 = call isAnimLc _t0  ; Δ{_t0}
  let _d1000000 = call laGo _t0 k  ; Δ{_t0} · makes String
  let _d1000000 = call length _t0  ; Δ{_t0}
  let _d1000000 = call lines _t1  ; Δ{_t1} · makes List$String
  let _d1000000 = call maybe d _t0 m  ; Δ{_t0}
  let _d1000000 = call nthLine _t0 idx  ; Δ{_t0} · makes String
  let _d1000000 = call runNamed win ren n idx tex tw th z px py rot curPct _t0  ; Δ{_t0}
  let _d1000000 = rtcall axion_strcat "'" _t2  ; Δ{_t2} · makes String
  let _d1000000 = rtcall axion_strcat "f=" _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/aximv/filelist"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/aximv/keymap"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.config/aximv/config.lua"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t12  ; Δ{_t0 _t12} · makes String
  let _d1000000 = rtcall axion_system _t11  ; Δ{_t11}
  let _d1000000 = rtcall axion_system _t15  ; Δ{_t15}
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = * pct 100  ; Δ{}
  let _t0 = * tw pct  ; Δ{}
  let _t0 = + i 1  ; Δ{}
  let _t0 = + pct 1  ; Δ{}
  let _t0 = - 0 1  ; Δ{}
  let _t0 = - j i  ; Δ{}
  let _t0 = < a b  ; Δ{}
  let _t0 = < i 0  ; Δ{}
  let _t0 = < i 0  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < k 0  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == ac 0  ; Δ{}
  let _t0 = == c 32  ; Δ{}
  let _t0 = == key 1073741903  ; Δ{}
  let _t0 = == ty 256  ; Δ{}
  let _t0 = == z 0  ; Δ{}
  let _t0 = == z 0  ; Δ{}
  let _t0 = > a b  ; Δ{}
  let _t0 = > j 0  ; Δ{}
  let _t0 = call >=$Int c 48  ; Δ{}
  let _t0 = call >=$Int c 65  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int key 97  ; Δ{}
  let _t0 = call baseName path  ; Δ{} · makes String
  let _t0 = call configFile 0  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call hasSuffix ".gif" q  ; Δ{}
  let _t0 = call imagePath idx  ; Δ{} · makes String
  let _t0 = call imagePath idx  ; Δ{} · makes String
  let _t0 = call imagePath idx  ; Δ{} · makes String
  let _t0 = call imagePath idx  ; Δ{} · makes String
  let _t0 = call imgLines 0  ; Δ{} · makes List$String
  let _t0 = call imgLines 0  ; Δ{} · makes List$String
  let _t0 = call imgListFile 0  ; Δ{} · makes String
  let _t0 = call imgListFile 0  ; Δ{} · makes String
  let _t0 = call imin hi x  ; Δ{}
  let _t0 = call keyName key md  ; Δ{} · makes String
  let _t0 = call keymapFile 0  ; Δ{} · makes String
  let _t0 = call lines km  ; Δ{} · makes List$String
  let _t0 = call lines km  ; Δ{} · makes List$String
  let _t0 = call shQuote path  ; Δ{} · makes String
  let _t0 = call toLower p  ; Δ{} · makes String
  let _t0 = call trimStart s 0  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes Closure
  let _t0 = div md 256  ; Δ{}
  let _t0 = div md 64  ; Δ{}
  let _t0 = ffi IMG_FreeAnimation anim [o]  ; Δ{}
  let _t0 = ffi IMG_FreeAnimation anim [o]  ; Δ{}
  let _t0 = ffi SDL_DestroyRenderer ren [o]  ; Δ{}
  let _t0 = ffi SDL_DestroyTexture tex [o]  ; Δ{}
  let _t0 = ffi SDL_DestroyTexture tex [o]  ; Δ{}
  let _t0 = mod md 4  ; Δ{}
  let _t0 = rtcall axion_buf_ptr_n b 8  ; Δ{b}
  let _t0 = rtcall axion_buf_ptr_n fb 8  ; Δ{fb}
  let _t0 = rtcall axion_buf_ptr_n owb 4  ; Δ{ohb owb}
  let _t0 = rtcall axion_getarg i  ; Δ{} · makes String
  let _t0 = rtcall axion_poke_u32 axsb 0 x  ; Δ{axsb}
  let _t0 = rtcall axion_str_cmp act "quit"  ; Δ{}
  let _t0 = rtcall axion_str_cmp seed "."  ; Δ{}
  let _t0 = rtcall axion_str_len b  ; Δ{}
  let _t0 = rtcall axion_str_len base  ; Δ{base}
  let _t0 = rtcall axion_str_len cmd  ; Δ{}
  let _t0 = rtcall axion_str_len p  ; Δ{}
  let _t0 = rtcall axion_str_len q  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len v  ; Δ{v}
  let _t1 = * fi 8  ; Δ{fb}
  let _t1 = * th pct  ; Δ{}
  let _t1 = + idx 1  ; Δ{_t0}
  let _t1 = < i _t0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{base}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == anim 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{v}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call isAnim _t0  ; Δ{_t0}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = call optionInt "zoom_step" 5 1 100  ; Δ{}
  let _t1 = call optionInt "zoom_step" 5 1 100  ; Δ{}
  let _t1 = call shEsc s 0 _t0  ; Δ{} · makes String
  let _t1 = call shQuote _t0  ; Δ{_t0} · makes String
  let _t1 = call shQuote _t0  ; Δ{_t0} · makes String
  let _t1 = call substPct cmd "\"$f\""  ; Δ{_t0} · makes String
  let _t1 = if _t0 then
  let _t1 = if _t0 then
  let _t1 = mod _t0 4  ; Δ{}
  let _t1 = mod _t0 4  ; Δ{}
  let _t1 = rtcall axion_buf_ptr_n b 8  ; Δ{b}
  let _t1 = rtcall axion_buf_ptr_n ohb 4  ; Δ{ohb owb}
  let _t1 = rtcall axion_poke_u32 axsb 4 y  ; Δ{axsb}
  let _t1 = rtcall axion_read_file _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_read_file _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_str_cmp act "quit"  ; Δ{}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len acc  ; Δ{}
  let _t1 = rtcall axion_str_len act  ; Δ{_t0}
  let _t1 = rtcall axion_str_len act  ; Δ{_t0}
  let _t1 = rtcall axion_str_len cmd  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t1 = surf  ; Δ{}
  let _t10 = rtcall axion_buf_free dst  ; Δ{dst} · moves{dst}
  let _t10 = rtcall axion_strcat "/" _t9  ; Δ{_t0 _t2 _t9} · makes String
  let _t10 = rtcall axion_strcat "sed '/^[[:space:]]*--/d' \"$cfg\" | while IFS= read -r line; do case \"$line\" in " _t9  ; Δ{_t1 _t3 _t9} · makes String
  let _t10 = rtcall axion_strcat _t1 _t9  ; Δ{_t1 _t9} · makes String
  let _t11 = rtcall axion_strcat "; mkdir -p \"${km%/*}\"; : > \"$km\"; [ -r \"$cfg\" ] || exit 0; " _t10  ; Δ{_t1 _t10 _t3} · makes String
  let _t11 = rtcall axion_strcat "lf=" _t10  ; Δ{_t10} · makes String
  let _t11 = rtcall axion_strcat _t2 _t10  ; Δ{_t0 _t10 _t2} · makes String
  let _t12 = rtcall axion_strcat " (" _t11  ; Δ{_t0 _t11} · makes String
  let _t12 = rtcall axion_strcat _t3 _t11  ; Δ{_t1 _t11 _t3} · makes String
  let _t13 = rtcall axion_strcat "; km=" _t12  ; Δ{_t1 _t12} · makes String
  let _t14 = rtcall axion_strcat _t1 _t13  ; Δ{_t1 _t13} · makes String
  let _t15 = rtcall axion_strcat "cfg=" _t14  ; Δ{_t14} · makes String
  let _t2 = + 100 _t1  ; Δ{}
  let _t2 = + 100 _t1  ; Δ{}
  let _t2 = + _t0 _t1  ; Δ{axsb}
  let _t2 = + _t1 4  ; Δ{b}
  let _t2 = + fp _t1  ; Δ{fb}
  let _t2 = + j 1  ; Δ{_t1}
  let _t2 = - _t1 1  ; Δ{_t0}
  let _t2 = - _t1 1  ; Δ{_t0}
  let _t2 = - ow dw  ; Δ{}
  let _t2 = < _t0 _t1  ; Δ{}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = call buildImgList _t1  ; Δ{}
  let _t2 = call keymapFile 0  ; Δ{_t1} · makes String
  let _t2 = call shQuote seed  ; Δ{_t1} · makes String
  let _t2 = call trimEnd s _t1  ; Δ{}
  let _t2 = ffi SDL_GetRendererOutputSize ren _t0 _t1  ; Δ{ohb owb}
  let _t2 = rtcall axion_strcat "\u{1}" name  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t1 " ; } >/dev/null 2>&1"  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat _t1 "'"  ; Δ{_t1} · makes String
  let _t2 = showInt _t1  ; Δ{_t0} · makes String
  let _t3 = * pct _t2  ; Δ{}
  let _t3 = == axis 0  ; Δ{b}
  let _t3 = call linesFrom s _t2 n  ; Δ{_t1} · makes List$String
  let _t3 = call shQuote _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = call trim v  ; Δ{v} · makes String
  let _t3 = call trimStart s 0  ; Δ{}
  let _t3 = div _t0 _t2  ; Δ{}
  let _t3 = div _t2 2  ; Δ{}
  let _t3 = ffi memcpy _t0 _t2 8  ; Δ{fb}
  let _t3 = rtcall axion_poke_u32 axsb 8 w  ; Δ{axsb}
  let _t3 = rtcall axion_strcat "-o -iname '*.avif' -o -iname '*.jxl' -o -iname '*.ppm' -o -iname '*.pgm' \\) " "| LC_ALL=C sort > \"$lf\""  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_strcat "; { " _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_substr 1 _t2 act  ; Δ{_t0} · makes String
  let _t3 = rtcall axion_substr 1 _t2 act  ; Δ{_t0} · makes String
  let _t3 = showInt n  ; Δ{_t0 _t2} · makes String
  let _t4 = + _t2 _t3  ; Δ{axsb}
  let _t4 = + _t3 px  ; Δ{}
  let _t4 = - _t2 _t3  ; Δ{}
  let _t4 = == z 0  ; Δ{_t0 _t2 _t3}
  let _t4 = call readInt _t3  ; Δ{_t3} · makes Maybe$Int
  let _t4 = call userCmd _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _t4 = call userCmd _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _t4 = div _t3 100  ; Δ{}
  let _t4 = if _t3 then
  let _t4 = rtcall axion_strcat "-o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' -o -iname '*.tif' -o -iname '*.tiff' " _t3  ; Δ{_t1 _t2 _t3} · makes String
  let _t4 = rtcall axion_strcat "v=$(printf '%s\\n' \"$line\" | sed -n 's/.*value[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); " "[ -n \"$o\" ] && printf '\\001%s\\t%s\\n' \"$o\" \"$v\" >> \"$km\" ;; esac; done; true"  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _t5 = - oh dh  ; Δ{}
  let _t5 = call fromMaybe dflt _t4  ; Δ{_t4} · moves{_t4}
  let _t5 = call imax _t0 _t4  ; Δ{}
  let _t5 = call optionInt "pan_step" 1 1 50  ; Δ{}
  let _t5 = rtcall axion_poke_u32 axsb 12 h  ; Δ{axsb}
  let _t5 = rtcall axion_strcat "*option*value*) o=$(printf '%s\\n' \"$line\" | sed -n 's/.*option[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); " _t4  ; Δ{_t1 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat "find \"$d\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' " _t4  ; Δ{_t1 _t2 _t4} · makes String
  let _t5 = rtcall axion_system _t4  ; Δ{_t4}
  let _t5 = rtcall axion_system _t4  ; Δ{_t4}
  let _t6 = * side _t5  ; Δ{}
  let _t6 = < axst 1  ; Δ{axsb}
  let _t6 = div _t5 2  ; Δ{}
  let _t6 = if _t4 then
  let _t6 = rtcall axion_strcat "[ -n \"$a\" ] || continue; printf '%s\\t%s\\n' \"$k\" \"$a\" >> \"$km\" ;; " _t5  ; Δ{_t1 _t3 _t5} · makes String
  let _t6 = rtcall axion_strcat "if [ -d \"$s\" ]; then d=\"$s\"; else d=$(dirname \"$s\"); fi; " _t5  ; Δ{_t1 _t2 _t5} · makes String
  let _t7 = + _t6 py  ; Δ{}
  let _t7 = div _t6 100  ; Δ{}
  let _t7 = rtcall axion_strcat "; " _t6  ; Δ{_t1 _t2 _t6} · makes String
  let _t7 = rtcall axion_strcat "a=$(printf '%s\\n' \"$line\" | sed -n 's/.*action[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); " _t6  ; Δ{_t1 _t3 _t6} · makes String
  let _t7 = rtcall axion_strcat _t6 " — aximv"  ; Δ{_t0 _t2 _t3} · makes String
  let _t8 = * got 0  ; Δ{}
  let _t8 = rtcall axion_strcat ") " _t7  ; Δ{_t0 _t2 _t3 _t7} · makes String
  let _t8 = rtcall axion_strcat "[ -n \"$k\" ] || continue; " _t7  ; Δ{_t1 _t3 _t7} · makes String
  let _t8 = rtcall axion_strcat _t2 _t7  ; Δ{_t1 _t2 _t7} · makes String
  let _t8 = toFloat rot  ; Δ{dst}
  let _t9 = + _t7 _t8  ; Δ{}
  let _t9 = ffi SDL_RenderCopyEx ren tex 0 p _t8 0 0 [-,-,-,-,f,-,-]  ; Δ{dst}
  let _t9 = rtcall axion_strcat "*key*action*) k=$(printf '%s\\n' \"$line\" | sed -n 's/.*key[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); " _t8  ; Δ{_t1 _t3 _t8} · makes String
  let _t9 = rtcall axion_strcat "; mkdir -p \"${lf%/*}\"; s=" _t8  ; Δ{_t1 _t8} · makes String
  let _t9 = rtcall axion_strcat _t3 _t8  ; Δ{_t0 _t2 _t3 _t8} · makes String
  let ac = call argCount 0  ; Δ{}
  let axsb = rtcall axion_buf_new 16  ; Δ{} · makes Buffer
  let axst = + _t4 _t5  ; Δ{axsb}
  let b = rtcall axion_buf_new 8  ; Δ{} · makes Buffer
  let base = call keyBase key  ; Δ{} · makes String
  let curPct = if _t0 then
  let dh = div _t1 100  ; Δ{}
  let dst = call mk__SDL_Rect _t4 _t7 dw dh  ; Δ{} · makes Buffer
  let dw = div _t0 100  ; Δ{}
  let fb = rtcall axion_buf_new 8  ; Δ{} · makes Buffer
  let got = ffi SDL_GetRendererOutputSize ren _t0 _t2  ; Δ{b}
  let i = call tabIdx line  ; Δ{}
  let i = call tabIdx line  ; Δ{}
  let ohb = rtcall axion_buf_new 4  ; Δ{owb} · makes Buffer
  let owb = rtcall axion_buf_new 4  ; Δ{} · makes Buffer
  let p = rtcall axion_buf_ptr dst  ; Δ{dst}
  let panZ = if _t0 then
  let side = rtcall axion_peek_u32 b _t4  ; Δ{b}
  let surf = ffi IMG_Load _t0  ; Δ{_t0}
  let v = call lookupAction _t1 _t2  ; Δ{_t1 _t2} · makes String
  let v = rtcall axion_getenv name  ; Δ{} · makes String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret > _t0 0  ; Δ{}
  ret > _t1 0  ; Δ{}
  ret > _t1 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call baseAfter s _t1  ; Δ{} · makes String
  ret call clamp lo hi _t5  ; Δ{}
  ret call imax 1 _t9  ; Δ{}
  ret call imax 5 _t3  ; Δ{}
  ret call imax lo _t0  ; Δ{}
  ret call imin 2000 _t5  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call linesFrom s 0 _t0  ; Δ{} · makes List$String
  ret call openTry win ren n idx z px py rot n  ; Δ{}
  ret call spGo cmd rep 0  ; Δ{} · makes String
  ret call tabScan s 0  ; Δ{}
  ret call toLowerGo s 0 _t0  ; Δ{} · makes String
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t10 of
  ret case _t2 of
  ret case _t2 of
  ret case _t3 of
  ret case _t5 of
  ret case _t5 of
  ret case key of
  ret case m of
  ret case ty of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Cons _t1 _t3  ; Δ{_t1 _t3} · moves{_t1 _t3} · makes List$String
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t6 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_peek_u32 axsr 0  ; Δ{}
  ret rtcall axion_peek_u32 axsr 12  ; Δ{}
  ret rtcall axion_peek_u32 axsr 4  ; Δ{}
  ret rtcall axion_peek_u32 axsr 8  ; Δ{}
  ret rtcall axion_substr 0 _t0 s  ; Δ{} · makes String
  ret rtcall axion_substr _t0 _t4 s  ; Δ{} · makes String
  ret x  ; Δ{}
<=$Int x y  =
>=$Int x y  =
altHeld md  =
animAct win ren n idx anim nf fp dp fi ty key md  =
animCmd win ren n idx anim act  =
animNamed win ren n idx anim nf fp dp fi act  =
animPlay win ren n idx anim nf fp dp fi  =
animQuit win ren anim  =
animReopen win ren anim n idx  =
animStart win ren n idx anim tries  =
argCount i  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$Int _p  =
baseAfter s k  =
baseName s  =
buildImgList seed  =
buildKeymap d  =
clamp lo hi x  =
configFile d  =
consLine s i n j  =
ctrlHeld md  =
dispatch win ren n idx tex tw th z px py rot fitPct ty key md  =
dup s  =
envOr name dflt  =
findByBase xs b i  =
findChar c s i n  =
frame win ren n idx tex tw th z px py rot acc  =
fromMaybe d m  =
h axsr  =
hasPrefix p s  =
hasSuffix q s  =
imageCount d  =
imagePath idx  =
imax a b  =
imgLines d  =
imgListFile d  =
imin a b  =
ippGo xs acc  =
isAnim p  =
isAnimLc q  =
isDigit c  =
isPctS cmd i  =
isProperPrefix km acc  =
isSpace c  =
keyBase key  =
keyName key md  =
keyToken key md  =
keymapFile d  =
kmKey line  =
kmVal line  =
laGo xs k  =
lam$0 [env ]x  =
lastIndex c s i best  =
le$Int x y  =
length xs  =
lines s  =
linesFrom s i n  =
lookupAction km k  =
lowerChar c  =
main  =
maybe d f m  =
mk__SDL_Rect x y w h  =
nthLine xs i  =
onKey win ren n idx tex tw th z px py rot curPct key md  =
openImage win ren n idx z px py rot  =
openTry win ren n idx z px py rot tries  =
optionInt name dflt lo hi  =
panPx ren axis  =
quitTex win ren tex  =
quitWith win ren  =
readInt s  =
readIntGo s i acc  =
renderAt ren tex rot pct tw th ow oh px py  =
reopen win ren tex n idx  =
runConfigCmd win ren n idx tex act  =
runNamed win ren n idx tex tw th z px py rot curPct act  =
seqStarts b acc  =
shEsc s i n  =
shQuote s  =
shiftGlyph key  =
shiftHeld md  =
spGo cmd rep i  =
startIndex seed  =
staticTry win ren n idx z px py rot tries  =
substPct cmd rep  =
tabIdx s  =
tabScan s i  =
titleFor path idx n z  =
toLower s  =
toLowerGo s i n  =
trim s  =
trimEnd s j  =
trimStart s i  =
userCmd path cmd  =
w axsr  =
x axsr  =
y axsr  =
zoomedIn pct  =
zoomedOut pct  =
