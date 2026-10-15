






























































































































































































































































                                                                            ret call favOrIgnore cwd sel marked prog hidden rows key  ; Δ{}
                                                                            ret call quit cwd  ; Δ{}
                                                                          else
                                                                          let _t109 = rtcall axion_str_cmp key ""  ; Δ{}
                                                                          let _t110 = == _t109 0  ; Δ{}
                                                                          ret call quit cwd  ; Δ{}
                                                                          ret if _t110 then
                                                                        else
                                                                        let _t107 = rtcall axion_str_cmp key "\u{1b}"  ; Δ{}
                                                                        let _t108 = == _t107 0  ; Δ{}
                                                                        ret call quit cwd  ; Δ{}
                                                                        ret if _t108 then
                                                                      drop _t103 : String
                                                                      else
                                                                      let _t103 = call readLastQ 0  ; Δ{} · makes String
                                                                      let _t104 = call searchPrev raw _t103 sel  ; Δ{_t103}
                                                                      let _t105 = rtcall axion_str_cmp key "q"  ; Δ{}
                                                                      let _t106 = == _t105 0  ; Δ{}
                                                                      ret call loop cwd _t104 marked prog hidden rows cols raw  ; Δ{}
                                                                      ret if _t106 then
                                                                    drop _t99 : String
                                                                    else
                                                                    let _t100 = call searchNext raw _t99 sel  ; Δ{_t99}
                                                                    let _t101 = rtcall axion_str_cmp key ","  ; Δ{}
                                                                    let _t102 = == _t101 0  ; Δ{}
                                                                    let _t99 = call readLastQ 0  ; Δ{} · makes String
                                                                    ret call loop cwd _t100 marked prog hidden rows cols raw  ; Δ{}
                                                                    ret if _t102 then
                                                                  else
                                                                  let _t97 = rtcall axion_str_cmp key ";"  ; Δ{}
                                                                  let _t98 = == _t97 0  ; Δ{}
                                                                  ret call doRestore cwd sel marked prog hidden rows  ; Δ{}
                                                                  ret if _t98 then
                                                                else
                                                                let _t95 = rtcall axion_str_cmp key "u"  ; Δ{}
                                                                let _t96 = == _t95 0  ; Δ{}
                                                                ret call doFilter cwd sel marked prog hidden rows  ; Δ{}
                                                                ret if _t96 then
                                                              else
                                                              let _t93 = rtcall axion_str_cmp key "F"  ; Δ{}
                                                              let _t94 = == _t93 0  ; Δ{}
                                                              ret call doSort cwd sel marked prog hidden rows  ; Δ{}
                                                              ret if _t94 then
                                                            else
                                                            let _t91 = rtcall axion_str_cmp key "o"  ; Δ{}
                                                            let _t92 = == _t91 0  ; Δ{}
                                                            ret call doShell cwd sel marked prog hidden rows  ; Δ{}
                                                            ret if _t92 then
                                                          else
                                                          let _t89 = rtcall axion_str_cmp key "!"  ; Δ{}
                                                          let _t90 = == _t89 0  ; Δ{}
                                                          ret call doBulk cwd sel marked prog hidden rows  ; Δ{}
                                                          ret if _t90 then
                                                        else
                                                        let _t87 = rtcall axion_str_cmp key "b"  ; Δ{}
                                                        let _t88 = == _t87 0  ; Δ{}
                                                        ret call doPaste cwd sel marked prog hidden rows  ; Δ{}
                                                        ret if _t88 then
                                                      else
                                                      let _t85 = rtcall axion_str_cmp key "p"  ; Δ{}
                                                      let _t86 = == _t85 0  ; Δ{}
                                                      ret call loop cwd sel "" "" hidden rows cols raw  ; Δ{}
                                                      ret if _t86 then
                                                    drop _t82 : String
                                                    else
                                                    let _d1000008 = call loop cwd sel _t82 "trash" hidden rows cols raw  ; Δ{_t82}
                                                    let _t82 = call allPathsOf cwd raw  ; Δ{} · makes String
                                                    let _t83 = rtcall axion_str_cmp key "c"  ; Δ{}
                                                    let _t84 = == _t83 0  ; Δ{}
                                                    ret _d1000008  ; Δ{}
                                                    ret if _t84 then
                                                  drop _t79 : String
                                                  else
                                                  let _d1000007 = call loop cwd sel _t79 "ln -s" hidden rows cols raw  ; Δ{_t79}
                                                  let _t79 = call allPathsOf cwd raw  ; Δ{} · makes String
                                                  let _t80 = rtcall axion_str_cmp key "D"  ; Δ{}
                                                  let _t81 = == _t80 0  ; Δ{}
                                                  ret _d1000007  ; Δ{}
                                                  ret if _t81 then
                                                drop _t76 : String
                                                else
                                                let _d1000006 = call loop cwd sel _t76 "mv -i" hidden rows cols raw  ; Δ{_t76}
                                                let _t76 = call allPathsOf cwd raw  ; Δ{} · makes String
                                                let _t77 = rtcall axion_str_cmp key "S"  ; Δ{}
                                                let _t78 = == _t77 0  ; Δ{}
                                                ret _d1000006  ; Δ{}
                                                ret if _t78 then
                                              drop _t73 : String
                                              else
                                              let _d1000005 = call loop cwd sel _t73 "cp -iR" hidden rows cols raw  ; Δ{_t73}
                                              let _t73 = call allPathsOf cwd raw  ; Δ{} · makes String
                                              let _t74 = rtcall axion_str_cmp key "M"  ; Δ{}
                                              let _t75 = == _t74 0  ; Δ{}
                                              ret _d1000005  ; Δ{}
                                              ret if _t75 then
                                            drop _t69 : String
                                            drop _t70 : String
                                            else
                                            let _d1000004 = call loop cwd sel _t70 "trash" hidden rows cols raw  ; Δ{_t70}
                                            let _t69 = call selPathOf cwd raw sel  ; Δ{} · makes String
                                            let _t70 = call markToggle marked _t69  ; Δ{_t69} · makes String
                                            let _t71 = rtcall axion_str_cmp key "Y"  ; Δ{}
                                            let _t72 = == _t71 0  ; Δ{}
                                            ret _d1000004  ; Δ{}
                                            ret if _t72 then
                                          drop _t65 : String
                                          drop _t66 : String
                                          else
                                          let _d1000003 = call loop cwd sel _t66 "ln -s" hidden rows cols raw  ; Δ{_t66}
                                          let _t65 = call selPathOf cwd raw sel  ; Δ{} · makes String
                                          let _t66 = call markToggle marked _t65  ; Δ{_t65} · makes String
                                          let _t67 = rtcall axion_str_cmp key "d"  ; Δ{}
                                          let _t68 = == _t67 0  ; Δ{}
                                          ret _d1000003  ; Δ{}
                                          ret if _t68 then
                                        drop _t61 : String
                                        drop _t62 : String
                                        else
                                        let _d1000002 = call loop cwd sel _t62 "mv -i" hidden rows cols raw  ; Δ{_t62}
                                        let _t61 = call selPathOf cwd raw sel  ; Δ{} · makes String
                                        let _t62 = call markToggle marked _t61  ; Δ{_t61} · makes String
                                        let _t63 = rtcall axion_str_cmp key "s"  ; Δ{}
                                        let _t64 = == _t63 0  ; Δ{}
                                        ret _d1000002  ; Δ{}
                                        ret if _t64 then
                                      drop _t57 : String
                                      drop _t58 : String
                                      else
                                      let _d1000001 = call loop cwd sel _t58 "cp -iR" hidden rows cols raw  ; Δ{_t58}
                                      let _t57 = call selPathOf cwd raw sel  ; Δ{} · makes String
                                      let _t58 = call markToggle marked _t57  ; Δ{_t57} · makes String
                                      let _t59 = rtcall axion_str_cmp key "m"  ; Δ{}
                                      let _t60 = == _t59 0  ; Δ{}
                                      ret _d1000001  ; Δ{}
                                      ret if _t60 then
                                    else
                                    let _t55 = rtcall axion_str_cmp key "y"  ; Δ{}
                                    let _t56 = == _t55 0  ; Δ{}
                                    ret call doChmod cwd sel marked prog hidden rows  ; Δ{}
                                    ret if _t56 then
                                  else
                                  let _t53 = rtcall axion_str_cmp key "X"  ; Δ{}
                                  let _t54 = == _t53 0  ; Δ{}
                                  ret call doAttr cwd sel marked prog hidden rows  ; Δ{}
                                  ret if _t54 then
                                else
                                let _t51 = rtcall axion_str_cmp key "x"  ; Δ{}
                                let _t52 = == _t51 0  ; Δ{}
                                ret call doRename cwd sel marked prog hidden rows  ; Δ{}
                                ret if _t52 then
                              else
                              let _t49 = rtcall axion_str_cmp key "r"  ; Δ{}
                              let _t50 = == _t49 0  ; Δ{}
                              ret call doMkfile cwd sel marked prog hidden rows  ; Δ{}
                              ret if _t50 then
                            else
                            let _t47 = rtcall axion_str_cmp key "f"  ; Δ{}
                            let _t48 = == _t47 0  ; Δ{}
                            ret call doMkdir cwd sel marked prog hidden rows  ; Δ{}
                            ret if _t48 then
                          else
                          let _t45 = rtcall axion_str_cmp key "n"  ; Δ{}
                          let _t46 = == _t45 0  ; Δ{}
                          ret call doSearch cwd sel marked prog hidden rows cols raw  ; Δ{}
                          ret if _t46 then
                        else
                        let _t43 = rtcall axion_str_cmp key "/"  ; Δ{}
                        let _t44 = == _t43 0  ; Δ{}
                        ret call doGoDir cwd sel marked prog hidden rows  ; Δ{}
                        ret if _t44 then
                      drop _t16 : String
                      drop _t17 : String
                      drop _t8 : String
                      else
                      let _d1000000 = call reloop _t17 0 "" "" 0 _t18  ; Δ{_t17}
                      let _t16 = rtcall axion_getarg 0  ; Δ{} · makes String
                      let _t17 = call startDir _t16  ; Δ{_t16} · makes String
                      let _t18 = call termRows 0  ; Δ{_t17}
                      let _t41 = rtcall axion_str_cmp key ":"  ; Δ{}
                      let _t42 = == _t41 0  ; Δ{}
                      ret _d1000000  ; Δ{}
                      ret call goPrev marked prog hidden rows  ; Δ{}
                      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
                      ret if _t42 then
                      ret rtcall axion_unlink tmp  ; Δ{}
                    _ ->
                    _ ->
                    _ ->
                    else
                    let _t39 = rtcall axion_str_cmp key "-"  ; Δ{}
                    let _t40 = == _t39 0  ; Δ{}
                    ret call goHome marked prog hidden rows  ; Δ{}
                    ret if _t40 then
                  drop _t14 : String
                  drop _t15 : String
                  drop _t33 : List$String
                  drop _t9 : String
                  else
                  let _t10 = putStr _t9  ; Δ{_t8 _t9}
                  let _t14 = call setupSeq  ; Δ{} · makes String
                  let _t15 = call setupSeq  ; Δ{} · makes String
                  let _t15 = putStr _t14  ; Δ{_t14}
                  let _t16 = putStr _t15  ; Δ{_t15}
                  let _t33 = call lines raw  ; Δ{} · makes List$String
                  let _t34 = call length _t33  ; Δ{_t33}
                  let _t35 = call clampSel sel _t34  ; Δ{}
                  let _t36 = call termRows 0  ; Δ{}
                  let _t37 = rtcall axion_str_cmp key "~"  ; Δ{}
                  let _t38 = == _t37 0  ; Δ{}
                  let _t9 = call setupSeq  ; Δ{_t8} · makes String
                  ret 0  ; Δ{}
                  ret 1  ; Δ{}
                  ret call reloop cwd _t35 marked prog hidden _t36  ; Δ{}
                  ret case _t10 of
                  ret case _t15 of
                  ret case _t16 of
                  ret if _t38 then
                _ ->
                _ ->
                _ ->
                else
                else
                let _t29 = == hidden 1  ; Δ{}
                let _t30 = if _t29 then
                let _t31 = rtcall axion_str_cmp key "e"  ; Δ{}
                let _t32 = == _t31 0  ; Δ{}
                ret 1  ; Δ{}
                ret call hasInfix "compress" m  ; Δ{}
                ret call reloop cwd 0 marked prog _t30 rows  ; Δ{}
                ret if _t32 then
              drop _t10 : List$String
              drop _t11 : String
              drop _t13 : List$String
              drop _t19 : String
              drop _t20 : String
              drop _t21 : String
              drop _t22 : String
              drop _t23 : String
              drop _t24 : String
              drop _t25 : List$String
              drop _t26 : String
              else
              else
              let _d1000000 = call reloop _t26 0 marked prog hidden rows  ; Δ{_t26}
              let _d1000002 = call drawLines _t25 1 px pw ph  ; Δ{_t25} · makes String
              let _t10 = call filter$$nonEmpty _t9  ; Δ{_t9} · moves{_t9} · makes List$String
              let _t11 = rtcall axion_read_file tmp  ; Δ{_t10} · makes String
              let _t12 = call lines _t11  ; Δ{_t10 _t11} · makes List$String
              let _t13 = call filter$$nonEmpty _t12  ; Δ{_t10 _t12} · moves{_t12} · makes List$String
              let _t13 = rtcall axion_system "test -t 0 && stty -echo -icanon 2>/dev/null"  ; Δ{}
              let _t14 = call bulkApply _t10 _t13 cwd  ; Δ{_t10 _t13}
              let _t19 = call shQuote path  ; Δ{} · makes String
              let _t20 = call scrollPipe poff ph  ; Δ{_t19} · makes String
              let _t21 = rtcall axion_strcat " 2>/dev/null" _t20  ; Δ{_t19 _t20} · makes String
              let _t22 = rtcall axion_strcat _t19 _t21  ; Δ{_t19 _t21} · makes String
              let _t23 = rtcall axion_strcat "file -bL -- " _t22  ; Δ{_t22} · makes String
              let _t24 = rtcall axion_run _t23  ; Δ{_t23} · makes String
              let _t25 = call lines _t24  ; Δ{_t24} · makes List$String
              let _t26 = call parentDir cwd  ; Δ{} · makes String
              let _t27 = rtcall axion_str_cmp key "."  ; Δ{}
              let _t28 = == _t27 0  ; Δ{}
              let _t6 = call hasInfix "xz" m  ; Δ{}
              let _t8 = rtcall axion_read_key 0  ; Δ{} · makes String
              let _t9 = call lines marked  ; Δ{} · makes List$String
              ret ""  ; Δ{}
              ret "1;32"  ; Δ{}
              ret 1  ; Δ{}
              ret 1  ; Δ{}
              ret _d1000000  ; Δ{}
              ret _d1000002  ; Δ{_d1000002} · moves{_d1000002}
              ret call bulkApply os ns cwd  ; Δ{}
              ret call hasPrefix "inode/x-empty" mime  ; Δ{}
              ret call reloop cwd sel marked prog hidden rows  ; Δ{}
              ret call reloop cwd sel marked prog hidden rows  ; Δ{}
              ret call textPreview path px pw ph poff  ; Δ{} · makes String
              ret call waitKey cwd sel marked prog hidden rows cols raw poff  ; Δ{}
              ret case _t13 of
              ret case _t14 of
              ret case _t8 of
              ret if _t28 then
              ret if _t6 then
            _ ->
            _ ->
            _ ->
            _ ->
            _ ->
            _ ->
            _ ->
            drop _t10 : List$String
            drop _t12 : String
            drop _t13 : String
            drop _t14 : String
            drop _t15 : List$String
            drop _t15 : String
            drop _t16 : List$String
            drop _t3 : String
            else
            else
            else
            else
            else
            let _d1000000 = rtcall axion_rename o _t3  ; Δ{_t3}
            let _d1000001 = call drawLines _t16 1 px pw ph  ; Δ{_t16} · makes String
            let _t10 = call codeExts  ; Δ{} · makes List$String
            let _t11 = call elemBy$String e _t10  ; Δ{_t10}
            let _t12 = call archiveList path  ; Δ{} · makes String
            let _t13 = call scrollPipe poff ph  ; Δ{_t12} · makes String
            let _t14 = rtcall axion_strcat _t12 _t13  ; Δ{_t12 _t13} · makes String
            let _t15 = call entriesRaw cwd 1  ; Δ{} · makes List$String
            let _t15 = rtcall axion_run _t14  ; Δ{_t14} · makes String
            let _t16 = call firstPrefix _t15 acc  ; Δ{_t15} · makes String
            let _t16 = call lines _t15  ; Δ{_t15} · makes List$String
            let _t17 = call dupOrAcc _t16 acc  ; Δ{_t16} · moves{_t16} · makes String
            let _t17 = call hasPrefix "text/" mime  ; Δ{}
            let _t18 = if _t17 then
            let _t18 = rtcall axion_strcat acc k  ; Δ{} · makes String
            let _t24 = rtcall axion_str_cmp key "h"  ; Δ{}
            let _t25 = == _t24 0  ; Δ{}
            let _t3 = call </> cwd n  ; Δ{} · makes String
            let _t5 = call hasInfix "bzip" m  ; Δ{}
            ret "0;33"  ; Δ{}
            ret 0  ; Δ{}
            ret 1  ; Δ{}
            ret _d1000000  ; Δ{}
            ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
            ret call cmdGo prompt rows cwd _t17  ; Δ{_t17} · moves{_t17} · makes String
            ret call cmdGo prompt rows cwd _t18  ; Δ{_t18} · moves{_t18} · makes String
            ret call open cwd sel marked prog hidden rows raw  ; Δ{}
            ret if _t11 then
            ret if _t18 then
            ret if _t25 then
            ret if _t5 then
          drop _t0 : String
          drop _t11 : String
          drop _t11 : String
          drop _t16 : List$String
          drop _t16 : String
          drop _t17 : String
          drop _t19 : List$String
          drop _t4 : String
          drop _t4 : String
          drop _t5 : String
          drop _t6 : String
          drop _t7 : String
          drop _t7 : String
          drop _t8 : List$String
          drop _t8 : String
          drop _t8 : String
          else
          else
          else
          else
          else
          else
          let _d1000000 = call searchKey cwd sel marked prog hidden rows cols raw osel acc _t7  ; Δ{_t7}
          let _d1000000 = call searchLoop cwd sel marked prog hidden rows cols raw osel _t16  ; Δ{_t16}
          let _d1000000 = putStr _t4  ; Δ{_t4}
          let _d1000001 = call searchLoop cwd sel marked prog hidden rows cols raw osel _t17  ; Δ{_t17}
          let _t0 = call </> cwd n  ; Δ{} · makes String
          let _t1 = rtcall axion_str_cmp o _t0  ; Δ{_t0}
          let _t10 = rtcall axion_str_at 0 k  ; Δ{}
          let _t11 = call isArchiveMime mime  ; Δ{}
          let _t11 = call queryCell 0  ; Δ{} · makes String
          let _t12 = call dropLast acc  ; Δ{} · makes String
          let _t12 = rtcall axion_system _t11  ; Δ{_t11}
          let _t13 = rtcall axion_str_at 0 k  ; Δ{}
          let _t14 = == _t13 9  ; Δ{}
          let _t14 = rtcall axion_str_at 0 k  ; Δ{}
          let _t16 = call dropLast acc  ; Δ{} · makes String
          let _t16 = call lines raw  ; Δ{} · makes List$String
          let _t17 = call length _t16  ; Δ{_t16}
          let _t17 = rtcall axion_strcat acc k  ; Δ{} · makes String
          let _t18 = - _t17 1  ; Δ{}
          let _t19 = call lines raw  ; Δ{} · makes List$String
          let _t2 = == _t1 0  ; Δ{}
          let _t20 = call length _t19  ; Δ{_t19}
          let _t21 = call clampSel _t18 _t20  ; Δ{}
          let _t22 = rtcall axion_str_cmp key "l"  ; Δ{}
          let _t23 = == _t22 0  ; Δ{}
          let _t4 = call editorCmd 0  ; Δ{} · makes String
          let _t4 = call hasInfix "gzip" m  ; Δ{}
          let _t4 = call resetSeq  ; Δ{} · makes String
          let _t4 = if _t2 then
          let _t5 = call shQuote tmp  ; Δ{_t4} · makes String
          let _t6 = call prefetch cwd sel rows raw cols  ; Δ{}
          let _t6 = rtcall axion_strcat " " _t5  ; Δ{_t4 _t5} · makes String
          let _t7 = putStr "\n[any key]"  ; Δ{}
          let _t7 = rtcall axion_read_key 0  ; Δ{} · makes String
          let _t7 = rtcall axion_strcat _t4 _t6  ; Δ{_t4 _t6} · makes String
          let _t8 = call docExts  ; Δ{} · makes List$String
          let _t8 = call setupSeq  ; Δ{} · makes String
          let _t8 = call setupSeq  ; Δ{} · makes String
          let _t8 = rtcall axion_system _t7  ; Δ{_t7}
          let _t9 = call elemBy$String e _t8  ; Δ{_t8}
          let _t9 = putStr _t8  ; Δ{_t8}
          let _t9 = putStr _t8  ; Δ{_t8}
          ret ""  ; Δ{}
          ret "1;31"  ; Δ{}
          ret "h"  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret == _t10 8  ; Δ{}
          ret == _t14 8  ; Δ{}
          ret _d1000000  ; Δ{}
          ret _d1000000  ; Δ{}
          ret _d1000000  ; Δ{}
          ret _d1000001  ; Δ{}
          ret call cmdGo prompt rows cwd _t12  ; Δ{_t12} · moves{_t12} · makes String
          ret call loop cwd _t21 marked prog hidden rows cols raw  ; Δ{}
          ret call pixHeader "[pdf] " path mime px pw ph  ; Δ{} · makes String
          ret case _t12 of
          ret case _t4 of
          ret case _t6 of
          ret case _t7 of
          ret case _t8 of
          ret case _t9 of
          ret case _t9 of
          ret if _t11 then
          ret if _t14 then
          ret if _t23 then
          ret if _t4 then
          ret if _t9 then
        Cons n ns ->
        Nil ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        drop _t1 : String
        drop _t10 : String
        drop _t11 : String
        drop _t11 : String
        drop _t12 : String
        drop _t13 : String
        drop _t2 : String
        drop _t2 : String
        drop _t2 : String
        drop _t2 : String
        drop _t3 : String
        drop _t3 : String
        drop _t4 : String
        drop _t4 : String
        drop _t4 : String
        drop _t5 : String
        drop _t5 : String
        drop _t5 : String
        drop _t6 : List$String
        drop _t6 : String
        drop _t6 : String
        drop _t7 : String
        drop _t7 : String
        drop _t8 : String
        drop _t8 : String
        drop _t9 : String
        drop _t9 : String
        drop _t9 : String
        drop b2 : String
        drop k : String
        drop k : String
        drop y : String
        drop y : String
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
        let _d1000000 = call hasInfix q _t1  ; Δ{_t1}
        let _d1000000 = call hasInfix q _t2  ; Δ{_t2}
        let _d1000000 = rtcall axion_strcat _t11 _t13  ; Δ{_t11 _t13} · makes String
        let _d1000000 = rtcall axion_strcat _t2 _t4  ; Δ{_t2 _t4} · makes String
        let _d1000000 = rtcall axion_strcat _t9 _t11  ; Δ{_t11 _t9} · makes String
        let _d1000001 = rtcall axion_strcat _t9 _t12  ; Δ{_t12 _t9} · makes String
        let _d1000002 = rtcall axion_system _t5  ; Δ{_t5}
        let _t1 = + i 1  ; Δ{}
        let _t1 = + r 1  ; Δ{}
        let _t1 = + r 1  ; Δ{}
        let _t1 = - i 1  ; Δ{}
        let _t1 = call filter$$neStr _cap0 ys  ; Δ{y ys} · moves{ys} · makes List$String
        let _t1 = call filter$$nonEmpty ys  ; Δ{y ys} · moves{ys} · makes List$String
        let _t1 = call stripSlash y  ; Δ{} · makes String
        let _t10 = + i 1  ; Δ{_t9}
        let _t10 = + r 1  ; Δ{_t9}
        let _t10 = call hasPrefix "application/pdf" mime  ; Δ{}
        let _t10 = rtcall axion_strcat _t8 _t9  ; Δ{_t7 _t8 _t9} · makes String
        let _t11 = + vis 1  ; Δ{_t9}
        let _t11 = call drawLines ys _t10 px pw maxRow  ; Δ{_t9} · makes String
        let _t11 = if _t9 then
        let _t11 = rtcall axion_strcat _t7 _t10  ; Δ{_t10 _t7} · makes String
        let _t12 = + r 1  ; Δ{_t11}
        let _t12 = call clipGo s _t10 n _t11 w  ; Δ{_t9} · makes String
        let _t12 = rtcall axion_str_at 0 k  ; Δ{}
        let _t13 = == _t12 127  ; Δ{}
        let _t13 = call drawLinesAnsi ys _t12 px pw maxRow  ; Δ{_t11} · makes String
        let _t14 = rtcall axion_str_cmp key "G"  ; Δ{}
        let _t15 = == _t14 0  ; Δ{}
        let _t15 = if _t13 then
        let _t2 = call rowFor y i sel marked cwd listW prev  ; Δ{} · makes String
        let _t2 = call stripSlash y  ; Δ{} · makes String
        let _t2 = showInt r  ; Δ{} · makes String
        let _t2 = showInt r  ; Δ{} · makes String
        let _t3 = + i 1  ; Δ{_t2}
        let _t3 = + i 1  ; Δ{}
        let _t3 = call hasInfix "rar" m  ; Δ{}
        let _t3 = showInt px  ; Δ{_t2} · makes String
        let _t3 = showInt px  ; Δ{_t2} · makes String
        let _t4 = call drawRows ys _t3 start endIdx sel marked cwd listW prev  ; Δ{_t2} · makes String
        let _t4 = rtcall axion_strcat _t3 "H"  ; Δ{_t2 _t3} · makes String
        let _t4 = rtcall axion_strcat _t3 "H"  ; Δ{_t2 _t3} · makes String
        let _t5 = + i 1  ; Δ{}
        let _t5 = call pdfCmd path cols rows  ; Δ{} · makes String
        let _t5 = rtcall axion_strcat ";" _t4  ; Δ{_t2 _t4} · makes String
        let _t5 = rtcall axion_strcat ";" _t4  ; Δ{_t2 _t4} · makes String
        let _t6 = call archiveExts  ; Δ{} · makes List$String
        let _t6 = rtcall axion_str_cmp b "D"  ; Δ{}
        let _t6 = rtcall axion_strcat _t2 _t5  ; Δ{_t2 _t5} · makes String
        let _t6 = rtcall axion_strcat _t2 _t5  ; Δ{_t2 _t5} · makes String
        let _t7 = == _t6 0  ; Δ{}
        let _t7 = call csi _t6  ; Δ{_t6} · makes String
        let _t7 = call csi _t6  ; Δ{_t6} · makes String
        let _t7 = call elemBy$String e _t6  ; Δ{_t6}
        let _t7 = rtcall axion_str_len fav  ; Δ{fav}
        let _t8 = + i 1  ; Δ{}
        let _t8 = call clip y pw  ; Δ{_t7} · makes String
        let _t8 = call clipAnsi y pw  ; Δ{_t7} · makes String
        let _t8 = rtcall axion_str_at 0 k  ; Δ{}
        let _t9 = == _t8 127  ; Δ{}
        let _t9 = call csi "0m"  ; Δ{_t7 _t8} · makes String
        let _t9 = rtcall axion_strcat _t7 _t8  ; Δ{_t7 _t8} · makes String
        let _t9 = rtcall axion_substr i 1 s  ; Δ{} · makes String
        let b2 = rtcall axion_read_key_timeout 25  ; Δ{k} · makes String
        ret ""  ; Δ{}
        ret "0;36"  ; Δ{}
        ret "\u{1b}"  ; Δ{}
        ret "l"  ; Δ{}
        ret - n 1  ; Δ{}
        ret 0  ; Δ{fav}
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
        ret < i endIdx  ; Δ{}
        ret == c 13  ; Δ{}
        ret > _t7 0  ; Δ{fav}
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
        ret _d1000000  ; Δ{}
        ret _d1000000  ; Δ{}
        ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
        ret _d1000002  ; Δ{}
        ret best  ; Δ{}
        ret call clipGo s _t8 n vis w  ; Δ{} · makes String
        ret call drawLines ys _t1 px pw maxRow  ; Δ{} · makes String
        ret call drawLinesAnsi ys _t1 px pw maxRow  ; Δ{} · makes String
        ret call drawRows ys _t5 start endIdx sel marked cwd listW prev  ; Δ{} · makes String
        ret call dup y  ; Δ{} · makes String
        ret call elemBy$String x ys  ; Δ{}
        ret call filter$$neStr _cap0 ys  ; Δ{ys} · moves{ys} · makes List$String
        ret call filter$$nonEmpty ys  ; Δ{ys} · moves{ys} · makes List$String
        ret call firstPrefix ys q  ; Δ{} · makes String
        ret call hasImgTool 0  ; Δ{}
        ret call hasImgTool 0  ; Δ{}
        ret call loop cwd 0 marked prog hidden rows cols raw  ; Δ{}
        ret call loop cwd osel marked prog hidden rows cols raw  ; Δ{}
        ret call matchFrom ys q _t3 lo  ; Δ{}
        ret call matchIndex ys q _t1 dflt  ; Δ{}
        ret call pick _t1 ys  ; Δ{} · makes String
        ret call pixHeader "[video] " path mime px pw ph  ; Δ{} · makes String
        ret call stripSlash y  ; Δ{} · makes String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
        ret i  ; Δ{}
        ret i  ; Δ{}
        ret i  ; Δ{}
        ret i  ; Δ{}
        ret i  ; Δ{}
        ret if _t10 then
        ret if _t11 then
        ret if _t15 then
        ret if _t15 then
        ret if _t3 then
        ret if _t7 then
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
      drop _t1 : String
      drop _t10 : String
      drop _t2 : List$String
      drop _t2 : List$String
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
      drop _t4 : List$String
      drop _t4 : String
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
      drop _t5 : String
      drop _t5 : String
      drop _t6 : String
      drop _t6 : String
      drop _t6 : String
      drop _t6 : String
      drop _t7 : String
      drop _t7 : String
      drop _t8 : List$String
      drop _t8 : String
      drop _t9 : List$String
      drop _t9 : String
      drop b1 : String
      drop b2 : String
      drop e : String
      drop k : String
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
      let _d1000000 = call arrowKey b2  ; Δ{b2 k} · makes String
      let _d1000000 = call cmdKey prompt rows cwd acc _t10  ; Δ{_t10} · makes String
      let _d1000000 = rtcall axion_strcat "'\\''" _t4  ; Δ{_t4} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
      let _d1000000 = rtcall axion_strcat _t2 _t3  ; Δ{_t2 _t3} · makes String
      let _d1000000 = rtcall axion_strcat _t5 _t6  ; Δ{_t5 _t6} · makes String
      let _d1000000 = rtcall axion_strcat s _t1  ; Δ{_t1} · makes String
      let _d1000001 = rtcall axion_strcat _t5 _t7  ; Δ{_t5 _t7} · makes String
      let _d1000001 = rtcall axion_system _t3  ; Δ{_t3}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = + i 1  ; Δ{}
      let _t0 = == i 0  ; Δ{}
      let _t0 = > r maxRow  ; Δ{}
      let _t0 = > r maxRow  ; Δ{}
      let _t0 = call >=$Int i lo  ; Δ{}
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
      let _t1 = < i hi  ; Δ{}
      let _t1 = call </> cwd _t0  ; Δ{_t0} · makes String
      let _t1 = call bnGo ys  ; Δ{_t0} · makes String
      let _t1 = call hasPrefix q _t0  ; Δ{_t0}
      let _t1 = call qlGo ys  ; Δ{_t0} · makes String
      let _t1 = if _t0 then
      let _t1 = rtcall axion_strcat "\n" _t0  ; Δ{_t0} · makes String
      let _t10 = call length _t9  ; Δ{_t9}
      let _t10 = rtcall axion_read_key 0  ; Δ{} · makes String
      let _t10 = rtcall axion_str_at 0 k  ; Δ{}
      let _t10 = rtcall axion_system _t9  ; Δ{_t9}
      let _t11 = == _t10 27  ; Δ{}
      let _t11 = call wrapSel _t8 _t10  ; Δ{}
      let _t11 = rtcall axion_read_key 0  ; Δ{} · makes String
      let _t12 = rtcall axion_str_cmp key "g"  ; Δ{}
      let _t13 = == _t12 0  ; Δ{}
      let _t2 = - sel mx  ; Δ{}
      let _t2 = == c 10  ; Δ{}
      let _t2 = call >=$Int i n  ; Δ{}
      let _t2 = call >=$Int i n  ; Δ{}
      let _t2 = call editorCmd 0  ; Δ{} · makes String
      let _t2 = call hasInfix "x-7z" m  ; Δ{}
      let _t2 = call lines raw  ; Δ{} · makes List$String
      let _t2 = call lines raw  ; Δ{} · makes List$String
      let _t2 = call resetSeq  ; Δ{} · makes String
      let _t2 = call selPath cwd hidden sel  ; Δ{} · makes String
      let _t2 = call shQuote cwd  ; Δ{} · makes String
      let _t2 = if _t0 then
      let _t2 = rtcall axion_strcat " " _t1  ; Δ{_t0 _t1} · makes String
      let _t2 = rtcall axion_strcat "\n" _t1  ; Δ{_t0 _t1} · makes String
      let _t2 = rtcall axion_strcat _t1 "\n"  ; Δ{_t1} · makes String
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = call envOr "SHELL" "sh"  ; Δ{_t2} · makes String
      let _t3 = call filterFile 0  ; Δ{} · makes String
      let _t3 = call joinPaths cwd ys  ; Δ{_t2} · makes String
      let _t3 = call length _t2  ; Δ{_t2}
      let _t3 = call length _t2  ; Δ{_t2}
      let _t3 = call selPath cwd hidden sel  ; Δ{_t2} · makes String
      let _t3 = call shQuote _t2  ; Δ{_t2} · makes String
      let _t3 = call videoCmd path cols rows  ; Δ{} · makes String
      let _t3 = if _t1 then
      let _t3 = putStr _t2  ; Δ{_t2}
      let _t3 = rtcall axion_str_at i s  ; Δ{}
      let _t3 = rtcall axion_system "test -t 0 && stty sane 2>/dev/null"  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = - j 1  ; Δ{}
      let _t4 = - j i  ; Δ{}
      let _t4 = > _t3 0  ; Δ{}
      let _t4 = > _t3 0  ; Δ{}
      let _t4 = call audioExts  ; Δ{} · makes List$String
      let _t4 = call hasPrefix "application/pdf" mime  ; Δ{}
      let _t4 = call infoMime _t1  ; Δ{_t1} · makes String
      let _t4 = call nEntries cwd hidden  ; Δ{}
      let _t4 = call nEntries cwd hidden  ; Δ{}
      let _t4 = call shEsc s _t3 n  ; Δ{} · makes String
      let _t4 = call shQuote _t3  ; Δ{_t2 _t3} · makes String
      let _t4 = call shQuote _t3  ; Δ{_t3} · makes String
      let _t4 = if _t3 then
      let _t4 = rtcall axion_str_at 0 k  ; Δ{}
      let _t4 = rtcall axion_str_cmp b "C"  ; Δ{}
      let _t4 = rtcall axion_str_len b1  ; Δ{b1 k}
      let _t4 = rtcall axion_strcat " && " _t3  ; Δ{_t2 _t3} · makes String
      let _t4 = rtcall axion_strcat "stat -- " _t3  ; Δ{_t3} · makes String
      let _t5 = * acc 10  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t5 = == _t4 0  ; Δ{k}
      let _t5 = == _t4 0  ; Δ{}
      let _t5 = call clampSel sel _t4  ; Δ{}
      let _t5 = call elemBy$String e _t4  ; Δ{_t4}
      let _t5 = call lastqFile 0  ; Δ{_t4} · makes String
      let _t5 = call markCount marked  ; Δ{}
      let _t5 = call previewImage cwd sel rows raw cols _t4  ; Δ{_t4}
      let _t5 = call scrollUp poff rows  ; Δ{}
      let _t5 = call searchPrompt rows acc  ; Δ{} · makes String
      let _t5 = rtcall axion_run _t4  ; Δ{_t4} · makes String
      let _t5 = rtcall axion_str_at 0 key  ; Δ{fav}
      let _t5 = rtcall axion_strcat " " _t4  ; Δ{_t2 _t4} · makes String
      let _t5 = rtcall axion_strcat _t2 _t4  ; Δ{_t2 _t4} · makes String
      let _t5 = rtcall axion_substr i 1 s  ; Δ{} · makes String
      let _t5 = rtcall axion_substr i _t4 s  ; Δ{} · makes String
      let _t6 = + _t4 _t5  ; Δ{}
      let _t6 = + i 1  ; Δ{_t5}
      let _t6 = call <=$Int _t5 57  ; Δ{fav}
      let _t6 = call clipGo s j n vis w  ; Δ{_t5} · makes String
      let _t6 = call nEntries cwd hidden  ; Δ{}
      let _t6 = call nEntries cwd hidden  ; Δ{}
      let _t6 = call shQuote _t5  ; Δ{_t4 _t5} · makes String
      let _t6 = putStr _t5  ; Δ{_t5}
      let _t6 = putStr _t5  ; Δ{_t5}
      let _t6 = rtcall axion_str_at 0 k  ; Δ{}
      let _t6 = rtcall axion_str_at 0 k  ; Δ{}
      let _t6 = rtcall axion_str_at i s  ; Δ{}
      let _t6 = rtcall axion_strcat "cd " _t5  ; Δ{_t5} · makes String
      let _t6 = rtcall axion_strcat _t2 _t5  ; Δ{_t2 _t5} · makes String
      let _t7 = + _t6 1  ; Δ{}
      let _t7 = + _t6 1  ; Δ{}
      let _t7 = - _t6 48  ; Δ{}
      let _t7 = == _t6 27  ; Δ{}
      let _t7 = call >=$Int vis w  ; Δ{}
      let _t7 = call clampSel sel _t6  ; Δ{}
      let _t7 = call shEsc s _t6 n  ; Δ{_t5} · makes String
      let _t7 = rtcall axion_strcat " " _t6  ; Δ{_t4 _t6} · makes String
      let _t7 = rtcall axion_system _t6  ; Δ{_t6}
      let _t7 = rtcall axion_system _t6  ; Δ{_t6}
      let _t8 = + _t5 _t7  ; Δ{}
      let _t8 = - sel 1  ; Δ{}
      let _t8 = call clampSel sel _t7  ; Δ{}
      let _t8 = call clampSel sel _t7  ; Δ{}
      let _t8 = call lines raw  ; Δ{} · makes List$String
      let _t8 = rtcall axion_strcat _t4 _t7  ; Δ{_t4 _t7} · makes String
      let _t9 = call hasPrefix "video/" mime  ; Δ{}
      let _t9 = call lines raw  ; Δ{} · makes List$String
      let _t9 = call searchSel _t8 acc osel  ; Δ{_t8}
      let _t9 = rtcall axion_strcat "rm -f " _t8  ; Δ{_t8} · makes String
      let b1 = rtcall axion_read_key_timeout 25  ; Δ{k} · makes String
      let b2 = rtcall axion_read_key_timeout 25  ; Δ{k} · makes String
      let j = call escEnd s _t3 n  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret "-S"  ; Δ{}
      ret "1;35"  ; Δ{}
      ret "\u{1b}"  ; Δ{}
      ret "img2sixel"  ; Δ{}
      ret "j"  ; Δ{}
      ret "vi"  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret + _t2 1  ; Δ{}
      ret + c 32  ; Δ{}
      ret + i 1  ; Δ{}
      ret + i 1  ; Δ{}
      ret - 0 1  ; Δ{}
      ret - n 1  ; Δ{}
      ret 0  ; Δ{fav}
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
      ret == _t4 10  ; Δ{}
      ret == _t6 10  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret _d1000001  ; Δ{}
      ret acc  ; Δ{}
      ret best  ; Δ{}
      ret c  ; Δ{}
      ret call </> cwd nm  ; Δ{} · makes String
      ret call <=$Int _t3 126  ; Δ{}
      ret call dup nm  ; Δ{} · makes String
      ret call endSearch cwd marked prog hidden rows cols raw acc _t9  ; Δ{}
      ret call escFinal s _t3 n  ; Δ{}
      ret call escFinal s _t5 n  ; Δ{}
      ret call findChar c s _t3 n  ; Δ{}
      ret call infixGo q s _t5 lim  ; Δ{}
      ret call lastIndex c s _t4 i  ; Δ{}
      ret call lastIndex c s _t5 best  ; Δ{}
      ret call loop cwd _t11 marked prog hidden rows cols raw  ; Δ{}
      ret call loop cwd msel marked prog hidden rows cols raw  ; Δ{}
      ret call loopAt cwd sel marked prog hidden rows cols raw _t5  ; Δ{}
      ret call matchBefore ys q _t0 hi _t4  ; Δ{}
      ret call pixHeader "[image] " path mime px pw ph  ; Δ{} · makes String
      ret call readIntGo s _t4 _t8  ; Δ{} · makes Maybe$Int
      ret call reloop cwd 0 marked prog hidden rows  ; Δ{}
      ret call reloop cwd _t5 "" "" hidden rows  ; Δ{}
      ret call reloop cwd _t7 "" "" hidden rows  ; Δ{}
      ret call reloop cwd _t8 marked prog hidden rows  ; Δ{}
      ret call reloop cwd _t8 marked prog hidden rows  ; Δ{}
      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
      ret call step cwd sel marked prog hidden rows cols raw key  ; Δ{}
      ret call trimEnd s _t4  ; Δ{}
      ret call trimStart s _t4  ; Δ{}
      ret call wordEnd s _t3 n  ; Δ{}
      ret callclo f x  ; Δ{x} · moves{x}
      ret case _t10 of
      ret case _t11 of
      ret case _t3 of
      ret case _t3 of
      ret case _t5 of
      ret case _t6 of
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
      ret i  ; Δ{}
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t1 then
      ret if _t1 then
      ret if _t11 then
      ret if _t13 then
      ret if _t2 then
      ret if _t2 then
      ret if _t2 then
      ret if _t2 then
      ret if _t2 then
      ret if _t4 then
      ret if _t4 then
      ret if _t4 then
      ret if _t5 then
      ret if _t5 then
      ret if _t5 then
      ret if _t6 then
      ret if _t7 then
      ret if _t7 then
      ret if _t9 then
      ret j  ; Δ{}
      ret k  ; Δ{k} · moves{k}
      ret rtcall axion_read_key 0  ; Δ{} · makes String
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
    drop _t1 : String
    drop _t1 : String
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
    drop _t12 : String
    drop _t12 : String
    drop _t13 : String
    drop _t13 : String
    drop _t14 : String
    drop _t14 : String
    drop _t15 : String
    drop _t15 : String
    drop _t16 : String
    drop _t16 : String
    drop _t17 : String
    drop _t17 : String
    drop _t18 : List$String
    drop _t18 : String
    drop _t2 : List$String
    drop _t2 : List$String
    drop _t2 : List$String
    drop _t2 : List$String
    drop _t2 : List$String
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
    drop _t3 : List$String
    drop _t3 : List$String
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
    drop _t3 : String
    drop _t3 : String
    drop _t3 : String
    drop _t3 : String
    drop _t3 : String
    drop _t4 : List$String
    drop _t4 : String
    drop _t4 : String
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
    drop _t5 : String
    drop _t6 : String
    drop _t6 : String
    drop _t6 : String
    drop _t6 : String
    drop _t6 : String
    drop _t6 : String
    drop _t6 : String
    drop _t6 : String
    drop _t7 : List$String
    drop _t7 : List$String
    drop _t7 : String
    drop _t7 : String
    drop _t7 : String
    drop _t7 : String
    drop _t7 : String
    drop _t8 : List$String
    drop _t8 : String
    drop _t9 : String
    drop _t9 : String
    drop _t9 : String
    drop b1 : String
    drop e : String
    drop e : String
    drop fav : String
    drop fav : String
    drop k : String
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
    let _d1000000 = call colorForExt _t1  ; Δ{_t1} · makes String
    let _d1000000 = call drawLines _t7 1 px pw ph  ; Δ{_t7} · makes String
    let _d1000000 = call drawLines _t8 1 px pw ph  ; Δ{_t8} · makes String
    let _d1000000 = call drawLinesAnsi _t7 1 px pw ph  ; Δ{_t7} · makes String
    let _d1000000 = call drawPreview _t0 _t1 _t2 mx mime poff  ; Δ{_t0} · makes String
    let _d1000000 = call flashFail _t3 rows  ; Δ{_t3}
    let _d1000000 = call gotoTo cwd sel marked prog hidden rows _t3  ; Δ{_t3}
    let _d1000000 = call hasInfix "kitty" _t3  ; Δ{_t3}
    let _d1000000 = call previewPix _t6 cols rows mime  ; Δ{_t6}
    let _d1000000 = call reloop _t1 0 marked prog hidden rows  ; Δ{_t1}
    let _d1000000 = call reloop _t2 0 marked prog hidden rows  ; Δ{_t2}
    let _d1000000 = call reloop fav 0 marked prog hidden rows  ; Δ{fav}
    let _d1000000 = call stepAt cwd sel marked prog hidden rows cols raw poff _t1  ; Δ{_t1}
    let _d1000000 = call toLower _t6  ; Δ{_t6} · makes String
    let _d1000000 = call unlines _t2  ; Δ{_t2} · makes String
    let _d1000000 = call warmLoop _t3 "cat \"$src\" >/dev/null 2>&1"  ; Δ{_t3} · makes String
    let _d1000000 = rtcall axion_mkdir_p _t3  ; Δ{_t3}
    let _d1000000 = rtcall axion_rename _t6 _t7  ; Δ{_t6 _t7}
    let _d1000000 = rtcall axion_strcat " " _t2  ; Δ{_t2} · makes String
    let _d1000000 = rtcall axion_strcat _t3 _t5  ; Δ{_t3 _t5} · makes String
    let _d1000000 = rtcall axion_strcat _t6 _t10  ; Δ{_t10 _t6} · makes String
    let _d1000000 = rtcall axion_strcat a _t0  ; Δ{_t0} · makes String
    let _d1000000 = rtcall axion_system _t1  ; Δ{_t1}
    let _d1000000 = rtcall axion_system _t10  ; Δ{_t10}
    let _d1000000 = rtcall axion_system _t6  ; Δ{_t6}
    let _d1000000 = rtcall axion_write_file _t3 ""  ; Δ{_t3}
    let _d1000001 = call drawLines _t18 1 px pw ph  ; Δ{_t18} · makes String
    let _d1000001 = call warmLoop _t4 _t7  ; Δ{_t4 _t7} · makes String
    let _d1000001 = rtcall axion_strcat m _t3  ; Δ{_t3} · makes String
    let _d1000001 = rtcall axion_system _t18  ; Δ{_t18}
    let _d1000002 = call elemBy$String e _t3  ; Δ{_t3 e}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t0 = + lw 1  ; Δ{}
    let _t0 = call selPathOf cwd raw sel  ; Δ{} · makes String
    let _t0 = rtcall axion_strcat "/" b  ; Δ{} · makes String
    let _t1 = + i 1  ; Δ{}
    let _t1 = + k 1  ; Δ{}
    let _t1 = - j 1  ; Δ{}
    let _t1 = - n 1  ; Δ{}
    let _t1 = < i 0  ; Δ{}
    let _t1 = < i 0  ; Δ{}
    let _t1 = < sel mx  ; Δ{}
    let _t1 = == c 9  ; Δ{}
    let _t1 = call <=$Int c 90  ; Δ{}
    let _t1 = call baseName path  ; Δ{} · makes String
    let _t1 = call dup dest  ; Δ{} · makes String
    let _t1 = call errDetail 0  ; Δ{} · makes String
    let _t1 = call extOf raw  ; Δ{} · makes String
    let _t1 = call findChar 10 s i n  ; Δ{}
    let _t1 = call hasInfix "tar" m  ; Δ{}
    let _t1 = call icatCmd path cols rows  ; Δ{} · makes String
    let _t1 = call lines m  ; Δ{} · makes List$String
    let _t1 = call paneX cols  ; Δ{_t0}
    let _t1 = call previewOn cols  ; Δ{}
    let _t1 = call previewOn cols  ; Δ{}
    let _t1 = call readMainKey 0  ; Δ{} · makes String
    let _t1 = call shQuote path  ; Δ{} · makes String
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_len q  ; Δ{}
    let _t1 = rtcall axion_str_len s  ; Δ{}
    let _t1 = showInt r  ; Δ{} · makes String
    let _t10 = call shQuote path  ; Δ{_t9} · makes String
    let _t10 = rtcall axion_strcat "d=" _t9  ; Δ{_t9} · makes String
    let _t10 = rtcall axion_strcat _t7 _t9  ; Δ{_t6 _t7 _t9} · makes String
    let _t11 = call quoteLines marked  ; Δ{} · makes String
    let _t11 = showInt ph  ; Δ{_t10 _t9} · makes String
    let _t12 = call shQuote cwd  ; Δ{_t11} · makes String
    let _t12 = rtcall axion_strcat " 2>/dev/null | head -n " _t11  ; Δ{_t10 _t11 _t9} · makes String
    let _t13 = call errRedir  ; Δ{_t11 _t12} · makes String
    let _t13 = rtcall axion_strcat _t10 _t12  ; Δ{_t10 _t12 _t9} · makes String
    let _t14 = rtcall axion_strcat " -- " _t13  ; Δ{_t13 _t9} · makes String
    let _t14 = rtcall axion_strcat _t12 _t13  ; Δ{_t11 _t12 _t13} · makes String
    let _t15 = rtcall axion_strcat " " _t14  ; Δ{_t11 _t14} · makes String
    let _t15 = rtcall axion_strcat _t9 _t14  ; Δ{_t14 _t9} · makes String
    let _t16 = rtcall axion_strcat "tail -n +" _t15  ; Δ{_t15} · makes String
    let _t16 = rtcall axion_strcat _t11 _t15  ; Δ{_t11 _t15} · makes String
    let _t17 = rtcall axion_run _t16  ; Δ{_t16} · makes String
    let _t17 = rtcall axion_strcat " -- " _t16  ; Δ{_t16} · makes String
    let _t18 = call lines _t17  ; Δ{_t17} · makes List$String
    let _t18 = rtcall axion_strcat prog _t17  ; Δ{_t17} · makes String
    let _t2 = + i 1  ; Δ{}
    let _t2 = + k 1  ; Δ{}
    let _t2 = + sel 1  ; Δ{}
    let _t2 = - _t1 1  ; Δ{}
    let _t2 = == _t1 27  ; Δ{}
    let _t2 = == _t1 39  ; Δ{}
    let _t2 = == _t1 91  ; Δ{}
    let _t2 = == _t1 c  ; Δ{}
    let _t2 = call >=$Int _t1 64  ; Δ{}
    let _t2 = call bulkTmp 0  ; Δ{} · makes String
    let _t2 = call dup mime  ; Δ{_t1} · makes String
    let _t2 = call expandDir cwd nm  ; Δ{} · makes String
    let _t2 = call filter$$neStr p _t1  ; Δ{_t1} · moves{_t1} · makes List$String
    let _t2 = call hasPrefix "video/" mime  ; Δ{}
    let _t2 = call have "img2sixel"  ; Δ{}
    let _t2 = call isSpace _t1  ; Δ{}
    let _t2 = call lines raw  ; Δ{} · makes List$String
    let _t2 = call lines raw  ; Δ{} · makes List$String
    let _t2 = call lines raw  ; Δ{} · makes List$String
    let _t2 = call lowerChar _t1  ; Δ{}
    let _t2 = call markCount marked  ; Δ{}
    let _t2 = call paneW cols  ; Δ{_t0}
    let _t2 = call scrollDown poff rows  ; Δ{}
    let _t2 = call scrollPipe poff ph  ; Δ{_t1} · makes String
    let _t2 = call selPathOf cwd raw i  ; Δ{} · makes String
    let _t2 = call selPathOf cwd raw sel  ; Δ{} · makes String
    let _t2 = call spaces _t1  ; Δ{} · makes String
    let _t2 = call termRows 0  ; Δ{}
    let _t2 = call trashDir 0  ; Δ{} · makes String
    let _t2 = call videoExts  ; Δ{} · makes List$String
    let _t2 = rtcall axion_str_at 0 k  ; Δ{k}
    let _t2 = rtcall axion_str_at 0 k  ; Δ{k}
    let _t2 = rtcall axion_str_at 0 k  ; Δ{}
    let _t2 = rtcall axion_str_at _t1 s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_cmp b "B"  ; Δ{}
    let _t2 = rtcall axion_str_cmp k "Y"  ; Δ{}
    let _t2 = rtcall axion_str_cmp s "-t"  ; Δ{}
    let _t2 = rtcall axion_str_len e  ; Δ{e v}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t2 = rtcall axion_strcat ": " _t1  ; Δ{_t1} · makes String
    let _t2 = rtcall axion_substr i _t1 s  ; Δ{} · makes String
    let _t2 = showInt col  ; Δ{_t1} · makes String
    let _t3 = + from 1  ; Δ{_t2}
    let _t3 = - 0 1  ; Δ{_t2}
    let _t3 = - _t2 1  ; Δ{}
    let _t3 = - _t2 k  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = == _t2 13  ; Δ{}
    let _t3 = == _t2 27  ; Δ{k}
    let _t3 = == _t2 c  ; Δ{}
    let _t3 = > _t2 0  ; Δ{e v}
    let _t3 = call </> cwd _t0  ; Δ{_t0} · makes String
    let _t3 = call </> cwd _t0  ; Δ{_t0} · makes String
    let _t3 = call absPath _t2  ; Δ{_t2} · makes String
    let _t3 = call codeExts  ; Δ{e} · makes List$String
    let _t3 = call elemBy$String e _t2  ; Δ{_t2}
    let _t3 = call hasPrefix "/" nm  ; Δ{}
    let _t3 = call isDigit _t2  ; Δ{}
    let _t3 = call isSpace _t2  ; Δ{}
    let _t3 = call isSpace _t2  ; Δ{}
    let _t3 = call lines raw  ; Δ{} · makes List$String
    let _t3 = call paneW cols  ; Δ{}
    let _t3 = call searchSel _t2 acc osel  ; Δ{_t2}
    let _t3 = call shQuote _t2  ; Δ{_t2} · makes String
    let _t3 = call shQuote _t2  ; Δ{_t2} · makes String
    let _t3 = call winPaths cwd sel raw  ; Δ{} · makes String
    let _t3 = call wordEnd s i n  ; Δ{}
    let _t3 = rtcall axion_chr _t2  ; Δ{} · makes String
    let _t3 = rtcall axion_getenv "TERM"  ; Δ{} · makes String
    let _t3 = rtcall axion_str_at 0 key  ; Δ{fav}
    let _t3 = rtcall axion_str_cmp key "K"  ; Δ{}
    let _t3 = rtcall axion_str_cmp q _t2  ; Δ{_t2}
    let _t3 = rtcall axion_str_len p  ; Δ{}
    let _t3 = rtcall axion_str_len s  ; Δ{}
    let _t3 = rtcall axion_str_len s  ; Δ{}
    let _t3 = rtcall axion_strcat "  " _t2  ; Δ{_t1 _t2} · makes String
    let _t3 = rtcall axion_strcat " 2>/dev/null" _t2  ; Δ{_t1 _t2} · makes String
    let _t3 = rtcall axion_strcat _t2 "H"  ; Δ{_t1 _t2} · makes String
    let _t3 = rtcall axion_strcat label _t2  ; Δ{_t2} · makes String
    let _t3 = rtcall axion_strcat p "\n"  ; Δ{} · makes String
    let _t4 = + i 1  ; Δ{_t3}
    let _t4 = - _t3 1  ; Δ{}
    let _t4 = - _t3 k  ; Δ{}
    let _t4 = == _t3 0  ; Δ{}
    let _t4 = == _t3 0  ; Δ{}
    let _t4 = call >=$Int _t3 49  ; Δ{fav}
    let _t4 = call length _t3  ; Δ{_t3}
    let _t4 = call lines raw  ; Δ{} · makes List$String
    let _t4 = call markCount marked  ; Δ{}
    let _t4 = call matchBefore _t2 q 0 from _t3  ; Δ{_t2}
    let _t4 = call matchFrom _t2 q 0 _t3  ; Δ{_t2}
    let _t4 = call maxItems rows  ; Δ{}
    let _t4 = call quoteLines marked  ; Δ{_t3} · makes String
    let _t4 = call winPaths cwd sel raw  ; Δ{} · makes String
    let _t4 = if _t2 then
    let _t4 = rtcall axion_str_at 0 k  ; Δ{}
    let _t4 = rtcall axion_str_len b1  ; Δ{b1 k}
    let _t4 = rtcall axion_str_len q  ; Δ{}
    let _t4 = rtcall axion_strcat ";" _t3  ; Δ{_t1 _t3} · makes String
    let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
    let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
    let _t4 = rtcall axion_strcat _t3 " "  ; Δ{_t3} · makes String
    let _t4 = rtcall axion_substr 0 _t3 s  ; Δ{} · makes String
    let _t5 = - _t3 _t4  ; Δ{}
    let _t5 = - _t4 1  ; Δ{}
    let _t5 = == _t4 0  ; Δ{k}
    let _t5 = == _t4 13  ; Δ{}
    let _t5 = call codePreviewCmd path poff ph  ; Δ{} · makes String
    let _t5 = call errRedir  ; Δ{_t3 _t4} · makes String
    let _t5 = call length _t4  ; Δ{_t4}
    let _t5 = call paneW cols  ; Δ{_t4}
    let _t5 = call paneX cols  ; Δ{}
    let _t5 = call toLowerGo s _t4 n  ; Δ{_t3} · makes String
    let _t5 = call trashPrompt _t4  ; Δ{} · makes String
    let _t5 = call wrapSel _t2 _t4  ; Δ{}
    let _t5 = if _t3 then
    let _t5 = rtcall axion_str_cmp _t4 p  ; Δ{_t4}
    let _t5 = rtcall axion_strcat "ls -p --group-directories-first -- " _t4  ; Δ{_t4} · makes String
    let _t5 = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
    let _t5 = rtcall axion_strcat acc _t4  ; Δ{_t4} · makes String
    let _t5 = rtcall axion_strcat label _t4  ; Δ{_t4} · makes String
    let _t6 = - _t5 1  ; Δ{}
    let _t6 = call clampSel sel _t5  ; Δ{}
    let _t6 = call confirm _t5 rows  ; Δ{_t5}
    let _t6 = call csi _t5  ; Δ{_t5} · makes String
    let _t6 = call maxItems rows  ; Δ{_t4}
    let _t6 = call prefetchCmd cwd sel rows raw cols  ; Δ{} · makes String
    let _t6 = call selPath cwd hidden sel  ; Δ{_t3} · makes String
    let _t6 = call selPathOf cwd raw sel  ; Δ{} · makes String
    let _t6 = con Nil  ; Δ{_t5} · makes List$String
    let _t6 = rtcall axion_run _t5  ; Δ{_t5} · makes String
    let _t6 = rtcall axion_run _t5  ; Δ{_t5} · makes String
    let _t6 = rtcall axion_str_cmp key "k"  ; Δ{}
    let _t6 = rtcall axion_str_len q  ; Δ{}
    let _t6 = rtcall axion_strcat "; do b=${src##*/}; dest=\"$d/$b\"; n=1; while [ -e \"$dest\" ]; do dest=\"$d/$b.$n\"; n=$((n+1)); done; mv -- \"$src\" \"$dest\" && printf '%s\\t%s\\n' \"$dest\" \"$src\" >> \"$L\"; done" _t5  ; Δ{_t3 _t4 _t5} · makes String
    let _t6 = rtcall axion_substr _t2 _t5 s  ; Δ{} · makes String
    let _t7 = == _t6 0  ; Δ{}
    let _t7 = call </> cwd _t3  ; Δ{_t3 _t6} · makes String
    let _t7 = call lines _t6  ; Δ{_t6} · makes List$String
    let _t7 = call lines _t6  ; Δ{_t6} · makes List$String
    let _t7 = call paint "90" "│"  ; Δ{_t6} · makes String
    let _t7 = call paneX cols  ; Δ{}
    let _t7 = call sixelDecode _t5 _t6  ; Δ{_t4} · makes String
    let _t7 = call termRows 0  ; Δ{}
    let _t7 = con Cons "(install kitty or img2sixel for a pixel preview)" _t6  ; Δ{_t5 _t6} · moves{_t6} · makes List$String
    let _t7 = if _t5 then
    let _t7 = rtcall axion_strcat _t4 _t6  ; Δ{_t3 _t4 _t6} · makes String
    let _t7 = rtcall axion_substr _t5 _t6 s  ; Δ{} · makes String
    let _t8 = + poff 1  ; Δ{}
    let _t8 = + r 1  ; Δ{_t6 _t7}
    let _t8 = call hasPrefix "image/" mime  ; Δ{}
    let _t8 = call paneW cols  ; Δ{}
    let _t8 = con Cons _t5 _t7  ; Δ{_t5 _t7} · moves{_t5 _t7} · makes List$String
    let _t8 = rtcall axion_str_cmp _t7 q  ; Δ{_t7}
    let _t8 = rtcall axion_strcat "; L=\"$HOME/.cache/fff/trashlog\"; mkdir -p \"$d\" \"${L%/*}\" && for src in " _t7  ; Δ{_t3 _t7} · makes String
    let _t9 = call maxItems rows  ; Δ{}
    let _t9 = call sepGo col _t8 mx  ; Δ{_t6 _t7} · makes String
    let _t9 = rtcall axion_strcat _t3 _t8  ; Δ{_t3 _t8} · makes String
    let _t9 = showInt _t8  ; Δ{} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let b1 = rtcall axion_read_key_timeout 25  ; Δ{k} · makes String
    let e = rtcall axion_getenv "EDITOR"  ; Δ{v} · makes String
    ret " "  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret "*"  ; Δ{}
    ret "-t"  ; Δ{}
    ret "."  ; Δ{}
    ret "."  ; Δ{}
    ret "/"  ; Δ{}
    ret "1;34"  ; Δ{}
    ret "1;35"  ; Δ{}
    ret "chmod +x -- "  ; Δ{}
    ret "chmod -x -- "  ; Δ{}
    ret "k"  ; Δ{}
    ret "kitten"  ; Δ{}
    ret "ls -Ap --group-directories-first $o -- "  ; Δ{}
    ret "ls -p --group-directories-first $o -- "  ; Δ{}
    ret - rows 3  ; Δ{}
    ret 0  ; Δ{fav}
    ret 0  ; Δ{k}
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
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret == _t2 0  ; Δ{}
    ret == _t2 27  ; Δ{k}
    ret == _t2 rows  ; Δ{}
    ret == _t5 0  ; Δ{}
    ret == _t8 0  ; Δ{}
    ret == x y  ; Δ{}
    ret > _t2 0  ; Δ{}
    ret > total 0  ; Δ{}
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
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
    ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
    ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
    ret _d1000001  ; Δ{}
    ret _d1000002  ; Δ{}
    ret a  ; Δ{}
    ret a  ; Δ{}
    ret a  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret best  ; Δ{}
    ret c  ; Δ{}
    ret call <=$Int c 57  ; Δ{}
    ret call bottomMatch raw q from  ; Δ{}
    ret call bulkRun cwd marked _t2  ; Δ{_t2} · moves{_t2}
    ret call clip plain listW  ; Δ{} · makes String
    ret call consLine s i n _t1  ; Δ{} · makes List$String
    ret call consWord s i n _t3  ; Δ{} · makes List$String
    ret call doPasteRun cwd sel marked prog hidden rows  ; Δ{}
    ret call doPasteRun cwd sel marked prog hidden rows  ; Δ{}
    ret call drawSep _t0 mx  ; Δ{} · makes String
    ret call dup a  ; Δ{} · makes String
    ret call dup acc  ; Δ{} · makes String
    ret call dup d  ; Δ{} · makes String
    ret call dup dflt  ; Δ{} · makes String
    ret call dup s  ; Δ{} · makes String
    ret call dup s  ; Δ{} · makes String
    ret call endSearch cwd marked prog hidden rows cols raw acc _t3  ; Δ{}
    ret call fit plain listW  ; Δ{} · makes String
    ret call flashFail label rows  ; Δ{}
    ret call hasPrefix "~/" nm  ; Δ{}
    ret call have "kitten"  ; Δ{}
    ret call kittenRenderSrc _t3 _t4 _t6 0  ; Δ{} · makes String
    ret call loop cwd _t5 marked prog hidden rows cols raw  ; Δ{}
    ret call loopAt cwd sel marked prog hidden rows cols raw _t2  ; Δ{}
    ret call markInfo marked prog  ; Δ{} · makes String
    ret call matchIndex xs acc 0 dflt  ; Δ{}
    ret call metaShow info  ; Δ{} · makes String
    ret call nextOrTop raw q from _t4  ; Δ{}
    ret call openFile cwd sel marked prog hidden rows  ; Δ{}
    ret call openOther cwd sel marked prog hidden rows  ; Δ{}
    ret call openText cwd sel marked prog hidden rows  ; Δ{}
    ret call paint "7" cell  ; Δ{} · makes String
    ret call paint col cell  ; Δ{} · makes String
    ret call pasteIfYes cwd sel marked prog hidden rows _t6  ; Δ{}
    ret call pollKey cwd sel marked prog hidden rows cols raw poff  ; Δ{}
    ret call pollKey cwd sel marked prog hidden rows cols raw poff  ; Δ{}
    ret call prevOrBottom raw q from _t4  ; Δ{}
    ret call readIntGo s 0 0  ; Δ{} · makes Maybe$Int
    ret call reloop cwd _t6 marked prog hidden _t7  ; Δ{}
    ret call reloop cwd sel marked prog hidden rows  ; Δ{}
    ret call reloop cwd sel marked prog hidden rows  ; Δ{}
    ret call reloop cwd sel marked prog hidden rows  ; Δ{}
    ret call reloop cwd sel marked prog hidden rows  ; Δ{}
    ret call resizeCheck cwd sel marked prog hidden rows cols raw poff  ; Δ{}
    ret call runPaste cwd marked prog  ; Δ{}
    ret call sixelRenderSrc _t7 _t8 _t9  ; Δ{} · makes String
    ret call stepAt cwd sel marked prog hidden rows cols raw poff key  ; Δ{}
    ret call tildeExpand nm  ; Δ{} · makes String
    ret call topMatch raw q from  ; Δ{}
    ret call windowGo cwd raw _t1 hi _t5  ; Δ{_t5} · moves{_t5} · makes String
    ret call wordsFrom s _t2 n  ; Δ{} · makes List$String
    ret call wordsStep s i n  ; Δ{} · makes List$String
    ret cols  ; Δ{}
    ret comp  ; Δ{}
    ret con Just acc  ; Δ{} · makes Maybe$Int
    ret con Nil  ; Δ{} · makes List$String
    ret con Nil  ; Δ{} · makes List$String
    ret con Nothing  ; Δ{} · makes Maybe$Int
    ret dflt  ; Δ{}
    ret div cols 2  ; Δ{}
    ret div h 2  ; Δ{}
    ret from  ; Δ{}
    ret from  ; Δ{}
    ret from  ; Δ{}
    ret i  ; Δ{}
    ret i  ; Δ{}
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
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t4 then
    ret if _t4 then
    ret if _t4 then
    ret if _t4 then
    ret if _t5 then
    ret if _t5 then
    ret if _t7 then
    ret if _t7 then
    ret if _t8 then
    ret j  ; Δ{}
    ret k  ; Δ{k} · moves{k}
    ret n  ; Δ{}
    ret n  ; Δ{}
    ret n  ; Δ{}
    ret p  ; Δ{}
    ret rtcall axion_strcat a b  ; Δ{} · makes String
    ret rtcall axion_strcat s ""  ; Δ{} · makes String
    ret rtcall axion_substr 0 _t2 s  ; Δ{} · makes String
    ret rtcall axion_substr 0 _t3 s  ; Δ{} · makes String
    ret rtcall axion_substr 0 k s  ; Δ{} · makes String
    ret rtcall axion_substr 0 w s  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 s  ; Δ{} · makes String
    ret v  ; Δ{v} · moves{v}
    ret v  ; Δ{v} · moves{v}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t11}
  ; Δ{_t1}
  ; Δ{_t3}
  ; Δ{_t8}
  ; Δ{_t8}
  ; Δ{e v}
  ; Δ{e}
  ; Δ{fav}
  ; Δ{fav}
  ; Δ{fav}
  ; Δ{fav}
  ; Δ{k}
  ; Δ{k}
  ; Δ{k}
  ; Δ{k}
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
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
  drop _t0 : List$String
  drop _t0 : List$String
  drop _t0 : List$String
  drop _t0 : List$String
  drop _t0 : List$String
  drop _t0 : List$String
  drop _t0 : List$String
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
  drop _t10 : String
  drop _t10 : String
  drop _t10 : String
  drop _t10 : String
  drop _t11 : String
  drop _t11 : String
  drop _t11 : String
  drop _t11 : String
  drop _t12 : String
  drop _t12 : String
  drop _t12 : String
  drop _t13 : String
  drop _t13 : String
  drop _t14 : String
  drop _t14 : String
  drop _t15 : String
  drop _t16 : String
  drop _t17 : String
  drop _t18 : String
  drop _t19 : String
  drop _t2 : List$String
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
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t20 : String
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
  drop _t3 : String
  drop _t3 : String
  drop _t3 : String
  drop _t3 : String
  drop _t4 : List$String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
  drop _t4 : String
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
  drop _t5 : String
  drop _t5 : String
  drop _t5 : String
  drop _t5 : String
  drop _t5 : String
  drop _t5 : String
  drop _t5 : String
  drop _t5 : String
  drop _t6 : String
  drop _t6 : String
  drop _t6 : String
  drop _t6 : String
  drop _t6 : String
  drop _t6 : String
  drop _t6 : String
  drop _t6 : String
  drop _t6 : String
  drop _t6 : String
  drop _t6 : String
  drop _t6 : String
  drop _t6 : String
  drop _t7 : String
  drop _t7 : String
  drop _t7 : String
  drop _t7 : String
  drop _t7 : String
  drop _t7 : String
  drop _t7 : String
  drop _t7 : String
  drop _t7 : String
  drop _t7 : String
  drop _t7 : String
  drop _t7 : String
  drop _t8 : String
  drop _t8 : String
  drop _t8 : String
  drop _t8 : String
  drop _t8 : String
  drop _t8 : String
  drop _t8 : String
  drop _t8 : String
  drop _t8 : String
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop c : String
  drop rng : String
  drop sed : String
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
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = call </> cwd _t0  ; Δ{_t0} · makes String
  let _d1000000 = call </> cwd _t2  ; Δ{_t2} · makes String
  let _d1000000 = call absPath _t0  ; Δ{_t0} · makes String
  let _d1000000 = call bnGo _t1  ; Δ{_t1} · makes String
  let _d1000000 = call colsOf _t0  ; Δ{_t0}
  let _d1000000 = call confirmYes _t0  ; Δ{_t0}
  let _d1000000 = call dispatchWait cwd sel marked prog hidden rows cols raw poff _t0  ; Δ{_t0}
  let _d1000000 = call elemBy$String p _t0  ; Δ{_t0}
  let _d1000000 = call gotoDir cwd _t0 sel marked prog hidden rows  ; Δ{_t0}
  let _d1000000 = call joinPaths cwd _t0  ; Δ{_t0} · makes String
  let _d1000000 = call joinPaths cwd _t0  ; Δ{_t0} · makes String
  let _d1000000 = call length _t0  ; Δ{_t0}
  let _d1000000 = call length _t1  ; Δ{_t1}
  let _d1000000 = call lines _t1  ; Δ{_t1} · makes List$String
  let _d1000000 = call loop cwd sel marked prog hidden rows _t0 _t1  ; Δ{_t1}
  let _d1000000 = call maybe d _t0 m  ; Δ{_t0}
  let _d1000000 = call pick 0 _t0  ; Δ{_t0} · makes String
  let _d1000000 = call qlGo _t1  ; Δ{_t1} · makes String
  let _d1000000 = call readFileTrim _t0  ; Δ{_t0} · makes String
  let _d1000000 = call reloop _t0 0 marked prog hidden rows  ; Δ{_t0}
  let _d1000000 = call reloop _t0 0 marked prog hidden rows  ; Δ{_t0}
  let _d1000000 = call rootIfEmpty _t0  ; Δ{_t0} · makes String
  let _d1000000 = call selMimeOf _t0  ; Δ{_t0} · makes String
  let _d1000000 = call stripSlash _t1  ; Δ{_t1} · makes String
  let _d1000000 = call trim _t1  ; Δ{_t1} · makes String
  let _d1000000 = call trim _t1  ; Δ{_t1} · makes String
  let _d1000000 = call trim _t1  ; Δ{_t1} · makes String
  let _d1000000 = call trim _t3  ; Δ{_t3} · makes String
  let _d1000000 = call trim _t3  ; Δ{_t3} · makes String
  let _d1000000 = call trim _t3  ; Δ{_t3} · makes String
  let _d1000000 = call trim _t5  ; Δ{_t5} · makes String
  let _d1000000 = rtcall axion_run _t0  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_run _t2  ; Δ{_t2} · makes String
  let _d1000000 = rtcall axion_strcat "  " _t3  ; Δ{_t3} · makes String
  let _d1000000 = rtcall axion_strcat " [" _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat " | tail -n +" _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat "'" _t2  ; Δ{_t2} · makes String
  let _d1000000 = rtcall axion_strcat "(" _t5  ; Δ{_t5} · makes String
  let _d1000000 = rtcall axion_strcat "/tmp/fff-bulk-" _t0  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat "bat --color=always --style=plain --paging=never --line-range " _t20  ; Δ{_t20} · makes String
  let _d1000000 = rtcall axion_strcat "command -v stty >/dev/null 2>&1 || exit 0; { exec 3</dev/tty; } 2>/dev/null || exit 0; " _t3  ; Δ{_t3} · makes String
  let _d1000000 = rtcall axion_strcat "cw=7; ch=14; [ -r \"$HOME/.cache/fff/cell\" ] && read cw ch < \"$HOME/.cache/fff/cell\"; W=$(( " _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat "for src in " _t2  ; Δ{_t2} · makes String
  let _d1000000 = rtcall axion_strcat "kitten icat --clear --stdin=no --scale-up --place=" _t10  ; Δ{_t10} · makes String
  let _d1000000 = rtcall axion_strcat "l=\"$HOME/.cache/fff/trashlog\"; [ -s \"$l\" ] || exit 0; last=$(tail -n1 \"$l\"); t=$(printf '\\t'); dest=${last%%$t*}; orig=${last#*$t}; rc=0; if [ -e \"$dest\" ]; then mkdir -p \"${orig%/*}\" && mv -- \"$dest\" \"$orig\" || rc=1; fi; sed -i '$ d' \"$l\"; exit $rc" _t0  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat "o=''; [ -r \"$HOME/.cache/fff/sort\" ] && read o < \"$HOME/.cache/fff/sort\" 2>/dev/null; fq=''; [ -r \"$HOME/.cache/fff/filter\" ] && read fq < \"$HOME/.cache/fff/filter\" 2>/dev/null; " _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat "printf '\\033[1;" _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat "src=" _t3  ; Δ{_t3} · makes String
  let _d1000000 = rtcall axion_strcat "th=\"$HOME/.cache/fff/thumb/$(printf %s " _t12  ; Δ{_t12} · makes String
  let _d1000000 = rtcall axion_strcat "th=\"$HOME/.cache/fff/thumb/$(printf %s " _t9  ; Δ{_t9} · makes String
  let _d1000000 = rtcall axion_strcat "trash " _t1  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_strcat "{ bsdtar -tf " _t7  ; Δ{_t7} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/fff/err"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/fff/fff.d"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/fff/filter"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/fff/lastq"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/fff/sort"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.local/share/fff/trash"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t2 _t14  ; Δ{_t14 _t2} · makes String
  let _d1000000 = rtcall axion_strcat _t2 _t7  ; Δ{_t2 _t7} · makes String
  let _d1000000 = rtcall axion_strcat _t3 _t11  ; Δ{_t11 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t8 "\n"  ; Δ{_t8} · makes String
  let _d1000000 = rtcall axion_strcat c _t2  ; Δ{_t2 c} · makes String
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = + poff 1  ; Δ{}
  let _t0 = + poff 1  ; Δ{}
  let _t0 = + sel 1  ; Δ{}
  let _t0 = - 0 1  ; Δ{}
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
  let _t0 = == code 0  ; Δ{}
  let _t0 = == code 0  ; Δ{}
  let _t0 = == hidden 1  ; Δ{}
  let _t0 = == i sel  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = > h 2  ; Δ{}
  let _t0 = > i hi  ; Δ{}
  let _t0 = > i lim  ; Δ{}
  let _t0 = > j 0  ; Δ{}
  let _t0 = > r mx  ; Δ{}
  let _t0 = call <=$Int n 0  ; Δ{}
  let _t0 = call <=$Int total mx  ; Δ{}
  let _t0 = call >=$Int a 0  ; Δ{}
  let _t0 = call >=$Int a 0  ; Δ{}
  let _t0 = call >=$Int a 0  ; Δ{}
  let _t0 = call >=$Int c 48  ; Δ{}
  let _t0 = call >=$Int c 65  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call baseName path  ; Δ{} · makes String
  let _t0 = call baseNames marked  ; Δ{} · makes String
  let _t0 = call cdFile 0  ; Δ{} · makes String
  let _t0 = call cmdLine "filter> " rows cwd  ; Δ{} · makes String
  let _t0 = call cmdLine "go to dir: " rows cwd  ; Δ{} · makes String
  let _t0 = call cmdLine "mkdir: " rows cwd  ; Δ{} · makes String
  let _t0 = call cmdLine "mkfile: " rows cwd  ; Δ{} · makes String
  let _t0 = call confirmKey prompt rows  ; Δ{} · makes String
  let _t0 = call csi "2J"  ; Δ{} · makes String
  let _t0 = call csi "?1049h"  ; Δ{} · makes String
  let _t0 = call csi "?25h"  ; Δ{} · makes String
  let _t0 = call dirName s  ; Δ{} · makes String
  let _t0 = call entriesRaw cwd hidden  ; Δ{} · makes List$String
  let _t0 = call entriesRaw cwd hidden  ; Δ{} · makes List$String
  let _t0 = call entriesRaw cwd hidden  ; Δ{} · makes List$String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
  let _t0 = call envOr "OLDPWD" "."  ; Δ{} · makes String
  let _t0 = call errFile 0  ; Δ{} · makes String
  let _t0 = call errRedir  ; Δ{} · makes String
  let _t0 = call esc  ; Δ{} · makes String
  let _t0 = call esc  ; Δ{} · makes String
  let _t0 = call hasImgTool 0  ; Δ{}
  let _t0 = call hasInfix "zip" m  ; Δ{}
  let _t0 = call hasPrefix "image/" mime  ; Δ{}
  let _t0 = call hasPrefix "inode/directory" mime  ; Δ{}
  let _t0 = call hasSuffix "/" raw  ; Δ{}
  let _t0 = call hasSuffix "/" s  ; Δ{}
  let _t0 = call imageExts  ; Δ{} · makes List$String
  let _t0 = call infoSize info  ; Δ{} · makes String
  let _t0 = call infoSize info  ; Δ{} · makes String
  let _t0 = call isDirPath dest  ; Δ{}
  let _t0 = call isKitty 0  ; Δ{}
  let _t0 = call lastqFile 0  ; Δ{} · makes String
  let _t0 = call lastqFile 0  ; Δ{} · makes String
  let _t0 = call lines info  ; Δ{} · makes List$String
  let _t0 = call lines info  ; Δ{} · makes List$String
  let _t0 = call lines info  ; Δ{} · makes List$String
  let _t0 = call lines m  ; Δ{} · makes List$String
  let _t0 = call lines m  ; Δ{} · makes List$String
  let _t0 = call lines m  ; Δ{} · makes List$String
  let _t0 = call lines m  ; Δ{} · makes List$String
  let _t0 = call lines raw  ; Δ{} · makes List$String
  let _t0 = call lines raw  ; Δ{} · makes List$String
  let _t0 = call lines raw  ; Δ{} · makes List$String
  let _t0 = call lines raw  ; Δ{} · makes List$String
  let _t0 = call lines raw  ; Δ{} · makes List$String
  let _t0 = call lines raw  ; Δ{} · makes List$String
  let _t0 = call lines raw  ; Δ{} · makes List$String
  let _t0 = call listWidth cols  ; Δ{}
  let _t0 = call lsCmd cwd hidden  ; Δ{} · makes String
  let _t0 = call lsCmd cwd hidden  ; Δ{} · makes String
  let _t0 = call markCount marked  ; Δ{}
  let _t0 = call markCount marked  ; Δ{}
  let _t0 = call markCount marked  ; Δ{}
  let _t0 = call markCount marked  ; Δ{}
  let _t0 = call markedHas m p  ; Δ{}
  let _t0 = call markedHas marked full  ; Δ{}
  let _t0 = call onTty 0  ; Δ{}
  let _t0 = call onTty 0  ; Δ{}
  let _t0 = call onTty 0  ; Δ{}
  let _t0 = call paneW cols  ; Δ{}
  let _t0 = call paneX cols  ; Δ{}
  let _t0 = call pickRenderer 0  ; Δ{} · makes String
  let _t0 = call pickRenderer 0  ; Δ{} · makes String
  let _t0 = call pickRenderer 0  ; Δ{} · makes String
  let _t0 = call readMainKeyTO 500  ; Δ{} · makes String
  let _t0 = call resetSeq  ; Δ{} · makes String
  let _t0 = call resetSeq  ; Δ{} · makes String
  let _t0 = call resetSeq  ; Δ{} · makes String
  let _t0 = call restoreCmd 0  ; Δ{} · makes String
  let _t0 = call scrollStep rows  ; Δ{}
  let _t0 = call scrollStep rows  ; Δ{}
  let _t0 = call selName cwd hidden sel  ; Δ{} · makes String
  let _t0 = call selName cwd hidden sel  ; Δ{} · makes String
  let _t0 = call selPath cwd hidden sel  ; Δ{} · makes String
  let _t0 = call selPath cwd hidden sel  ; Δ{} · makes String
  let _t0 = call selPath cwd hidden sel  ; Δ{} · makes String
  let _t0 = call selPath cwd hidden sel  ; Δ{} · makes String
  let _t0 = call selPathOf cwd raw sel  ; Δ{} · makes String
  let _t0 = call selPathOf cwd raw sel  ; Δ{} · makes String
  let _t0 = call shQuote d  ; Δ{} · makes String
  let _t0 = call shQuote p  ; Δ{} · makes String
  let _t0 = call shQuote p  ; Δ{} · makes String
  let _t0 = call shQuote p  ; Δ{} · makes String
  let _t0 = call shQuote path  ; Δ{} · makes String
  let _t0 = call shQuote path  ; Δ{} · makes String
  let _t0 = call shQuote path  ; Δ{} · makes String
  let _t0 = call shQuote path  ; Δ{} · makes String
  let _t0 = call shQuote path  ; Δ{} · makes String
  let _t0 = call shQuote path  ; Δ{} · makes String
  let _t0 = call shQuote path  ; Δ{} · makes String
  let _t0 = call sortFile 0  ; Δ{} · makes String
  let _t0 = call splitMin  ; Δ{}
  let _t0 = call startDirRaw a  ; Δ{} · makes String
  let _t0 = call stripSlash raw  ; Δ{} · makes String
  let _t0 = call termCols 0  ; Δ{}
  let _t0 = call termCols 0  ; Δ{}
  let _t0 = call trimStart s 0  ; Δ{}
  let _t0 = call words s  ; Δ{} · makes List$String
  let _t0 = call words sz  ; Δ{} · makes List$String
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = rtcall axion_getenv "KITTY_WINDOW_ID"  ; Δ{} · makes String
  let _t0 = rtcall axion_rand_hex 8  ; Δ{} · makes String
  let _t0 = rtcall axion_run "stty size"  ; Δ{} · makes String
  let _t0 = rtcall axion_run "stty size"  ; Δ{} · makes String
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_cmp a b  ; Δ{}
  let _t0 = rtcall axion_str_cmp b "A"  ; Δ{}
  let _t0 = rtcall axion_str_cmp k ""  ; Δ{}
  let _t0 = rtcall axion_str_cmp k ""  ; Δ{}
  let _t0 = rtcall axion_str_cmp k "y"  ; Δ{}
  let _t0 = rtcall axion_str_cmp key "J"  ; Δ{}
  let _t0 = rtcall axion_str_cmp key "j"  ; Δ{}
  let _t0 = rtcall axion_str_cmp nm "~"  ; Δ{}
  let _t0 = rtcall axion_str_cmp prog "trash"  ; Δ{}
  let _t0 = rtcall axion_str_cmp prog "trash"  ; Δ{}
  let _t0 = rtcall axion_str_cmp s "-S"  ; Δ{}
  let _t0 = rtcall axion_str_cmp x y  ; Δ{}
  let _t0 = rtcall axion_str_len a  ; Δ{}
  let _t0 = rtcall axion_str_len acc  ; Δ{}
  let _t0 = rtcall axion_str_len c  ; Δ{c}
  let _t0 = rtcall axion_str_len comp  ; Δ{}
  let _t0 = rtcall axion_str_len d  ; Δ{}
  let _t0 = rtcall axion_str_len k  ; Δ{k}
  let _t0 = rtcall axion_str_len k  ; Δ{k}
  let _t0 = rtcall axion_str_len key  ; Δ{}
  let _t0 = rtcall axion_str_len nm  ; Δ{}
  let _t0 = rtcall axion_str_len p  ; Δ{}
  let _t0 = rtcall axion_str_len q  ; Δ{}
  let _t0 = rtcall axion_str_len q  ; Δ{}
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
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len v  ; Δ{v}
  let _t0 = rtcall axion_str_len v  ; Δ{v}
  let _t0 = rtcall axion_strcat "FFF_FAV" key  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat "[ -n \"${1:-}\" ] && [ -n \"${2:-}\" ] || exit 0; sz=$(stty size <&3 2>/dev/null); rr=${sz%% *}; cc=${sz##* }; " "[ \"${rr:-0}\" -gt 0 ] && [ \"${cc:-0}\" -gt 0 ] || exit 0; cw=$(( $2 / cc )); ch=$(( $1 / rr )); [ \"$cw\" -gt 0 ] && [ \"$ch\" -gt 0 ] || exit 0; printf '%s %s' \"$cw\" \"$ch\" > \"$HOME/.cache/fff/cell\""  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat body "; done >/dev/null 2>&1 &"  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat c "m"  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat cmd " >/dev/null 2>&1"  ; Δ{} · makes String
  let _t0 = rtcall axion_system "test -t 1"  ; Δ{}
  let _t0 = showInt n  ; Δ{} · makes String
  let _t0 = showInt pw  ; Δ{} · makes String
  let _t0 = showInt pwc  ; Δ{} · makes String
  let _t0 = showInt px  ; Δ{} · makes String
  let _t0 = showInt rows  ; Δ{} · makes String
  let _t0 = showInt rows  ; Δ{} · makes String
  let _t0 = showInt rows  ; Δ{} · makes String
  let _t0 = showInt rows  ; Δ{} · makes String
  let _t1 = - cols _t0  ; Δ{}
  let _t1 = - sel 2  ; Δ{}
  let _t1 = - w _t0  ; Δ{c}
  let _t1 = < _t0 1  ; Δ{}
  let _t1 = < i _t0  ; Δ{}
  let _t1 = < k 0  ; Δ{}
  let _t1 = < p 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{k}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 cols  ; Δ{}
  let _t1 = > _t0 0  ; Δ{k}
  let _t1 = > _t0 0  ; Δ{v}
  let _t1 = > _t0 0  ; Δ{v}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 w  ; Δ{}
  let _t1 = call </> cwd _t0  ; Δ{_t0} · makes String
  let _t1 = call >=$Int cols _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call csi "2J"  ; Δ{_t0} · makes String
  let _t1 = call csi "?25l"  ; Δ{_t0} · makes String
  let _t1 = call csi "H"  ; Δ{_t0} · makes String
  let _t1 = call csi _t0  ; Δ{_t0} · makes String
  let _t1 = call elemBy$String e _t0  ; Δ{_t0}
  let _t1 = call esc  ; Δ{_t0} · makes String
  let _t1 = call filter$$nonEmpty _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = call filter$$nonEmpty _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = call filter$$nonEmpty _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = call filterFile 0  ; Δ{_t0} · makes String
  let _t1 = call firstWord _t0  ; Δ{_t0} · makes String
  let _t1 = call freshLs cwd hidden  ; Δ{} · makes String
  let _t1 = call hasSuffix "/" a  ; Δ{}
  let _t1 = call infoMtime info  ; Δ{_t0} · makes String
  let _t1 = call isDirPath _t0  ; Δ{_t0}
  let _t1 = call isExecPath _t0  ; Δ{_t0}
  let _t1 = call isSpace _t0  ; Δ{}
  let _t1 = call isTextPath _t0  ; Δ{_t0}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = call lines raw  ; Δ{_t0} · makes List$String
  let _t1 = call matchFrom _t0 q 0 0  ; Δ{_t0}
  let _t1 = call pick 0 _t0  ; Δ{_t0} · makes String
  let _t1 = call pick 1 _t0  ; Δ{_t0} · makes String
  let _t1 = call pick 1 _t0  ; Δ{_t0} · makes String
  let _t1 = call pick 2 _t0  ; Δ{_t0} · makes String
  let _t1 = call pick sel _t0  ; Δ{_t0} · makes String
  let _t1 = call pick sel _t0  ; Δ{_t0} · makes String
  let _t1 = call previewOn cols  ; Δ{}
  let _t1 = call readFileTrim _t0  ; Δ{_t0} · makes String
  let _t1 = call renderSrc cols rows  ; Δ{_t0} · makes String
  let _t1 = call selInfo _t0  ; Δ{_t0} · makes String
  let _t1 = call selPathOf cwd raw msel  ; Δ{} · makes String
  let _t1 = call shEsc s 0 _t0  ; Δ{} · makes String
  let _t1 = call shQuote _t0  ; Δ{_t0} · makes String
  let _t1 = call shQuote d  ; Δ{_t0} · makes String
  let _t1 = call shQuote path  ; Δ{_t0} · makes String
  let _t1 = call shQuote path  ; Δ{_t0} · makes String
  let _t1 = call shQuote path  ; Δ{_t0} · makes String
  let _t1 = call sixelDecode pwc phc  ; Δ{_t0} · makes String
  let _t1 = call sortFile 0  ; Δ{_t0} · makes String
  let _t1 = con Cons "aac" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = con Cons "axi" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = con Cons "heic" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = con Cons "md" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = con Cons "mpeg" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = con Cons "tgz" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = if _t0 then
  let _t1 = if _t0 then
  let _t1 = putStr _t0  ; Δ{_t0}
  let _t1 = putStr _t0  ; Δ{_t0}
  let _t1 = putStr _t0  ; Δ{_t0}
  let _t1 = rtcall axion_run _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_str_cmp _t0 "kitten"  ; Δ{_t0}
  let _t1 = rtcall axion_str_cmp _t0 "kitten"  ; Δ{_t0}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len e  ; Δ{e}
  let _t1 = rtcall axion_str_len key  ; Δ{fav}
  let _t1 = rtcall axion_str_len nm  ; Δ{_t0}
  let _t1 = rtcall axion_str_len q  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_strcat "; do " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "[" s  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "command -v " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "hw=$(printf %s \"$r\"|sed -n 's/.*4;\\([0-9]*\\);\\([0-9]*\\)t.*/\\1 \\2/p'); set -- $hw; " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "test -d " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "test -x " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " 2>/dev/null | grep -q '^text/\\|^inode/x-empty'"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " 2>/dev/null"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " 2>/dev/null"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " item(s)? [y/N] "  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " to: "  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "/.cache/fff"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "; file -bL --mime-type -- \"$f\" 2>/dev/null; o=$(stat -c '%s|%y' -- \"$f\" 2>/dev/null); s=${o%%|*}; t=${o#*|}; t=${t%%.*}; h=$(printf %s \"$s\" | numfmt --to=iec 2>/dev/null); printf '%s\\n%s\\n' \"${h:-$s}\" \"$t\""  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 ";1H"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 ";1H"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 ";1H"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 ";1H"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat acc "\n"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat cwd "\n"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t1 = rtcall axion_system _t0  ; Δ{_t0}
  let _t1 = rtcall axion_write_file tmp _t0  ; Δ{_t0}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt ph  ; Δ{_t0} · makes String
  let _t1 = showInt phc  ; Δ{_t0} · makes String
  let _t10 = call statusLine cwd total sel marked prog rows info  ; Δ{_t2 _t3 _t6 _t7 _t9} · makes String
  let _t10 = con Cons "xml" _t9  ; Δ{_t9} · moves{_t9} · makes List$String
  let _t10 = putStr _t9  ; Δ{_t9}
  let _t10 = rtcall axion_strcat "," _t9  ; Δ{_t6 _t9 rng} · makes String
  let _t10 = rtcall axion_strcat _t0 _t9  ; Δ{_t0 _t9} · makes String
  let _t10 = rtcall axion_strcat _t1 _t9  ; Δ{_t0 _t1 _t9} · makes String
  let _t10 = rtcall axion_strcat _t4 _t9  ; Δ{_t3 _t4 _t9} · makes String
  let _t11 = call paint "7" _t10  ; Δ{_t10 _t3} · makes String
  let _t11 = call shQuote path  ; Δ{rng sed} · makes String
  let _t11 = con Cons "scss" _t10  ; Δ{_t10} · moves{_t10} · makes List$String
  let _t11 = rtcall axion_strcat "|md5sum|cut -c1-32).png\"; mkdir -p \"${th%/*}\"; { [ -f \"$th\" ] && [ \"$th\" -nt " _t10  ; Δ{_t0 _t10} · makes String
  let _t11 = rtcall axion_strcat _t9 _t10  ; Δ{_t10 _t2 _t3 _t6 _t7 _t9} · makes String
  let _t12 = call shQuote sed  ; Δ{_t11 rng sed} · makes String
  let _t12 = con Cons "css" _t11  ; Δ{_t11} · moves{_t11} · makes List$String
  let _t12 = rtcall axion_strcat _t0 _t11  ; Δ{_t0 _t11} · makes String
  let _t12 = rtcall axion_strcat _t7 _t11  ; Δ{_t11 _t2 _t3 _t6 _t7} · makes String
  let _t13 = call shQuote path  ; Δ{_t11 _t12 rng} · makes String
  let _t13 = con Cons "html" _t12  ; Δ{_t12} · moves{_t12} · makes List$String
  let _t13 = rtcall axion_strcat _t6 _t12  ; Δ{_t12 _t2 _t3 _t6} · makes String
  let _t14 = con Cons "json" _t13  ; Δ{_t13} · moves{_t13} · makes List$String
  let _t14 = rtcall axion_strcat _t13 " 2>/dev/null"  ; Δ{_t11 _t12 _t13 rng} · makes String
  let _t14 = rtcall axion_strcat _t3 _t13  ; Δ{_t13 _t2 _t3} · makes String
  let _t15 = con Cons "yml" _t14  ; Δ{_t14} · moves{_t14} · makes List$String
  let _t15 = rtcall axion_strcat " -- " _t14  ; Δ{_t11 _t12 _t14 rng} · makes String
  let _t16 = con Cons "yaml" _t15  ; Δ{_t15} · moves{_t15} · makes List$String
  let _t16 = rtcall axion_strcat _t12 _t15  ; Δ{_t11 _t12 _t15 rng} · makes String
  let _t17 = con Cons "toml" _t16  ; Δ{_t16} · moves{_t16} · makes List$String
  let _t17 = rtcall axion_strcat " 2>/dev/null || sed -n " _t16  ; Δ{_t11 _t16 rng} · makes String
  let _t18 = con Cons "sql" _t17  ; Δ{_t17} · moves{_t17} · makes List$String
  let _t18 = rtcall axion_strcat _t11 _t17  ; Δ{_t11 _t17 rng} · makes String
  let _t19 = con Cons "el" _t18  ; Δ{_t18} · moves{_t18} · makes List$String
  let _t19 = rtcall axion_strcat " -- " _t18  ; Δ{_t18 rng} · makes String
  let _t2 = + j 1  ; Δ{_t1}
  let _t2 = + poff ph  ; Δ{_t1}
  let _t2 = - _t0 _t1  ; Δ{}
  let _t2 = - _t1 1  ; Δ{_t0}
  let _t2 = == _t1 0  ; Δ{e}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = > _t1 0  ; Δ{_t0}
  let _t2 = > _t1 0  ; Δ{_t0}
  let _t2 = > _t1 0  ; Δ{fav}
  let _t2 = > _t1 0  ; Δ{}
  let _t2 = > _t1 0  ; Δ{}
  let _t2 = call clampSel _t1 n  ; Δ{}
  let _t2 = call csi "2J"  ; Δ{_t0 _t1} · makes String
  let _t2 = call csi "?1049l"  ; Δ{_t0 _t1} · makes String
  let _t2 = call csi "m"  ; Δ{_t1} · makes String
  let _t2 = call csi _t1  ; Δ{_t1} · makes String
  let _t2 = call csi _t1  ; Δ{_t1} · makes String
  let _t2 = call csi _t1  ; Δ{_t1} · makes String
  let _t2 = call csi _t1  ; Δ{_t1} · makes String
  let _t2 = call imgClearSeq  ; Δ{} · makes String
  let _t2 = call length _t1  ; Δ{_t0 _t1}
  let _t2 = call lines _t1  ; Δ{_t1} · makes List$String
  let _t2 = call markChar marked _t1  ; Δ{_t1} · makes String
  let _t2 = call okOrErr _t1 "restore failed" rows  ; Δ{}
  let _t2 = call readFileTrim _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = call readInt _t1  ; Δ{_t1} · makes Maybe$Int
  let _t2 = call readInt _t1  ; Δ{_t1} · makes Maybe$Int
  let _t2 = call render cwd sel marked prog rows raw cols _t1 poff  ; Δ{_t1} · makes String
  let _t2 = call selInfo _t1  ; Δ{_t1} · makes String
  let _t2 = call shQuote cwd  ; Δ{} · makes String
  let _t2 = call shQuote path  ; Δ{_t0 _t1} · makes String
  let _t2 = call shQuote path  ; Δ{_t0 _t1} · makes String
  let _t2 = call shQuote path  ; Δ{_t0 _t1} · makes String
  let _t2 = call spaces _t1  ; Δ{c} · makes String
  let _t2 = call stripSlash _t1  ; Δ{_t1} · makes String
  let _t2 = call trimEnd s _t1  ; Δ{}
  let _t2 = call wordsFrom s j n  ; Δ{_t1} · makes List$String
  let _t2 = con Cons "ico" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = con Cons "m4a" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = con Cons "mpg" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = con Cons "nix" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = con Cons "odt" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = con Cons "zst" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = if _t1 then
  let _t2 = if _t1 then
  let _t2 = if _t1 then
  let _t2 = rtcall axion_mkdir_p _t1  ; Δ{_t1}
  let _t2 = rtcall axion_strcat "  " _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat " 2>/dev/null && pwd || printf %s " _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat "; " _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat "cat " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "f=" _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "file -bL --mime-type " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "file -bL --mime-type -- " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "r=$(dd bs=64 count=1 <&3 2>/dev/null); stty \"$old\" <&3; " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "rename " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t0 "\n"  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat _t1 " * ${ch:-14} )); k=\"$HOME/.cache/fff/sixel/$(printf %s \"$src\"|md5sum|cut -c1-32)_${W}x${H}.six\"; mkdir -p \"${k%/*}\"; if [ ! -f \"$k\" ] || [ \"$src\" -nt \"$k\" ]; then dim=$(identify -format '%wx%h' \"$src\"[0] 2>/dev/null); [ -n \"$dim\" ] || dim=$(file -bL -- \"$src\" 2>/dev/null|grep -oE '[0-9]+ ?x ?[0-9]+'|tr -d ' '|sort -t x -k1,1n|tail -1); iw=${dim%x*}; ih=${dim#*x}; if [ -n \"$dim\" ] && [ \"$((iw*H))\" -ge \"$((ih*W))\" ]; then f=\"-w $W\"; else f=\"-h $H\"; fi; [ -n \"$dim\" ] || f=\"-w $W\"; img2sixel $f -- \"$src\" >\"$k.$$.t\" 2>/dev/null && mv \"$k.$$.t\" \"$k\"; fi"  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat _t1 " >/dev/null 2>&1 &"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t1 "'"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t1 "; cat \"$k\" 2>/dev/null; printf '\\033[?25l'"  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat _t1 ";1H"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t1 "\\"  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat paths _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat prog ")"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_system _t1  ; Δ{_t1}
  let _t2 = rtcall axion_system _t1  ; Δ{_t1}
  let _t2 = rtcall axion_system _t1  ; Δ{_t1}
  let _t2 = rtcall axion_write_file _t0 _t1  ; Δ{_t0 _t1}
  let _t2 = rtcall axion_write_file _t0 _t1  ; Δ{_t0 _t1}
  let _t2 = showInt ph  ; Δ{_t1} · makes String
  let _t2 = showInt px  ; Δ{_t0 _t1} · makes String
  let _t2 = showInt total  ; Δ{_t1} · makes String
  let _t20 = con Cons "vim" _t19  ; Δ{_t19} · moves{_t19} · makes List$String
  let _t20 = rtcall axion_strcat rng _t19  ; Δ{_t19 rng} · makes String
  let _t21 = con Cons "ml" _t20  ; Δ{_t20} · moves{_t20} · makes List$String
  let _t22 = con Cons "zig" _t21  ; Δ{_t21} · moves{_t21} · makes List$String
  let _t23 = con Cons "dart" _t22  ; Δ{_t22} · moves{_t22} · makes List$String
  let _t24 = con Cons "r" _t23  ; Δ{_t23} · moves{_t23} · makes List$String
  let _t25 = con Cons "jl" _t24  ; Δ{_t24} · moves{_t24} · makes List$String
  let _t26 = con Cons "exs" _t25  ; Δ{_t25} · moves{_t25} · makes List$String
  let _t27 = con Cons "ex" _t26  ; Δ{_t26} · moves{_t26} · makes List$String
  let _t28 = con Cons "clj" _t27  ; Δ{_t27} · moves{_t27} · makes List$String
  let _t29 = con Cons "scala" _t28  ; Δ{_t28} · moves{_t28} · makes List$String
  let _t3 = + sel 4  ; Δ{}
  let _t3 = - 0 1  ; Δ{_t0}
  let _t3 = call cmdLine _t2 rows cwd  ; Δ{_t2} · makes String
  let _t3 = call csi "?25h"  ; Δ{_t2} · makes String
  let _t3 = call csi "?25h"  ; Δ{_t2} · makes String
  let _t3 = call csi "?25h"  ; Δ{_t2} · makes String
  let _t3 = call csi "?25h"  ; Δ{_t2} · makes String
  let _t3 = call csi _t2  ; Δ{_t2} · makes String
  let _t3 = call dup raw  ; Δ{_t2} · makes String
  let _t3 = call homeClear  ; Δ{_t2} · makes String
  let _t3 = call linesFrom s _t2 n  ; Δ{_t1} · makes List$String
  let _t3 = call nextSort _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = call okOrErr _t2 "paste failed" rows  ; Δ{}
  let _t3 = call pick 0 _t2  ; Δ{_t2} · makes String
  let _t3 = call render cwd msel marked prog rows raw cols _t2 0  ; Δ{_t2} · makes String
  let _t3 = call renderSrc cols rows  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = call selPath cwd hidden sel  ; Δ{} · makes String
  let _t3 = call shQuote path  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = call trimStart s 0  ; Δ{}
  let _t3 = con Cons "docx" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t3 = con Cons "m4v" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t3 = con Cons "opus" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t3 = con Cons "patch" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t3 = con Cons "rar" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t3 = con Cons "tiff" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t3 = if _t1 then
  let _t3 = if _t1 then
  let _t3 = if _t1 then
  let _t3 = if _t1 then
  let _t3 = putStr _t2  ; Δ{_t1 _t2}
  let _t3 = rtcall axion_run _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_run _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_strcat " * ${cw:-7} )); H=$(( " _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat " | head -n " _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_strcat "H'; " _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat "] (" _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_strcat "_Ga=d,d=A" _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat "nohup xdg-open " _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_strcat "old=$(stty -g <&3) || exit 0; stty raw -echo min 0 time 1 <&3; printf '\\033[14t' >/dev/tty; " _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat _t1 _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_strcat _t1 _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_strcat _t2 " 2>/dev/null | { if [ -n \"$fq\" ]; then grep -iF -- \"$fq\"; else cat; fi; }"  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_strcat _t2 ")"  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_strcat _t2 "; } 2>/dev/null"  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_strcat s _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_substr 1 _t2 nm  ; Δ{_t0} · makes String
  let _t3 = rtcall axion_system _t2  ; Δ{_t2}
  let _t3 = rtcall axion_write_file _t1 _t2  ; Δ{_t1 _t2}
  let _t3 = showInt _t2  ; Δ{_t1} · makes String
  let _t3 = showInt py  ; Δ{_t0 _t1 _t2} · makes String
  let _t30 = con Cons "swift" _t29  ; Δ{_t29} · moves{_t29} · makes List$String
  let _t31 = con Cons "kt" _t30  ; Δ{_t30} · moves{_t30} · makes List$String
  let _t32 = con Cons "php" _t31  ; Δ{_t31} · moves{_t31} · makes List$String
  let _t33 = con Cons "pl" _t32  ; Δ{_t32} · moves{_t32} · makes List$String
  let _t34 = con Cons "lua" _t33  ; Δ{_t33} · moves{_t33} · makes List$String
  let _t35 = con Cons "rb" _t34  ; Δ{_t34} · moves{_t34} · makes List$String
  let _t36 = con Cons "java" _t35  ; Δ{_t35} · moves{_t35} · makes List$String
  let _t37 = con Cons "nu" _t36  ; Δ{_t36} · moves{_t36} · makes List$String
  let _t38 = con Cons "fish" _t37  ; Δ{_t37} · moves{_t37} · makes List$String
  let _t39 = con Cons "zsh" _t38  ; Δ{_t38} · moves{_t38} · makes List$String
  let _t4 = - _t2 _t3  ; Δ{}
  let _t4 = call clampSel _t3 n  ; Δ{}
  let _t4 = call csi "K"  ; Δ{_t2 _t3} · makes String
  let _t4 = call csi "K"  ; Δ{_t2 _t3} · makes String
  let _t4 = call csi "K"  ; Δ{_t2 _t3} · makes String
  let _t4 = call csi "K"  ; Δ{_t2 _t3} · makes String
  let _t4 = call lines raw  ; Δ{_t2 _t3} · makes List$String
  let _t4 = call matchBefore _t0 q 0 _t2 _t3  ; Δ{_t0}
  let _t4 = call posStr sel total  ; Δ{_t3} · makes String
  let _t4 = call renderSrc cols rows  ; Δ{_t0 _t1 _t2 _t3} · makes String
  let _t4 = call shQuote _t3  ; Δ{_t3} · makes String
  let _t4 = con Cons "7z" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t4 = con Cons "diff" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t4 = con Cons "doc" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t4 = con Cons "ogg" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t4 = con Cons "svg" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t4 = con Cons "wmv" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t4 = if _t2 then
  let _t4 = if _t2 then
  let _t4 = if _t2 then
  let _t4 = putStr _t3  ; Δ{_t3}
  let _t4 = rtcall axion_str_len _t3  ; Δ{_t3}
  let _t4 = rtcall axion_strcat " " _t3  ; Δ{_t2 _t3} · makes String
  let _t4 = rtcall axion_strcat " \"${th%.png}\" 2>/dev/null; src=\"$th\"; " _t3  ; Δ{_t0 _t1 _t2 _t3} · makes String
  let _t4 = rtcall axion_strcat " || unzip -l " _t3  ; Δ{_t0 _t1 _t3} · makes String
  let _t4 = rtcall axion_strcat "/" _t3  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat ":" _t3  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat "cd -- " _t3  ; Δ{_t3} · makes String
  let _t4 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _t4 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t3} · makes String
  let _t4 = rtcall axion_strcat _t3 " -- \"$src\"; printf '\\033[?25l'"  ; Δ{_t0 _t1 _t2 _t3} · makes String
  let _t4 = rtcall axion_strcat _t3 "\n"  ; Δ{_t0 _t3} · makes String
  let _t4 = rtcall axion_system _t3  ; Δ{_t3}
  let _t40 = con Cons "bash" _t39  ; Δ{_t39} · moves{_t39} · makes List$String
  let _t41 = con Cons "sh" _t40  ; Δ{_t40} · moves{_t40} · makes List$String
  let _t42 = con Cons "hs" _t41  ; Δ{_t41} · moves{_t41} · makes List$String
  let _t43 = con Cons "go" _t42  ; Δ{_t42} · moves{_t42} · makes List$String
  let _t44 = con Cons "tsx" _t43  ; Δ{_t43} · moves{_t43} · makes List$String
  let _t45 = con Cons "jsx" _t44  ; Δ{_t44} · moves{_t44} · makes List$String
  let _t46 = con Cons "ts" _t45  ; Δ{_t45} · moves{_t45} · makes List$String
  let _t47 = con Cons "js" _t46  ; Δ{_t46} · moves{_t46} · makes List$String
  let _t48 = con Cons "py" _t47  ; Δ{_t47} · moves{_t47} · makes List$String
  let _t49 = con Cons "rs" _t48  ; Δ{_t48} · moves{_t48} · makes List$String
  let _t5 = + poff 1  ; Δ{rng}
  let _t5 = + start mx  ; Δ{_t2 _t3 _t4}
  let _t5 = > _t4 0  ; Δ{_t3}
  let _t5 = call errRedir  ; Δ{_t4} · makes String
  let _t5 = call markSeg marked prog  ; Δ{_t3 _t4} · makes String
  let _t5 = call okOr _t4 "mkdir failed" rows  ; Δ{}
  let _t5 = call okOr _t4 "mkfile failed" rows  ; Δ{}
  let _t5 = call paint "1;31" msg  ; Δ{_t2 _t3 _t4} · makes String
  let _t5 = con Cons "bz2" _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t5 = con Cons "conf" _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t5 = con Cons "djvu" _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t5 = con Cons "flv" _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t5 = con Cons "wav" _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t5 = con Cons "webp" _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t5 = if _t0 then
  let _t5 = if _t0 then
  let _t5 = rtcall axion_run _t4  ; Δ{_t4} · makes String
  let _t5 = rtcall axion_strcat " -frames:v 1 -vf scale=512:-1 \"$th\" 2>/dev/null; src=\"$th\"; " _t4  ; Δ{_t0 _t1 _t2 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat "/" acc  ; Δ{_t2 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat "x" _t4  ; Δ{_t0 _t1 _t2 _t4} · makes String
  let _t5 = rtcall axion_strcat _t1 _t4  ; Δ{_t0 _t1 _t4} · makes String
  let _t5 = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
  let _t5 = rtcall axion_strcat _t2 _t4  ; Δ{_t0 _t1 _t2 _t4} · makes String
  let _t5 = rtcall axion_strcat _t2 _t4  ; Δ{_t2 _t4} · makes String
  let _t5 = rtcall axion_strcat _t4 prompt  ; Δ{_t2 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat prompt acc  ; Δ{_t2 _t3 _t4} · makes String
  let _t5 = rtcall axion_write_file _t0 _t4  ; Δ{_t0 _t4}
  let _t50 = con Cons "cc" _t49  ; Δ{_t49} · moves{_t49} · makes List$String
  let _t51 = con Cons "hpp" _t50  ; Δ{_t50} · moves{_t50} · makes List$String
  let _t52 = con Cons "cpp" _t51  ; Δ{_t51} · moves{_t51} · makes List$String
  let _t53 = con Cons "h" _t52  ; Δ{_t52} · moves{_t52} · makes List$String
  let _t6 = call drawRows _t4 0 start _t5 sel marked cwd lw prev  ; Δ{_t2 _t3 _t4} · makes String
  let _t6 = call metaSeg info  ; Δ{_t3 _t4 _t5} · makes String
  let _t6 = call sizedCell _t5 listW prev  ; Δ{_t5} · makes String
  let _t6 = con Cons "avi" _t5  ; Δ{_t5} · moves{_t5} · makes List$String
  let _t6 = con Cons "bmp" _t5  ; Δ{_t5} · moves{_t5} · makes List$String
  let _t6 = con Cons "cfg" _t5  ; Δ{_t5} · moves{_t5} · makes List$String
  let _t6 = con Cons "epub" _t5  ; Δ{_t5} · moves{_t5} · makes List$String
  let _t6 = con Cons "flac" _t5  ; Δ{_t5} · moves{_t5} · makes List$String
  let _t6 = con Cons "xz" _t5  ; Δ{_t5} · moves{_t5} · makes List$String
  let _t6 = rtcall axion_strcat " ]; } || pdftoppm -png -f 1 -l 1 -r 96 -singlefile " _t5  ; Δ{_t0 _t1 _t5} · makes String
  let _t6 = rtcall axion_strcat " || tar -tf " _t5  ; Δ{_t0 _t5} · makes String
  let _t6 = rtcall axion_strcat _t2 _t5  ; Δ{_t0 _t1 _t2 _t5} · makes String
  let _t6 = rtcall axion_strcat _t3 _t5  ; Δ{_t0 _t1 _t2 _t3 _t5} · makes String
  let _t6 = rtcall axion_strcat _t3 _t5  ; Δ{_t2 _t3 _t5} · makes String
  let _t6 = rtcall axion_strcat _t4 _t5  ; Δ{_t2 _t3 _t4 _t5} · makes String
  let _t6 = rtcall axion_strcat _t4 _t5  ; Δ{_t2 _t3 _t4 _t5} · makes String
  let _t6 = rtcall axion_strcat _t4 _t5  ; Δ{_t4 _t5} · makes String
  let _t6 = rtcall axion_strcat _t5 "  —  any key"  ; Δ{_t2 _t3 _t4 _t5} · makes String
  let _t6 = showInt _t5  ; Δ{rng} · makes String
  let _t7 = + poff ph  ; Δ{_t6 rng}
  let _t7 = call entryColor raw  ; Δ{_t6} · makes String
  let _t7 = call sepSeg lw mx prev  ; Δ{_t2 _t3 _t6} · makes String
  let _t7 = con Cons "gif" _t6  ; Δ{_t6} · moves{_t6} · makes List$String
  let _t7 = con Cons "gz" _t6  ; Δ{_t6} · moves{_t6} · makes List$String
  let _t7 = con Cons "ini" _t6  ; Δ{_t6} · moves{_t6} · makes List$String
  let _t7 = con Cons "mov" _t6  ; Δ{_t6} · moves{_t6} · makes List$String
  let _t7 = rtcall axion_strcat " " cwd  ; Δ{_t3 _t4 _t5 _t6} · makes String
  let _t7 = rtcall axion_strcat " -o \"$th\" -s 512 2>/dev/null || ffmpeg -y -ss 1 -i " _t6  ; Δ{_t0 _t1 _t2 _t6} · makes String
  let _t7 = rtcall axion_strcat "@" _t6  ; Δ{_t0 _t1 _t6} · makes String
  let _t7 = rtcall axion_strcat _t0 _t6  ; Δ{_t0 _t6} · makes String
  let _t7 = rtcall axion_strcat _t1 _t6  ; Δ{_t0 _t1 _t6} · makes String
  let _t7 = rtcall axion_strcat _t2 _t6  ; Δ{_t2 _t6} · makes String
  let _t7 = rtcall axion_strcat _t2 _t6  ; Δ{_t6} · makes String
  let _t7 = rtcall axion_strcat _t3 _t6  ; Δ{_t2 _t3 _t6} · makes String
  let _t7 = rtcall axion_strcat _t3 _t6  ; Δ{_t2 _t3 _t6} · makes String
  let _t7 = rtcall axion_strcat _t4 _t6  ; Δ{_t2 _t3 _t4 _t6} · makes String
  let _t8 = call colorCell _t6 i sel _t7  ; Δ{_t6 _t7} · makes String
  let _t8 = call infoMime info  ; Δ{_t2 _t3 _t6 _t7} · makes String
  let _t8 = con Cons "hcl" _t7  ; Δ{_t7} · moves{_t7} · makes List$String
  let _t8 = con Cons "png" _t7  ; Δ{_t7} · moves{_t7} · makes List$String
  let _t8 = con Cons "tar" _t7  ; Δ{_t7} · moves{_t7} · makes List$String
  let _t8 = con Cons "webm" _t7  ; Δ{_t7} · moves{_t7} · makes List$String
  let _t8 = if _t2 then
  let _t8 = if _t5 then
  let _t8 = putStr _t7  ; Δ{_t7}
  let _t8 = rtcall axion_strcat "|md5sum|cut -c1-32).png\"; mkdir -p \"${th%/*}\"; { [ -f \"$th\" ] && [ \"$th\" -nt " _t7  ; Δ{_t0 _t7} · makes String
  let _t8 = rtcall axion_strcat _t1 _t7  ; Δ{_t0 _t1 _t7} · makes String
  let _t8 = rtcall axion_strcat _t2 _t7  ; Δ{_t0 _t1 _t2 _t7} · makes String
  let _t8 = rtcall axion_strcat _t2 _t7  ; Δ{_t2 _t7} · makes String
  let _t8 = rtcall axion_strcat _t3 _t7  ; Δ{_t2 _t3 _t7} · makes String
  let _t8 = rtcall axion_strcat _t6 _t7  ; Δ{_t3 _t4 _t5 _t6 _t7} · makes String
  let _t8 = rtcall axion_system _t7  ; Δ{_t7}
  let _t8 = showInt _t7  ; Δ{_t6 rng} · makes String
  let _t9 = call okOr _t8 "rename failed" rows  ; Δ{}
  let _t9 = call okOrErr _t8 "chmod failed" rows  ; Δ{}
  let _t9 = call previewSeg cwd sel raw cols mx prev _t8 poff  ; Δ{_t2 _t3 _t6 _t7 _t8} · makes String
  let _t9 = con Cons "jpeg" _t8  ; Δ{_t8} · moves{_t8} · makes List$String
  let _t9 = con Cons "mkv" _t8  ; Δ{_t8} · moves{_t8} · makes List$String
  let _t9 = con Cons "tf" _t8  ; Δ{_t8} · moves{_t8} · makes List$String
  let _t9 = putStr _t8  ; Δ{_t8}
  let _t9 = rtcall axion_strcat " ]; } || ffmpegthumbnailer -i " _t8  ; Δ{_t0 _t1 _t8} · makes String
  let _t9 = rtcall axion_strcat "x" _t8  ; Δ{_t0 _t8} · makes String
  let _t9 = rtcall axion_strcat _t0 _t8  ; Δ{_t0 _t8} · makes String
  let _t9 = rtcall axion_strcat _t2 _t8  ; Δ{_t2 _t8} · makes String
  let _t9 = rtcall axion_strcat _t5 _t8  ; Δ{_t3 _t4 _t5 _t8} · makes String
  let _t9 = rtcall axion_strcat _t8 "p"  ; Δ{_t6 _t8 rng} · makes String
  let c = call clip s w  ; Δ{} · makes String
  let e = call extOf _t0  ; Δ{_t0} · makes String
  let fav = rtcall axion_getenv _t0  ; Δ{_t0} · makes String
  let h = call maxItems rows  ; Δ{}
  let k = call lastIndex 46 s 0 _t0  ; Δ{}
  let k = rtcall axion_read_key 0  ; Δ{} · makes String
  let k = rtcall axion_read_key_timeout ms  ; Δ{} · makes String
  let lw = call listWidth cols  ; Δ{}
  let msel = call searchSel _t0 acc osel  ; Δ{_t0}
  let mx = call maxItems rows  ; Δ{}
  let n = call length _t0  ; Δ{_t0}
  let p = - poff _t0  ; Δ{}
  let prev = if _t1 then
  let rng = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
  let sed = rtcall axion_strcat _t6 _t10  ; Δ{_t10 _t6 rng} · makes String
  let start = call viewStart sel total mx  ; Δ{}
  let total = call length _t0  ; Δ{_t0}
  let v = rtcall axion_getenv "VISUAL"  ; Δ{} · makes String
  let v = rtcall axion_getenv name  ; Δ{} · makes String
  ret " 2>\"$HOME/.cache/fff/err\""  ; Δ{}
  ret "\u{1b}"  ; Δ{}
  ret + _t0 2  ; Δ{}
  ret + _t1 1  ; Δ{}
  ret + poff _t0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 60  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret == _t2 0  ; Δ{}
  ret == _t2 0  ; Δ{}
  ret == _t2 0  ; Δ{}
  ret == _t3 0  ; Δ{}
  ret > _t0 0  ; Δ{}
  ret > _t0 4  ; Δ{}
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
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call baseAfter s _t1  ; Δ{} · makes String
  ret call clampNeg _t1 from  ; Δ{}
  ret call clampNeg _t4 from  ; Δ{}
  ret call clipGo s 0 _t0 0 w  ; Δ{} · makes String
  ret call cmdGo prompt rows cwd ""  ; Δ{} · makes String
  ret call dirBefore s _t1  ; Δ{} · makes String
  ret call fromMaybe 24 _t2  ; Δ{_t2} · moves{_t2}
  ret call fromMaybe 80 _t2  ; Δ{_t2} · moves{_t2}
  ret call infixGo q s 0 _t2  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call linesFrom s 0 _t0  ; Δ{} · makes List$String
  ret call loopAt cwd sel marked prog hidden rows cols raw 0  ; Δ{}
  ret call not _t1  ; Δ{}
  ret call searchLoop cwd sel marked prog hidden rows cols raw sel ""  ; Δ{}
  ret call sepGo col 1 mx  ; Δ{} · makes String
  ret call toLowerGo s 0 _t0  ; Δ{} · makes String
  ret call windowGo cwd raw lo hi ""  ; Δ{} · makes String
  ret call windowPaths cwd raw _t2 _t4  ; Δ{} · makes String
  ret call wordsFrom s 0 _t0  ; Δ{} · makes List$String
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t10 of
  ret case _t2 of
  ret case _t2 of
  ret case _t2 of
  ret case _t2 of
  ret case _t3 of
  ret case _t3 of
  ret case _t3 of
  ret case _t3 of
  ret case _t4 of
  ret case _t4 of
  ret case _t5 of
  ret case _t5 of
  ret case _t5 of
  ret case _t8 of
  ret case _t9 of
  ret case _t9 of
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
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Cons "c" _t53  ; Δ{_t53} · moves{_t53} · makes List$String
  ret con Cons "jpg" _t9  ; Δ{_t9} · moves{_t9} · makes List$String
  ret con Cons "mp3" _t6  ; Δ{_t6} · moves{_t6} · makes List$String
  ret con Cons "mp4" _t9  ; Δ{_t9} · moves{_t9} · makes List$String
  ret con Cons "pdf" _t6  ; Δ{_t6} · moves{_t6} · makes List$String
  ret con Cons "zip" _t8  ; Δ{_t8} · moves{_t8} · makes List$String
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
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t3 then
  ret if _t3 then
  ret if _t3 then
  ret if _t4 then
  ret if _t5 then
  ret if _t5 then
  ret if _t8 then
  ret if b then
  ret if prev then
  ret if prev then
  ret if prev then
  ret if yes then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_substr 0 _t0 s  ; Δ{} · makes String
  ret rtcall axion_substr _t0 _t4 s  ; Δ{} · makes String
  ret x  ; Δ{}
</> a b  =
<=$Int x y  =
>=$Int x y  =
absPath d  =
allPaths cwd hidden  =
allPathsOf cwd raw  =
archiveExts  =
archiveList path  =
arrowKey b  =
audioExts  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$Int _p  =
baseAfter s k  =
baseName s  =
baseNames m  =
bnGo xs  =
bottomMatch raw q from  =
bulkApply olds news cwd  =
bulkRun cwd marked tmp  =
bulkTmp d  =
cdFile d  =
clampNeg a from  =
clampSel i n  =
clip s w  =
clipAnsi s w  =
clipGo s i n vis w  =
cmdGo prompt rows cwd acc  =
cmdKey prompt rows cwd acc k  =
cmdLine prompt rows cwd  =
codeExts  =
codePreviewCmd path poff ph  =
colorCell cell i sel col  =
colorForExt e  =
colsOf sz  =
confirm prompt rows  =
confirmKey prompt rows  =
confirmYes k  =
consLine s i n j  =
consWord s i n j  =
csi s  =
dirBefore s k  =
dirName s  =
dispatchWait cwd sel marked prog hidden rows cols raw poff key  =
doAttr cwd sel marked prog hidden rows  =
doBulk cwd sel marked prog hidden rows  =
doChmod cwd sel marked prog hidden rows  =
doFilter cwd sel marked prog hidden rows  =
doGoDir cwd sel marked prog hidden rows  =
doMkdir cwd sel marked prog hidden rows  =
doMkfile cwd sel marked prog hidden rows  =
doPaste cwd sel marked prog hidden rows  =
doPasteRun cwd sel marked prog hidden rows  =
doRename cwd sel marked prog hidden rows  =
doRestore cwd sel marked prog hidden rows  =
doSearch cwd sel marked prog hidden rows cols raw  =
doShell cwd sel marked prog hidden rows  =
doSort cwd sel marked prog hidden rows  =
docExts  =
drawLines xs r px pw maxRow  =
drawLinesAnsi xs r px pw maxRow  =
drawPreview path px pw ph mime poff  =
drawRows xs i start endIdx sel marked cwd listW prev  =
drawSep col mx  =
dropLast s  =
dup s  =
dupOrAcc comp acc  =
editorCmd d  =
elemBy$String x xs  =
endSearch cwd marked prog hidden rows cols raw acc msel  =
entriesRaw cwd hidden  =
entryColor raw  =
envOr name dflt  =
eq$String x y  =
errDetail d  =
errFile d  =
errRedir  =
esc  =
escEnd s i n  =
escFinal s i n  =
expandDir cwd nm  =
extOf s  =
favOrIgnore cwd sel marked prog hidden rows key  =
filter$$neStr _cap0 xs  =
filter$$nonEmpty xs  =
filterFile d  =
findChar c s i n  =
firstPrefix xs q  =
firstWord s  =
fit s w  =
flashFail msg rows  =
freshLs cwd hidden  =
fromMaybe d m  =
goHome marked prog hidden rows  =
goPrev marked prog hidden rows  =
gotoDir cwd nm sel marked prog hidden rows  =
gotoTo cwd sel marked prog hidden rows dest  =
hasImgTool d  =
hasInfix q s  =
hasPrefix p s  =
hasSuffix q s  =
have cmd  =
homeClear  =
icatCmd path cols rows  =
imageExts  =
imgClearSeq  =
infixGo q s i lim  =
infoMime info  =
infoMtime info  =
infoSize info  =
isArchiveMime m  =
isDigit c  =
isDirPath p  =
isExecPath p  =
isKitty d  =
isSpace c  =
isTextPath p  =
joinPaths cwd xs  =
kittenRenderSrc pw ph px py  =
lam$0 [env ]x  =
lastIndex c s i best  =
lastqFile d  =
le$Int x y  =
length xs  =
lines s  =
linesFrom s i n  =
listWidth cols  =
loop cwd sel marked prog hidden rows cols raw  =
loopAt cwd sel marked prog hidden rows cols raw poff  =
lowerChar c  =
lsCmd cwd hidden  =
main  =
markChar marked full  =
markCount m  =
markInfo marked prog  =
markSeg marked prog  =
markToggle m p  =
markedHas m p  =
matchBefore xs q i hi best  =
matchFrom xs q i lo  =
matchIndex xs q i dflt  =
maxItems rows  =
maybe d f m  =
metaSeg info  =
metaShow info  =
nEntries cwd hidden  =
neStr a b  =
nextOrTop raw q from a  =
nextSort s  =
nonEmpty s  =
not b  =
okOr code label rows  =
okOrErr code label rows  =
onTty d  =
open cwd sel marked prog hidden rows raw  =
openFile cwd sel marked prog hidden rows  =
openOther cwd sel marked prog hidden rows  =
openText cwd sel marked prog hidden rows  =
paint c s  =
paneW cols  =
paneX cols  =
parentDir s  =
pasteIfYes cwd sel marked prog hidden rows yes  =
pdfCmd path cols rows  =
pick i xs  =
pickRenderer d  =
pixHeader label path mime px pw ph  =
pollKey cwd sel marked prog hidden rows cols raw poff  =
posStr sel total  =
prefetch cwd sel rows raw cols  =
prefetchCmd cwd sel rows raw cols  =
prevOrBottom raw q from a  =
previewImage cwd sel rows raw cols mime  =
previewOn cols  =
previewPix path cols rows mime  =
previewSeg cwd sel raw cols mx prev mime poff  =
qlGo xs  =
queryCell d  =
quit cwd  =
quoteLines m  =
readFileTrim path  =
readInt s  =
readIntGo s i acc  =
readLastQ d  =
readMainKey dummy  =
readMainKeyTO ms  =
reloop cwd sel marked prog hidden rows  =
render cwd sel marked prog rows raw cols info poff  =
renderSrc cols rows  =
resetSeq  =
resizeCheck cwd sel marked prog hidden rows cols raw poff  =
restoreCmd d  =
rootIfEmpty d  =
rowFor raw i sel marked cwd listW prev  =
runPaste cwd marked prog  =
scrollDown poff rows  =
scrollPipe poff ph  =
scrollStep rows  =
scrollUp poff rows  =
searchKey cwd sel marked prog hidden rows cols raw osel acc k  =
searchLoop cwd sel marked prog hidden rows cols raw osel acc  =
searchNext raw q from  =
searchPrev raw q from  =
searchPrompt rows acc  =
searchSel xs acc dflt  =
selInfo path  =
selMime cwd hidden sel  =
selMimeOf path  =
selName cwd hidden sel  =
selPath cwd hidden sel  =
selPathOf cwd raw sel  =
sepGo col r mx  =
sepSeg lw mx prev  =
setupSeq  =
shEsc s i n  =
shQuote s  =
sixelDecode pwc phc  =
sixelRenderSrc px pwc phc  =
sizedCell plain listW prev  =
sortFile d  =
spaces n  =
splitMin  =
startDir a  =
startDirRaw a  =
statusLine cwd total sel marked prog rows info  =
step cwd sel marked prog hidden rows cols raw key  =
stepAt cwd sel marked prog hidden rows cols raw poff key  =
stripSlash s  =
termCols dummy  =
termRows dummy  =
textPreview path px pw ph poff  =
tildeExpand nm  =
toLower s  =
toLowerGo s i n  =
topMatch raw q from  =
trashDir d  =
trashPrompt n  =
trim s  =
trimEnd s j  =
trimStart s i  =
unlines xs  =
videoCmd path cols rows  =
videoExts  =
viewStart sel total mx  =
waitKey cwd sel marked prog hidden rows cols raw poff  =
warmLoop paths body  =
winPaths cwd sel raw  =
windowGo cwd raw i hi acc  =
windowPaths cwd raw lo hi  =
wordEnd s i n  =
words s  =
wordsFrom s i n  =
wordsStep s i n  =
wrapSel i n  =
