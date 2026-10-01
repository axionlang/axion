





























































































































                                                                ret call favOrIgnore cwd sel marked prog hidden rows key  ; Δ{}
                                                                ret call quit cwd  ; Δ{}
                                                              else
                                                              let _t88 = rtcall axion_str_cmp key ""  ; Δ{}
                                                              let _t89 = == _t88 0  ; Δ{}
                                                              ret call quit cwd  ; Δ{}
                                                              ret if _t89 then
                                                            else
                                                            let _t86 = rtcall axion_str_cmp key "q"  ; Δ{}
                                                            let _t87 = == _t86 0  ; Δ{}
                                                            ret call doShell cwd sel marked prog hidden rows  ; Δ{}
                                                            ret if _t87 then
                                                          else
                                                          let _t84 = rtcall axion_str_cmp key "!"  ; Δ{}
                                                          let _t85 = == _t84 0  ; Δ{}
                                                          ret call doBulk cwd sel marked prog hidden rows  ; Δ{}
                                                          ret if _t85 then
                                                        else
                                                        let _t82 = rtcall axion_str_cmp key "b"  ; Δ{}
                                                        let _t83 = == _t82 0  ; Δ{}
                                                        ret call doPaste cwd sel marked prog hidden rows  ; Δ{}
                                                        ret if _t83 then
                                                      else
                                                      let _t80 = rtcall axion_str_cmp key "p"  ; Δ{}
                                                      let _t81 = == _t80 0  ; Δ{}
                                                      ret call loop cwd sel "" "" hidden rows  ; Δ{}
                                                      ret if _t81 then
                                                    drop _t77 : String
                                                    else
                                                    let _d1000008 = call loop cwd sel _t77 "trash" hidden rows  ; Δ{_t77}
                                                    let _t77 = call allPaths cwd hidden  ; Δ{} · makes String
                                                    let _t78 = rtcall axion_str_cmp key "c"  ; Δ{}
                                                    let _t79 = == _t78 0  ; Δ{}
                                                    ret _d1000008  ; Δ{}
                                                    ret if _t79 then
                                                  drop _t74 : String
                                                  else
                                                  let _d1000007 = call loop cwd sel _t74 "ln -s" hidden rows  ; Δ{_t74}
                                                  let _t74 = call allPaths cwd hidden  ; Δ{} · makes String
                                                  let _t75 = rtcall axion_str_cmp key "D"  ; Δ{}
                                                  let _t76 = == _t75 0  ; Δ{}
                                                  ret _d1000007  ; Δ{}
                                                  ret if _t76 then
                                                drop _t71 : String
                                                else
                                                let _d1000006 = call loop cwd sel _t71 "mv -i" hidden rows  ; Δ{_t71}
                                                let _t71 = call allPaths cwd hidden  ; Δ{} · makes String
                                                let _t72 = rtcall axion_str_cmp key "S"  ; Δ{}
                                                let _t73 = == _t72 0  ; Δ{}
                                                ret _d1000006  ; Δ{}
                                                ret if _t73 then
                                              drop _t68 : String
                                              else
                                              let _d1000005 = call loop cwd sel _t68 "cp -iR" hidden rows  ; Δ{_t68}
                                              let _t68 = call allPaths cwd hidden  ; Δ{} · makes String
                                              let _t69 = rtcall axion_str_cmp key "M"  ; Δ{}
                                              let _t70 = == _t69 0  ; Δ{}
                                              ret _d1000005  ; Δ{}
                                              ret if _t70 then
                                            drop _t64 : String
                                            drop _t65 : String
                                            else
                                            let _d1000004 = call loop cwd sel _t65 "trash" hidden rows  ; Δ{_t65}
                                            let _t64 = call selPath cwd hidden sel  ; Δ{} · makes String
                                            let _t65 = call markToggle marked _t64  ; Δ{_t64} · makes String
                                            let _t66 = rtcall axion_str_cmp key "Y"  ; Δ{}
                                            let _t67 = == _t66 0  ; Δ{}
                                            ret _d1000004  ; Δ{}
                                            ret if _t67 then
                                          drop _t60 : String
                                          drop _t61 : String
                                          else
                                          let _d1000003 = call loop cwd sel _t61 "ln -s" hidden rows  ; Δ{_t61}
                                          let _t60 = call selPath cwd hidden sel  ; Δ{} · makes String
                                          let _t61 = call markToggle marked _t60  ; Δ{_t60} · makes String
                                          let _t62 = rtcall axion_str_cmp key "d"  ; Δ{}
                                          let _t63 = == _t62 0  ; Δ{}
                                          ret _d1000003  ; Δ{}
                                          ret if _t63 then
                                        drop _t56 : String
                                        drop _t57 : String
                                        else
                                        let _d1000002 = call loop cwd sel _t57 "mv -i" hidden rows  ; Δ{_t57}
                                        let _t56 = call selPath cwd hidden sel  ; Δ{} · makes String
                                        let _t57 = call markToggle marked _t56  ; Δ{_t56} · makes String
                                        let _t58 = rtcall axion_str_cmp key "s"  ; Δ{}
                                        let _t59 = == _t58 0  ; Δ{}
                                        ret _d1000002  ; Δ{}
                                        ret if _t59 then
                                      drop _t52 : String
                                      drop _t53 : String
                                      else
                                      let _d1000001 = call loop cwd sel _t53 "cp -iR" hidden rows  ; Δ{_t53}
                                      let _t52 = call selPath cwd hidden sel  ; Δ{} · makes String
                                      let _t53 = call markToggle marked _t52  ; Δ{_t52} · makes String
                                      let _t54 = rtcall axion_str_cmp key "m"  ; Δ{}
                                      let _t55 = == _t54 0  ; Δ{}
                                      ret _d1000001  ; Δ{}
                                      ret if _t55 then
                                    else
                                    let _t50 = rtcall axion_str_cmp key "y"  ; Δ{}
                                    let _t51 = == _t50 0  ; Δ{}
                                    ret call doChmod cwd sel marked prog hidden rows  ; Δ{}
                                    ret if _t51 then
                                  else
                                  let _t48 = rtcall axion_str_cmp key "X"  ; Δ{}
                                  let _t49 = == _t48 0  ; Δ{}
                                  ret call doAttr cwd sel marked prog hidden rows  ; Δ{}
                                  ret if _t49 then
                                else
                                let _t46 = rtcall axion_str_cmp key "x"  ; Δ{}
                                let _t47 = == _t46 0  ; Δ{}
                                ret call doRename cwd sel marked prog hidden rows  ; Δ{}
                                ret if _t47 then
                              else
                              let _t44 = rtcall axion_str_cmp key "r"  ; Δ{}
                              let _t45 = == _t44 0  ; Δ{}
                              ret call doMkfile cwd sel marked prog hidden rows  ; Δ{}
                              ret if _t45 then
                            else
                            let _t42 = rtcall axion_str_cmp key "f"  ; Δ{}
                            let _t43 = == _t42 0  ; Δ{}
                            ret call doMkdir cwd sel marked prog hidden rows  ; Δ{}
                            ret if _t43 then
                          else
                          let _t40 = rtcall axion_str_cmp key "n"  ; Δ{}
                          let _t41 = == _t40 0  ; Δ{}
                          ret call doSearch cwd sel marked prog hidden rows  ; Δ{}
                          ret if _t41 then
                        else
                        let _t38 = rtcall axion_str_cmp key "/"  ; Δ{}
                        let _t39 = == _t38 0  ; Δ{}
                        ret call doGoDir cwd sel marked prog hidden rows  ; Δ{}
                        ret if _t39 then
                      drop _t8 : String
                      else
                      let _t36 = rtcall axion_str_cmp key ":"  ; Δ{}
                      let _t37 = == _t36 0  ; Δ{}
                      ret call goPrev marked prog hidden rows  ; Δ{}
                      ret call loop cwd sel marked prog hidden rows  ; Δ{}
                      ret if _t37 then
                      ret rtcall axion_unlink tmp  ; Δ{}
                    _ ->
                    _ ->
                    else
                    let _t34 = rtcall axion_str_cmp key "-"  ; Δ{}
                    let _t35 = == _t34 0  ; Δ{}
                    ret call goHome marked prog hidden rows  ; Δ{}
                    ret if _t35 then
                  drop _t15 : String
                  drop _t9 : String
                  else
                  let _t10 = putStr _t9  ; Δ{_t8 _t9}
                  let _t15 = call setupSeq  ; Δ{} · makes String
                  let _t16 = putStr _t15  ; Δ{_t15}
                  let _t29 = call nEntries cwd hidden  ; Δ{}
                  let _t30 = call clampSel sel _t29  ; Δ{}
                  let _t31 = call termRows 0  ; Δ{}
                  let _t32 = rtcall axion_str_cmp key "~"  ; Δ{}
                  let _t33 = == _t32 0  ; Δ{}
                  let _t9 = call setupSeq  ; Δ{_t8} · makes String
                  ret 0  ; Δ{}
                  ret 1  ; Δ{}
                  ret call loop cwd _t30 marked prog hidden _t31  ; Δ{}
                  ret case _t10 of
                  ret case _t16 of
                  ret if _t33 then
                _ ->
                _ ->
                else
                else
                let _t25 = == hidden 1  ; Δ{}
                let _t26 = if _t25 then
                let _t27 = rtcall axion_str_cmp key "e"  ; Δ{}
                let _t28 = == _t27 0  ; Δ{}
                ret call loop cwd 0 marked prog _t26 rows  ; Δ{}
                ret if _t28 then
              drop _t10 : List$String
              drop _t11 : String
              drop _t13 : List$String
              drop _t22 : String
              else
              let _d1000000 = call loop _t22 0 marked prog hidden rows  ; Δ{_t22}
              let _t10 = call filter$$nonEmpty _t9  ; Δ{_t9} · moves{_t9} · makes List$String
              let _t11 = rtcall axion_read_file tmp  ; Δ{_t10} · makes String
              let _t12 = call lines _t11  ; Δ{_t10 _t11} · makes List$String
              let _t13 = call filter$$nonEmpty _t12  ; Δ{_t10 _t12} · moves{_t12} · makes List$String
              let _t14 = call bulkApply _t10 _t13 cwd  ; Δ{_t10 _t13}
              let _t22 = call dirName cwd  ; Δ{} · makes String
              let _t23 = rtcall axion_str_cmp key "."  ; Δ{}
              let _t24 = == _t23 0  ; Δ{}
              let _t8 = rtcall axion_read_key 0  ; Δ{} · makes String
              let _t9 = call lines marked  ; Δ{} · makes List$String
              ret _d1000000  ; Δ{}
              ret call bulkApply os ns cwd  ; Δ{}
              ret call loop cwd sel marked prog hidden rows  ; Δ{}
              ret call loop cwd sel marked prog hidden rows  ; Δ{}
              ret case _t14 of
              ret case _t8 of
              ret if _t24 then
            _ ->
            _ ->
            _ ->
            _ ->
            _ ->
            drop _t17 : List$String
            drop _t3 : String
            else
            let _d1000000 = rtcall axion_rename o _t3  ; Δ{_t3}
            let _t17 = call entriesRaw cwd 1  ; Δ{} · makes List$String
            let _t18 = call firstPrefix _t17 acc  ; Δ{_t17} · makes String
            let _t19 = call dupOrAcc _t18 acc  ; Δ{_t18} · moves{_t18} · makes String
            let _t20 = rtcall axion_str_cmp key "h"  ; Δ{}
            let _t20 = rtcall axion_strcat acc k  ; Δ{} · makes String
            let _t21 = == _t20 0  ; Δ{}
            let _t3 = call </> cwd n  ; Δ{} · makes String
            ret 0  ; Δ{}
            ret _d1000000  ; Δ{}
            ret call cmdGo prompt rows cwd _t19  ; Δ{_t19} · moves{_t19} · makes String
            ret call cmdGo prompt rows cwd _t20  ; Δ{_t20} · moves{_t20} · makes String
            ret call open cwd sel marked prog hidden rows  ; Δ{}
            ret if _t21 then
          drop _t0 : String
          drop _t4 : String
          drop _t5 : String
          drop _t5 : String
          drop _t6 : String
          drop _t6 : String
          drop _t7 : String
          drop _t8 : String
          drop _t8 : String
          else
          else
          else
          let _d1000000 = call loop _t6 0 "" "" 0 _t7  ; Δ{_t6}
          let _t0 = call </> cwd n  ; Δ{} · makes String
          let _t1 = rtcall axion_str_cmp o _t0  ; Δ{_t0}
          let _t14 = call dropLast acc  ; Δ{} · makes String
          let _t14 = call nEntries cwd hidden  ; Δ{}
          let _t15 = - _t14 1  ; Δ{}
          let _t15 = rtcall axion_str_at 0 k  ; Δ{}
          let _t16 = == _t15 9  ; Δ{}
          let _t16 = call nEntries cwd hidden  ; Δ{}
          let _t17 = call clampSel _t15 _t16  ; Δ{}
          let _t18 = rtcall axion_str_cmp key "l"  ; Δ{}
          let _t19 = == _t18 0  ; Δ{}
          let _t2 = == _t1 0  ; Δ{}
          let _t4 = call editorCmd 0  ; Δ{} · makes String
          let _t4 = if _t2 then
          let _t5 = call shQuote tmp  ; Δ{_t4} · makes String
          let _t5 = rtcall axion_getarg 0  ; Δ{} · makes String
          let _t6 = call startDir _t5  ; Δ{_t5} · makes String
          let _t6 = rtcall axion_strcat " " _t5  ; Δ{_t4 _t5} · makes String
          let _t7 = call termRows 0  ; Δ{_t6}
          let _t7 = putStr "\n[any key]"  ; Δ{}
          let _t7 = rtcall axion_strcat _t4 _t6  ; Δ{_t4 _t6} · makes String
          let _t8 = call setupSeq  ; Δ{} · makes String
          let _t8 = call setupSeq  ; Δ{} · makes String
          let _t8 = rtcall axion_system _t7  ; Δ{_t7}
          let _t9 = putStr _t8  ; Δ{_t8}
          let _t9 = putStr _t8  ; Δ{_t8}
          ret ""  ; Δ{}
          ret "h"  ; Δ{}
          ret 0  ; Δ{}
          ret _d1000000  ; Δ{}
          ret call cmdGo prompt rows cwd _t14  ; Δ{_t14} · moves{_t14} · makes String
          ret call loop cwd _t17 marked prog hidden rows  ; Δ{}
          ret case _t4 of
          ret case _t7 of
          ret case _t8 of
          ret case _t9 of
          ret case _t9 of
          ret if _t16 then
          ret if _t19 then
        Cons n ns ->
        Nil ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        drop _t3 : String
        drop _t5 : String
        drop y : String
        drop y : String
        else
        else
        else
        let _d1000000 = rtcall axion_strcat _t3 _t5  ; Δ{_t3 _t5} · makes String
        let _t1 = + i 1  ; Δ{}
        let _t1 = - i 1  ; Δ{}
        let _t1 = call filter$$neStr _cap0 ys  ; Δ{y ys} · moves{ys} · makes List$String
        let _t1 = call filter$$nonEmpty ys  ; Δ{y ys} · moves{ys} · makes List$String
        let _t10 = == _t9 127  ; Δ{}
        let _t11 = rtcall axion_str_at 0 k  ; Δ{}
        let _t12 = == _t11 8  ; Δ{}
        let _t12 = rtcall axion_str_cmp key "G"  ; Δ{}
        let _t13 = == _t12 0  ; Δ{}
        let _t13 = call || _t10 _t12  ; Δ{}
        let _t3 = call rowFor y i sel marked cwd  ; Δ{} · makes String
        let _t4 = + i 1  ; Δ{_t3}
        let _t5 = call drawRows ys _t4 start endIdx sel marked cwd  ; Δ{_t3} · makes String
        let _t6 = + i 1  ; Δ{}
        let _t6 = div mx 2  ; Δ{}
        let _t6 = rtcall axion_str_cmp b "D"  ; Δ{}
        let _t7 = == _t6 0  ; Δ{}
        let _t9 = rtcall axion_str_at 0 k  ; Δ{}
        ret ""  ; Δ{}
        ret "l"  ; Δ{}
        ret - n 1  ; Δ{}
        ret - sel _t6  ; Δ{}
        ret - total mx  ; Δ{}
        ret 1  ; Δ{}
        ret 1  ; Δ{}
        ret == c 13  ; Δ{}
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
        ret call drawRows ys _t6 start endIdx sel marked cwd  ; Δ{} · makes String
        ret call dup y  ; Δ{} · makes String
        ret call elemBy$String x ys  ; Δ{}
        ret call filter$$neStr _cap0 ys  ; Δ{ys} · moves{ys} · makes List$String
        ret call filter$$nonEmpty ys  ; Δ{ys} · moves{ys} · makes List$String
        ret call firstPrefix ys q  ; Δ{} · makes String
        ret call loop cwd 0 marked prog hidden rows  ; Δ{}
        ret call matchIndex ys q _t1 dflt  ; Δ{}
        ret call pick _t1 ys  ; Δ{} · makes String
        ret call stripSlash y  ; Δ{} · makes String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
        ret i  ; Δ{}
        ret i  ; Δ{}
        ret if _t13 then
        ret if _t13 then
        ret if _t7 then
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t1 : String
      drop _t1 : String
      drop _t1 : String
      drop _t1 : String
      drop _t10 : String
      drop _t2 : String
      drop _t2 : String
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
      drop _t4 : String
      drop _t4 : String
      drop _t4 : String
      drop _t4 : String
      drop _t5 : String
      drop _t5 : String
      drop _t5 : String
      drop _t5 : String
      drop _t6 : String
      drop _t6 : String
      drop _t7 : String
      drop b1 : String
      drop b2 : String
      drop e : String
      drop k : String
      drop m
      drop m
      drop v : String
      drop v : String
      drop xs
      drop xs
      drop xs
      drop xs
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
      let _d1000000 = call arrowKey b2  ; Δ{b2 k} · makes String
      let _d1000000 = call cmdKey prompt rows cwd acc _t10  ; Δ{_t10} · makes String
      let _d1000000 = call step cwd sel marked prog hidden rows _t2  ; Δ{_t2}
      let _d1000000 = putStr _t3  ; Δ{_t3}
      let _d1000000 = rtcall axion_strcat "'\\''" _t4  ; Δ{_t4} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
      let _d1000000 = rtcall axion_strcat _t2 _t3  ; Δ{_t2 _t3} · makes String
      let _d1000000 = rtcall axion_strcat s _t1  ; Δ{_t1} · makes String
      let _d1000001 = rtcall axion_strcat _t5 _t7  ; Δ{_t5 _t7} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = == i 0  ; Δ{}
      let _t0 = call >=$Int i start  ; Δ{}
      let _t0 = call baseName y  ; Δ{} · makes String
      let _t0 = call eq$String x y  ; Δ{}
      let _t0 = call hasInfix q y  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call neStr _cap0 y  ; Δ{y ys}
      let _t0 = call nonEmpty y  ; Δ{y ys}
      let _t0 = call shQuote y  ; Δ{} · makes String
      let _t0 = call stripSlash y  ; Δ{} · makes String
      let _t0 = call stripSlash y  ; Δ{} · makes String
      let _t0 = call unlines ss  ; Δ{} · makes String
      let _t1 = < i endIdx  ; Δ{}
      let _t1 = call </> cwd _t0  ; Δ{_t0} · makes String
      let _t1 = call bnGo ys  ; Δ{_t0} · makes String
      let _t1 = call hasPrefix q _t0  ; Δ{_t0}
      let _t1 = call qlGo ys  ; Δ{_t0} · makes String
      let _t1 = rtcall axion_strcat "\n" _t0  ; Δ{_t0} · makes String
      let _t10 = rtcall axion_read_key 0  ; Δ{} · makes String
      let _t10 = rtcall axion_str_cmp key "g"  ; Δ{}
      let _t11 = == _t10 0  ; Δ{}
      let _t2 = == c 10  ; Δ{}
      let _t2 = call && _t0 _t1  ; Δ{}
      let _t2 = call >=$Int i n  ; Δ{}
      let _t2 = call editorCmd 0  ; Δ{} · makes String
      let _t2 = call readMainKey 0  ; Δ{} · makes String
      let _t2 = call resetSeq  ; Δ{} · makes String
      let _t2 = call selPath cwd hidden sel  ; Δ{} · makes String
      let _t2 = call shQuote cwd  ; Δ{} · makes String
      let _t2 = rtcall axion_strcat " " _t1  ; Δ{_t0 _t1} · makes String
      let _t2 = rtcall axion_strcat "\n" _t1  ; Δ{_t0 _t1} · makes String
      let _t2 = rtcall axion_strcat _t1 "\n"  ; Δ{_t1} · makes String
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = - total sel  ; Δ{}
      let _t3 = call envOr "SHELL" "sh"  ; Δ{_t2} · makes String
      let _t3 = call joinPaths cwd ys  ; Δ{_t2} · makes String
      let _t3 = call nEntries cwd hidden  ; Δ{}
      let _t3 = call resetSeq  ; Δ{} · makes String
      let _t3 = call selPath cwd hidden sel  ; Δ{_t2} · makes String
      let _t3 = call setupSeq  ; Δ{} · makes String
      let _t3 = call shQuote _t2  ; Δ{_t2} · makes String
      let _t3 = putStr _t2  ; Δ{_t2}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = call markCount marked  ; Δ{}
      let _t4 = call nEntries cwd hidden  ; Δ{}
      let _t4 = call shEsc s _t3 n  ; Δ{} · makes String
      let _t4 = call shQuote _t3  ; Δ{_t2 _t3} · makes String
      let _t4 = div mx 2  ; Δ{}
      let _t4 = putStr _t3  ; Δ{_t3}
      let _t4 = rtcall axion_str_cmp b "C"  ; Δ{}
      let _t4 = rtcall axion_strcat " && " _t3  ; Δ{_t2 _t3} · makes String
      let _t4 = rtcall axion_strcat "stat -- " _t3  ; Δ{_t3} · makes String
      let _t5 = * acc 10  ; Δ{}
      let _t5 = + _t3 _t4  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t5 = == _t4 0  ; Δ{}
      let _t5 = call <=$Int _t3 _t4  ; Δ{}
      let _t5 = call clampSel sel _t4  ; Δ{}
      let _t5 = call nEntries cwd hidden  ; Δ{}
      let _t5 = call nEntries cwd hidden  ; Δ{}
      let _t5 = rtcall axion_run _t4  ; Δ{_t4} · makes String
      let _t5 = rtcall axion_strcat " " _t4  ; Δ{_t2 _t4} · makes String
      let _t5 = rtcall axion_strcat _t2 _t4  ; Δ{_t2 _t4} · makes String
      let _t5 = rtcall axion_substr i 1 s  ; Δ{} · makes String
      let _t6 = + _t5 1  ; Δ{}
      let _t6 = + _t5 1  ; Δ{}
      let _t6 = + i 1  ; Δ{_t5}
      let _t6 = call clampSel sel _t5  ; Δ{}
      let _t6 = putStr _t5  ; Δ{_t5}
      let _t6 = rtcall axion_str_at i s  ; Δ{}
      let _t6 = rtcall axion_strcat "cd " _t5  ; Δ{_t5} · makes String
      let _t6 = rtcall axion_strcat _t2 _t5  ; Δ{_t2 _t5} · makes String
      let _t7 = - _t6 48  ; Δ{}
      let _t7 = - sel 1  ; Δ{}
      let _t7 = call clampSel sel _t6  ; Δ{}
      let _t7 = call clampSel sel _t6  ; Δ{}
      let _t7 = call shEsc s _t6 n  ; Δ{_t5} · makes String
      let _t7 = rtcall axion_str_at 0 k  ; Δ{}
      let _t7 = rtcall axion_system _t6  ; Δ{_t6}
      let _t7 = rtcall axion_system _t6  ; Δ{_t6}
      let _t8 = + _t5 _t7  ; Δ{}
      let _t8 = == _t7 27  ; Δ{}
      let _t8 = call nEntries cwd hidden  ; Δ{}
      let _t9 = call clampSel _t7 _t8  ; Δ{}
      let b1 = rtcall axion_read_key 0  ; Δ{k} · makes String
      let b2 = rtcall axion_read_key 0  ; Δ{k} · makes String
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret "j"  ; Δ{}
      ret "vi"  ; Δ{}
      ret + 1 _t0  ; Δ{}
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
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{}
      ret _d1000000  ; Δ{}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret acc  ; Δ{}
      ret call findChar c s _t3 n  ; Δ{}
      ret call infixGo q s _t5 lim  ; Δ{}
      ret call lastIndex c s _t4 i  ; Δ{}
      ret call lastIndex c s _t5 best  ; Δ{}
      ret call loop cwd _t5 "" "" hidden rows  ; Δ{}
      ret call loop cwd _t6 "" "" hidden rows  ; Δ{}
      ret call loop cwd _t7 marked prog hidden rows  ; Δ{}
      ret call loop cwd _t7 marked prog hidden rows  ; Δ{}
      ret call loop cwd _t9 marked prog hidden rows  ; Δ{}
      ret call loop cwd sel marked prog hidden rows  ; Δ{}
      ret call loop cwd sel marked prog hidden rows  ; Δ{}
      ret call loop cwd sel marked prog hidden rows  ; Δ{}
      ret call readIntGo s _t4 _t8  ; Δ{} · makes Maybe$Int
      ret call wordEnd s _t3 n  ; Δ{}
      ret callclo f x  ; Δ{x} · moves{x}
      ret case _t3 of
      ret case _t4 of
      ret case _t6 of
      ret case _t7 of
      ret case _t7 of
      ret case news of
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret d  ; Δ{}
      ret dflt  ; Δ{}
      ret e  ; Δ{e} · moves{e}
      ret i  ; Δ{}
      ret i  ; Δ{}
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t1 then
      ret if _t11 then
      ret if _t2 then
      ret if _t2 then
      ret if _t2 then
      ret if _t5 then
      ret if _t5 then
      ret if _t8 then
      ret k  ; Δ{k} · moves{k}
    Cons o os ->
    Cons s ss ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
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
    Nil ->
    Nil ->
    Nil ->
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
    _ ->
    _ ->
    drop _t0 : String
    drop _t0 : String
    drop _t0 : String
    drop _t0 : String
    drop _t0 : String
    drop _t0 : String
    drop _t0 : String
    drop _t10 : String
    drop _t10 : String
    drop _t11 : String
    drop _t11 : String
    drop _t12 : String
    drop _t12 : String
    drop _t13 : String
    drop _t14 : String
    drop _t2 : List$String
    drop _t2 : String
    drop _t2 : String
    drop _t2 : String
    drop _t2 : String
    drop _t3 : List$String
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
    drop _t5 : String
    drop _t5 : String
    drop _t6 : String
    drop _t6 : String
    drop _t6 : String
    drop _t7 : String
    drop _t7 : String
    drop _t7 : String
    drop _t7 : String
    drop _t8 : String
    drop _t8 : String
    drop _t9 : String
    drop _t9 : String
    drop fav : String
    drop fav : String
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
    let _d1000000 = call loop _t2 0 marked prog hidden rows  ; Δ{_t2}
    let _d1000000 = call loop _t4 0 marked prog hidden rows  ; Δ{_t4}
    let _d1000000 = call loop fav 0 marked prog hidden rows  ; Δ{fav}
    let _d1000000 = call matchIndex _t3 _t0 0 sel  ; Δ{_t0 _t3}
    let _d1000000 = call unlines _t2  ; Δ{_t2} · makes String
    let _d1000000 = rtcall axion_mkdir_p _t3  ; Δ{_t3}
    let _d1000000 = rtcall axion_rename _t6 _t7  ; Δ{_t6 _t7}
    let _d1000000 = rtcall axion_strcat a _t0  ; Δ{_t0} · makes String
    let _d1000000 = rtcall axion_system _t8  ; Δ{_t8}
    let _d1000000 = rtcall axion_write_file _t3 ""  ; Δ{_t3}
    let _d1000001 = call paint "7" _t7  ; Δ{_t0 _t7} · makes String
    let _d1000001 = rtcall axion_strcat m _t3  ; Δ{_t3} · makes String
    let _d1000001 = rtcall axion_system _t14  ; Δ{_t14}
    let _d1000002 = rtcall axion_strcat _t10 _t12  ; Δ{_t0 _t10 _t12} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t0 = rtcall axion_strcat "/" b  ; Δ{} · makes String
    let _t1 = + k 1  ; Δ{}
    let _t1 = < i 0  ; Δ{}
    let _t1 = == c 9  ; Δ{}
    let _t1 = call findChar 10 s i n  ; Δ{}
    let _t1 = call lines m  ; Δ{} · makes List$String
    let _t1 = div mx 2  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_len q  ; Δ{}
    let _t1 = rtcall axion_str_len s  ; Δ{}
    let _t10 = call markChar marked _t9  ; Δ{_t0 _t9} · makes String
    let _t10 = call shQuote cwd  ; Δ{_t9} · makes String
    let _t11 = call colorName raw  ; Δ{_t0 _t10} · makes String
    let _t11 = rtcall axion_strcat " " _t10  ; Δ{_t10 _t9} · makes String
    let _t12 = rtcall axion_strcat " " _t11  ; Δ{_t0 _t10 _t11} · makes String
    let _t12 = rtcall axion_strcat _t9 _t11  ; Δ{_t11 _t9} · makes String
    let _t13 = rtcall axion_strcat " -- " _t12  ; Δ{_t12} · makes String
    let _t14 = rtcall axion_strcat prog _t13  ; Δ{_t13} · makes String
    let _t2 = + i 1  ; Δ{}
    let _t2 = + sel 1  ; Δ{}
    let _t2 = - _t1 1  ; Δ{}
    let _t2 = < sel _t1  ; Δ{}
    let _t2 = == _t1 39  ; Δ{}
    let _t2 = == _t1 c  ; Δ{}
    let _t2 = call bulkTmp 0  ; Δ{} · makes String
    let _t2 = call filter$$neStr p _t1  ; Δ{_t1} · moves{_t1} · makes List$String
    let _t2 = call isSpace _t1  ; Δ{}
    let _t2 = call selPath cwd hidden sel  ; Δ{} · makes String
    let _t2 = call stripSlash raw  ; Δ{_t0} · makes String
    let _t2 = call trashDir 0  ; Δ{} · makes String
    let _t2 = rtcall axion_str_at 0 k  ; Δ{k}
    let _t2 = rtcall axion_str_at 0 k  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_cmp b "B"  ; Δ{}
    let _t2 = rtcall axion_str_len e  ; Δ{e v}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t2 = rtcall axion_substr i _t1 s  ; Δ{} · makes String
    let _t3 = - _t2 1  ; Δ{}
    let _t3 = - _t2 k  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = == _t2 13  ; Δ{}
    let _t3 = == _t2 27  ; Δ{k}
    let _t3 = == _t2 c  ; Δ{}
    let _t3 = > _t2 0  ; Δ{e v}
    let _t3 = call </> cwd _t0  ; Δ{_t0} · makes String
    let _t3 = call </> cwd _t0  ; Δ{_t0} · makes String
    let _t3 = call </> cwd _t2  ; Δ{_t0 _t2} · makes String
    let _t3 = call entriesRaw cwd hidden  ; Δ{_t0} · makes List$String
    let _t3 = call isDigit _t2  ; Δ{}
    let _t3 = call nEntries cwd hidden  ; Δ{}
    let _t3 = call shQuote _t2  ; Δ{_t2} · makes String
    let _t3 = call wordEnd s i n  ; Δ{}
    let _t3 = rtcall axion_str_cmp q _t2  ; Δ{_t2}
    let _t3 = rtcall axion_str_len p  ; Δ{}
    let _t3 = rtcall axion_str_len s  ; Δ{}
    let _t3 = rtcall axion_strcat p "\n"  ; Δ{} · makes String
    let _t4 = - _t3 1  ; Δ{}
    let _t4 = == _t3 0  ; Δ{}
    let _t4 = call clampSel _t2 _t3  ; Δ{}
    let _t4 = call dup nm  ; Δ{} · makes String
    let _t4 = call markChar marked _t3  ; Δ{_t0 _t3} · makes String
    let _t4 = call quoteLines marked  ; Δ{_t3} · makes String
    let _t4 = rtcall axion_str_at 0 k  ; Δ{}
    let _t4 = rtcall axion_str_len q  ; Δ{}
    let _t4 = rtcall axion_substr 0 _t3 s  ; Δ{} · makes String
    let _t5 = - _t3 _t4  ; Δ{}
    let _t5 = == _t4 10  ; Δ{}
    let _t5 = call dup raw  ; Δ{_t0 _t4} · makes String
    let _t5 = rtcall axion_str_cmp _t4 p  ; Δ{_t4}
    let _t5 = rtcall axion_str_cmp key "k"  ; Δ{}
    let _t5 = rtcall axion_strcat _t4 " \"$d\""  ; Δ{_t3 _t4} · makes String
    let _t6 = == _t5 0  ; Δ{}
    let _t6 = call selPath cwd hidden sel  ; Δ{_t3} · makes String
    let _t6 = call || _t3 _t5  ; Δ{}
    let _t6 = rtcall axion_str_len q  ; Δ{}
    let _t6 = rtcall axion_strcat " " _t5  ; Δ{_t0 _t4 _t5} · makes String
    let _t6 = rtcall axion_strcat "; mkdir -p \"$d\" && mv -f -- " _t5  ; Δ{_t3 _t5} · makes String
    let _t7 = call </> cwd _t3  ; Δ{_t3 _t6} · makes String
    let _t7 = rtcall axion_strcat _t3 _t6  ; Δ{_t3 _t6} · makes String
    let _t7 = rtcall axion_strcat _t4 _t6  ; Δ{_t0 _t4 _t6} · makes String
    let _t7 = rtcall axion_substr _t5 _t6 s  ; Δ{} · makes String
    let _t8 = call stripSlash raw  ; Δ{_t0} · makes String
    let _t8 = rtcall axion_str_cmp _t7 q  ; Δ{_t7}
    let _t8 = rtcall axion_strcat "d=" _t7  ; Δ{_t7} · makes String
    let _t9 = call </> cwd _t8  ; Δ{_t0 _t8} · makes String
    let _t9 = call quoteLines marked  ; Δ{} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let e = rtcall axion_getenv "EDITOR"  ; Δ{v} · makes String
    ret " "  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret "*"  ; Δ{}
    ret "."  ; Δ{}
    ret "."  ; Δ{}
    ret "chmod +x -- "  ; Δ{}
    ret "chmod -x -- "  ; Δ{}
    ret "k"  ; Δ{}
    ret "ls -Ap --group-directories-first -- "  ; Δ{}
    ret "ls -p --group-directories-first -- "  ; Δ{}
    ret - rows 3  ; Δ{}
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
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret == _t5 0  ; Δ{}
    ret == _t8 0  ; Δ{}
    ret == x y  ; Δ{}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000001  ; Δ{_d1000001 _t0} · moves{_d1000001}
    ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
    ret _d1000001  ; Δ{}
    ret _d1000002  ; Δ{_d1000002 _t0} · moves{_d1000002}
    ret acc  ; Δ{}
    ret best  ; Δ{}
    ret call bulkRun cwd marked _t2  ; Δ{_t2} · moves{_t2}
    ret call consLine s i n _t1  ; Δ{} · makes List$String
    ret call consWord s i n _t3  ; Δ{} · makes List$String
    ret call dup a  ; Δ{} · makes String
    ret call dup acc  ; Δ{} · makes String
    ret call dup dflt  ; Δ{} · makes String
    ret call dup raw  ; Δ{} · makes String
    ret call dup s  ; Δ{} · makes String
    ret call loop cwd _t4 marked prog hidden rows  ; Δ{}
    ret call loop cwd sel marked prog hidden rows  ; Δ{}
    ret call loop cwd sel marked prog hidden rows  ; Δ{}
    ret call markInfo marked prog  ; Δ{} · makes String
    ret call openFile cwd sel marked prog hidden rows  ; Δ{}
    ret call openOther cwd sel marked prog hidden rows  ; Δ{}
    ret call openText cwd sel marked prog hidden rows  ; Δ{}
    ret call paint "1;34" raw  ; Δ{} · makes String
    ret call readIntGo s 0 0  ; Δ{} · makes Maybe$Int
    ret call runPaste cwd marked prog  ; Δ{}
    ret call wordsFrom s _t2 n  ; Δ{} · makes List$String
    ret call wordsStep s i n  ; Δ{} · makes List$String
    ret comp  ; Δ{}
    ret con Just acc  ; Δ{} · makes Maybe$Int
    ret con Nil  ; Δ{} · makes List$String
    ret con Nil  ; Δ{} · makes List$String
    ret con Nothing  ; Δ{} · makes Maybe$Int
    ret i  ; Δ{}
    ret if _t1 then
    ret if _t1 then
    ret if _t2 then
    ret if _t2 then
    ret if _t2 then
    ret if _t2 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t4 then
    ret if _t6 then
    ret if _t6 then
    ret k  ; Δ{k} · moves{k}
    ret n  ; Δ{}
    ret rtcall axion_strcat a b  ; Δ{} · makes String
    ret rtcall axion_substr 0 _t2 s  ; Δ{} · makes String
    ret rtcall axion_substr 0 _t3 s  ; Δ{} · makes String
    ret rtcall axion_substr 0 k s  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 s  ; Δ{} · makes String
    ret s  ; Δ{}
    ret sel  ; Δ{}
    ret v  ; Δ{v} · moves{v}
    ret v  ; Δ{v} · moves{v}
    ret y  ; Δ{}
    ret y  ; Δ{}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t3}
  ; Δ{_t8}
  ; Δ{_t8}
  ; Δ{e v}
  ; Δ{fav}
  ; Δ{k}
  ; Δ{k}
  ; Δ{v}
  ; Δ{v}
  ; Δ{y ys}
  ; Δ{y ys}
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
  drop _t0 : String
  drop _t1 : List$String
  drop _t1 : List$String
  drop _t1 : List$String
  drop _t1 : List$String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t10 : String
  drop _t13 : String
  drop _t14 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
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
  drop _t5 : String
  drop _t5 : String
  drop _t5 : String
  drop _t6 : String
  drop _t6 : String
  drop _t7 : String
  drop _t7 : String
  drop _t8 : String
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
  let _d1000000 = call </> cwd _t0  ; Δ{_t0} · makes String
  let _d1000000 = call bnGo _t1  ; Δ{_t1} · makes String
  let _d1000000 = call elemBy$String p _t0  ; Δ{_t0}
  let _d1000000 = call gotoDir cwd _t0 sel marked prog hidden rows  ; Δ{_t0}
  let _d1000000 = call joinPaths cwd _t0  ; Δ{_t0} · makes String
  let _d1000000 = call length _t0  ; Δ{_t0}
  let _d1000000 = call length _t1  ; Δ{_t1}
  let _d1000000 = call lines _t1  ; Δ{_t1} · makes List$String
  let _d1000000 = call loop _t0 0 marked prog hidden rows  ; Δ{_t0}
  let _d1000000 = call loop _t0 0 marked prog hidden rows  ; Δ{_t0}
  let _d1000000 = call maybe d _t0 m  ; Δ{_t0}
  let _d1000000 = call pick 0 _t0  ; Δ{_t0} · makes String
  let _d1000000 = call qlGo _t1  ; Δ{_t1} · makes String
  let _d1000000 = call stripSlash _t1  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_strcat " [" _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat "'" _t2  ; Δ{_t2} · makes String
  let _d1000000 = rtcall axion_strcat "(" _t5  ; Δ{_t5} · makes String
  let _d1000000 = rtcall axion_strcat "/tmp/fff-bulk-" _t0  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/fff/fff.d"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.local/share/fff/trash"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t14  ; Δ{_t0 _t14} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t5  ; Δ{_t0 _t5} · makes String
  let _d1000000 = rtcall axion_strcat _t1 _t2  ; Δ{_t2} · makes String
  let _d1000000 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t3 _t10  ; Δ{_t10 _t3} · makes String
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = + sel 1  ; Δ{}
  let _t0 = - 0 1  ; Δ{}
  let _t0 = - 0 1  ; Δ{}
  let _t0 = - j i  ; Δ{}
  let _t0 = - j i  ; Δ{}
  let _t0 = - rows 1  ; Δ{}
  let _t0 = - rows 3  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < k 0  ; Δ{}
  let _t0 = < k 0  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == c 32  ; Δ{}
  let _t0 = == hidden 1  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = > i lim  ; Δ{}
  let _t0 = call <=$Int total mx  ; Δ{}
  let _t0 = call >=$Int c 48  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call baseNames marked  ; Δ{} · makes String
  let _t0 = call cdFile 0  ; Δ{} · makes String
  let _t0 = call cmdLine "/" rows cwd  ; Δ{} · makes String
  let _t0 = call cmdLine "go to dir: " rows cwd  ; Δ{} · makes String
  let _t0 = call cmdLine "mkdir: " rows cwd  ; Δ{} · makes String
  let _t0 = call cmdLine "mkfile: " rows cwd  ; Δ{} · makes String
  let _t0 = call csi "2J"  ; Δ{} · makes String
  let _t0 = call csi "?1049h"  ; Δ{} · makes String
  let _t0 = call csi "?25h"  ; Δ{} · makes String
  let _t0 = call csi "K"  ; Δ{} · makes String
  let _t0 = call entriesRaw cwd hidden  ; Δ{} · makes List$String
  let _t0 = call entriesRaw cwd hidden  ; Δ{} · makes List$String
  let _t0 = call entriesRaw cwd hidden  ; Δ{} · makes List$String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "OLDPWD" "."  ; Δ{} · makes String
  let _t0 = call esc  ; Δ{} · makes String
  let _t0 = call hasSuffix "/" raw  ; Δ{}
  let _t0 = call hasSuffix "/" s  ; Δ{}
  let _t0 = call homeClear  ; Δ{} · makes String
  let _t0 = call lines m  ; Δ{} · makes List$String
  let _t0 = call lines m  ; Δ{} · makes List$String
  let _t0 = call lines m  ; Δ{} · makes List$String
  let _t0 = call lines m  ; Δ{} · makes List$String
  let _t0 = call lsCmd cwd hidden  ; Δ{} · makes String
  let _t0 = call markCount marked  ; Δ{}
  let _t0 = call markCount marked  ; Δ{}
  let _t0 = call markCount marked  ; Δ{}
  let _t0 = call markCount marked  ; Δ{}
  let _t0 = call markedHas m p  ; Δ{}
  let _t0 = call markedHas marked full  ; Δ{}
  let _t0 = call render cwd sel marked prog hidden rows  ; Δ{} · makes String
  let _t0 = call resetSeq  ; Δ{} · makes String
  let _t0 = call resetSeq  ; Δ{} · makes String
  let _t0 = call resetSeq  ; Δ{} · makes String
  let _t0 = call selName cwd hidden sel  ; Δ{} · makes String
  let _t0 = call selName cwd hidden sel  ; Δ{} · makes String
  let _t0 = call selPath cwd hidden sel  ; Δ{} · makes String
  let _t0 = call selPath cwd hidden sel  ; Δ{} · makes String
  let _t0 = call selPath cwd hidden sel  ; Δ{} · makes String
  let _t0 = call selPath cwd hidden sel  ; Δ{} · makes String
  let _t0 = call shQuote p  ; Δ{} · makes String
  let _t0 = call shQuote p  ; Δ{} · makes String
  let _t0 = call shQuote p  ; Δ{} · makes String
  let _t0 = call words s  ; Δ{} · makes List$String
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = rtcall axion_rand_hex 8  ; Δ{} · makes String
  let _t0 = rtcall axion_run "stty size"  ; Δ{} · makes String
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_cmp a b  ; Δ{}
  let _t0 = rtcall axion_str_cmp b "A"  ; Δ{}
  let _t0 = rtcall axion_str_cmp k ""  ; Δ{}
  let _t0 = rtcall axion_str_cmp key "j"  ; Δ{}
  let _t0 = rtcall axion_str_cmp prog "trash"  ; Δ{}
  let _t0 = rtcall axion_str_cmp x y  ; Δ{}
  let _t0 = rtcall axion_str_len a  ; Δ{}
  let _t0 = rtcall axion_str_len comp  ; Δ{}
  let _t0 = rtcall axion_str_len k  ; Δ{k}
  let _t0 = rtcall axion_str_len nm  ; Δ{}
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
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len v  ; Δ{v}
  let _t0 = rtcall axion_str_len v  ; Δ{v}
  let _t0 = rtcall axion_strcat "FFF_FAV" key  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat c "m"  ; Δ{} · makes String
  let _t0 = showInt rows  ; Δ{} · makes String
  let _t1 = < _t0 1  ; Δ{}
  let _t1 = == _t0 0  ; Δ{k}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == i sel  ; Δ{_t0}
  let _t1 = > _t0 0  ; Δ{v}
  let _t1 = > _t0 0  ; Δ{v}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = call <=$Int c 57  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call csi "2J"  ; Δ{_t0} · makes String
  let _t1 = call csi "?25l"  ; Δ{_t0} · makes String
  let _t1 = call csi "H"  ; Δ{_t0} · makes String
  let _t1 = call csi _t0  ; Δ{_t0} · makes String
  let _t1 = call entriesRaw cwd hidden  ; Δ{_t0} · makes List$String
  let _t1 = call filter$$nonEmpty _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = call filter$$nonEmpty _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = call filter$$nonEmpty _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = call firstWord _t0  ; Δ{_t0} · makes String
  let _t1 = call hasSuffix "/" a  ; Δ{}
  let _t1 = call isDirPath _t0  ; Δ{_t0}
  let _t1 = call isExecPath _t0  ; Δ{_t0}
  let _t1 = call isSpace _t0  ; Δ{}
  let _t1 = call isTextPath _t0  ; Δ{_t0}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = call pick sel _t0  ; Δ{_t0} · makes String
  let _t1 = call shEsc s 0 _t0  ; Δ{} · makes String
  let _t1 = call shQuote _t0  ; Δ{_t0} · makes String
  let _t1 = if _t0 then
  let _t1 = putStr _t0  ; Δ{_t0}
  let _t1 = putStr _t0  ; Δ{_t0}
  let _t1 = putStr _t0  ; Δ{_t0}
  let _t1 = putStr _t0  ; Δ{_t0}
  let _t1 = rtcall axion_run _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len key  ; Δ{fav}
  let _t1 = rtcall axion_str_len q  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_strcat "[" s  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "test -d " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "test -x " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " 2>/dev/null | grep -q '^text/\\|^inode/x-empty'"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " to: "  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "/.cache/fff"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 ";1H"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat cwd "\n"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t1 = rtcall axion_write_file tmp _t0  ; Δ{_t0}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t10 = call && _t4 _t9  ; Δ{fav}
  let _t10 = call paint "7" _t9  ; Δ{_t3 _t9} · makes String
  let _t11 = call && _t2 _t10  ; Δ{fav}
  let _t13 = if _t1 then
  let _t14 = rtcall axion_strcat _t13 "\n"  ; Δ{_t0} · makes String
  let _t2 = + j 1  ; Δ{_t1}
  let _t2 = + start mx  ; Δ{_t0 _t1}
  let _t2 = - _t0 _t1  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = > _t1 0  ; Δ{_t0}
  let _t2 = > _t1 0  ; Δ{_t0}
  let _t2 = > _t1 0  ; Δ{_t0}
  let _t2 = > _t1 0  ; Δ{fav}
  let _t2 = call csi "2J"  ; Δ{_t0 _t1} · makes String
  let _t2 = call csi "?1049l"  ; Δ{_t0 _t1} · makes String
  let _t2 = call csi "m"  ; Δ{_t1} · makes String
  let _t2 = call csi _t1  ; Δ{_t1} · makes String
  let _t2 = call isDirPath nm  ; Δ{}
  let _t2 = call readInt _t1  ; Δ{_t1} · makes Maybe$Int
  let _t2 = call shQuote cwd  ; Δ{} · makes String
  let _t2 = call wordsFrom s j n  ; Δ{_t1} · makes List$String
  let _t2 = if _t1 then
  let _t2 = if _t1 then
  let _t2 = rtcall axion_mkdir_p _t1  ; Δ{_t1}
  let _t2 = rtcall axion_strcat "file -bL --mime-type " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "rename " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t1 " >/dev/null 2>&1 &"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t1 "'"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t1 ";1H"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat prog ")"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_system _t1  ; Δ{_t1}
  let _t2 = rtcall axion_system _t1  ; Δ{_t1}
  let _t2 = rtcall axion_write_file _t0 _t1  ; Δ{_t0 _t1}
  let _t2 = showInt total  ; Δ{_t1} · makes String
  let _t3 = call && _t1 _t2  ; Δ{}
  let _t3 = call cmdLine _t2 rows cwd  ; Δ{_t2} · makes String
  let _t3 = call csi "?25h"  ; Δ{_t2} · makes String
  let _t3 = call csi _t2  ; Δ{_t2} · makes String
  let _t3 = call drawRows _t1 0 start _t2 sel marked cwd  ; Δ{_t0 _t1} · makes String
  let _t3 = call linesFrom s _t2 n  ; Δ{_t1} · makes List$String
  let _t3 = call selPath cwd hidden sel  ; Δ{} · makes String
  let _t3 = if _t1 then
  let _t3 = rtcall axion_str_at 0 key  ; Δ{fav}
  let _t3 = rtcall axion_strcat "] (" _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_strcat "nohup xdg-open " _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_strcat _t1 _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_strcat _t1 _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_strcat _t2 ")"  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_strcat s _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_system _t2  ; Δ{_t2}
  let _t4 = call >=$Int _t3 49  ; Δ{fav}
  let _t4 = call csi "K"  ; Δ{_t2 _t3} · makes String
  let _t4 = call nEntries cwd hidden  ; Δ{_t3}
  let _t4 = call shQuote _t3  ; Δ{_t3} · makes String
  let _t4 = call statusLine cwd sel marked prog hidden rows  ; Δ{_t0 _t3} · makes String
  let _t4 = if _t2 then
  let _t4 = if _t2 then
  let _t4 = if _t2 then
  let _t4 = rtcall axion_str_len _t3  ; Δ{_t3}
  let _t4 = rtcall axion_strcat "/" _t3  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_system _t3  ; Δ{_t3}
  let _t5 = > _t4 0  ; Δ{_t3}
  let _t5 = call posStr sel _t4  ; Δ{_t3} · makes String
  let _t5 = rtcall axion_str_at 0 key  ; Δ{fav}
  let _t5 = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
  let _t5 = rtcall axion_strcat _t2 _t4  ; Δ{_t4} · makes String
  let _t5 = rtcall axion_strcat _t3 _t4  ; Δ{_t0 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat prompt acc  ; Δ{_t2 _t3 _t4} · makes String
  let _t6 = call <=$Int _t5 57  ; Δ{fav}
  let _t6 = call markSeg marked prog  ; Δ{_t3 _t5} · makes String
  let _t6 = rtcall axion_strcat _t4 _t5  ; Δ{_t2 _t3 _t4 _t5} · makes String
  let _t6 = rtcall axion_system _t5  ; Δ{_t5}
  let _t7 = rtcall axion_str_len fav  ; Δ{fav}
  let _t7 = rtcall axion_strcat " " cwd  ; Δ{_t3 _t5 _t6} · makes String
  let _t7 = rtcall axion_strcat _t3 _t6  ; Δ{_t2 _t3 _t6} · makes String
  let _t8 = > _t7 0  ; Δ{fav}
  let _t8 = if _t5 then
  let _t8 = rtcall axion_strcat _t2 _t7  ; Δ{_t2 _t7} · makes String
  let _t8 = rtcall axion_strcat _t6 _t7  ; Δ{_t3 _t5 _t6 _t7} · makes String
  let _t9 = call && _t6 _t8  ; Δ{fav}
  let _t9 = putStr _t8  ; Δ{_t8}
  let _t9 = rtcall axion_strcat _t5 _t8  ; Δ{_t3 _t5 _t8} · makes String
  let fav = rtcall axion_getenv _t0  ; Δ{_t0} · makes String
  let k = rtcall axion_read_key 0  ; Δ{} · makes String
  let mx = call maxItems rows  ; Δ{}
  let start = call viewStart sel total mx  ; Δ{}
  let total = call nEntries cwd hidden  ; Δ{}
  let v = rtcall axion_getenv "VISUAL"  ; Δ{} · makes String
  let v = rtcall axion_getenv name  ; Δ{} · makes String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret == _t2 0  ; Δ{}
  ret == _t2 0  ; Δ{}
  ret == _t3 0  ; Δ{}
  ret > _t0 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
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
  ret call && _t0 _t1  ; Δ{}
  ret call baseAfter s _t1  ; Δ{} · makes String
  ret call cmdGo prompt rows cwd ""  ; Δ{} · makes String
  ret call dirBefore s _t1  ; Δ{} · makes String
  ret call fromMaybe 24 _t2  ; Δ{_t2} · moves{_t2}
  ret call infixGo q s 0 _t2  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call linesFrom s 0 _t0  ; Δ{} · makes List$String
  ret call loop cwd _t4 marked prog hidden rows  ; Δ{}
  ret call not _t1  ; Δ{}
  ret call wordsFrom s 0 _t0  ; Δ{} · makes List$String
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t2 of
  ret case _t2 of
  ret case _t2 of
  ret case _t3 of
  ret case _t4 of
  ret case _t4 of
  ret case _t4 of
  ret case _t6 of
  ret case _t8 of
  ret case _t9 of
  ret case m of
  ret case olds of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Cons _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes List$String
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
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t11 then
  ret if _t2 then
  ret if _t2 then
  ret if _t3 then
  ret if b then
  ret if x then
  ret if x then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_chr 27  ; Δ{} · makes String
  ret rtcall axion_substr 0 _t0 s  ; Δ{} · makes String
  ret x  ; Δ{}
&& x y  =
</> a b  =
<=$Int x y  =
>=$Int x y  =
allPaths cwd hidden  =
arrowKey b  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$Int _p  =
baseAfter s k  =
baseName s  =
baseNames m  =
bnGo xs  =
bulkApply olds news cwd  =
bulkRun cwd marked tmp  =
bulkTmp d  =
cdFile d  =
clampSel i n  =
cmdGo prompt rows cwd acc  =
cmdKey prompt rows cwd acc k  =
cmdLine prompt rows cwd  =
colorName raw  =
consLine s i n j  =
consWord s i n j  =
csi s  =
dirBefore s k  =
dirName s  =
doAttr cwd sel marked prog hidden rows  =
doBulk cwd sel marked prog hidden rows  =
doChmod cwd sel marked prog hidden rows  =
doGoDir cwd sel marked prog hidden rows  =
doMkdir cwd sel marked prog hidden rows  =
doMkfile cwd sel marked prog hidden rows  =
doPaste cwd sel marked prog hidden rows  =
doRename cwd sel marked prog hidden rows  =
doSearch cwd sel marked prog hidden rows  =
doShell cwd sel marked prog hidden rows  =
drawRows xs i start endIdx sel marked cwd  =
dropLast s  =
dup s  =
dupOrAcc comp acc  =
editorCmd d  =
elemBy$String x xs  =
entriesRaw cwd hidden  =
envOr name dflt  =
eq$String x y  =
esc  =
favOrIgnore cwd sel marked prog hidden rows key  =
filter$$neStr _cap0 xs  =
filter$$nonEmpty xs  =
findChar c s i n  =
firstPrefix xs q  =
firstWord s  =
fromMaybe d m  =
goHome marked prog hidden rows  =
goPrev marked prog hidden rows  =
gotoDir cwd nm sel marked prog hidden rows  =
hasInfix q s  =
hasPrefix p s  =
hasSuffix q s  =
homeClear  =
infixGo q s i lim  =
isDigit c  =
isDirPath p  =
isExecPath p  =
isSpace c  =
isTextPath p  =
joinPaths cwd xs  =
lam$0 [env ]x  =
lastIndex c s i best  =
le$Int x y  =
length xs  =
lines s  =
linesFrom s i n  =
loop cwd sel marked prog hidden rows  =
lsCmd cwd hidden  =
main  =
markChar marked full  =
markCount m  =
markInfo marked prog  =
markSeg marked prog  =
markToggle m p  =
markedHas m p  =
matchIndex xs q i dflt  =
maxItems rows  =
maybe d f m  =
nEntries cwd hidden  =
neStr a b  =
nonEmpty s  =
not b  =
open cwd sel marked prog hidden rows  =
openFile cwd sel marked prog hidden rows  =
openOther cwd sel marked prog hidden rows  =
openText cwd sel marked prog hidden rows  =
paint c s  =
pick i xs  =
posStr sel total  =
qlGo xs  =
quit cwd  =
quoteLines m  =
readInt s  =
readIntGo s i acc  =
readMainKey dummy  =
render cwd sel marked prog hidden rows  =
resetSeq  =
rowFor raw i sel marked cwd  =
runPaste cwd marked prog  =
selName cwd hidden sel  =
selPath cwd hidden sel  =
setupSeq  =
shEsc s i n  =
shQuote s  =
startDir a  =
statusLine cwd sel marked prog hidden rows  =
step cwd sel marked prog hidden rows key  =
stripSlash s  =
termRows dummy  =
trashDir d  =
unlines xs  =
viewStart sel total mx  =
wordEnd s i n  =
words s  =
wordsFrom s i n  =
wordsStep s i n  =
|| x y  =
