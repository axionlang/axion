































































































































































































































































































































































































































                                                                                                ret call countLoop cwd sel marked prog hidden rows cols raw key  ; Δ{}
                                                                                                ret call favOrIgnore cwd sel marked prog hidden rows key  ; Δ{}
                                                                                              else
                                                                                              let _t125 = call digitStart key  ; Δ{}
                                                                                              ret ""  ; Δ{}
                                                                                              ret "K"  ; Δ{}
                                                                                              ret call quit cwd  ; Δ{}
                                                                                              ret if _t125 then
                                                                                            else
                                                                                            else
                                                                                            let _t123 = rtcall axion_str_cmp key ""  ; Δ{}
                                                                                            let _t124 = == _t123 0  ; Δ{}
                                                                                            let _t90 = rtcall axion_str_cmp a "scrollUp"  ; Δ{}
                                                                                            let _t91 = == _t90 0  ; Δ{}
                                                                                            ret "J"  ; Δ{}
                                                                                            ret call quit cwd  ; Δ{}
                                                                                            ret if _t124 then
                                                                                            ret if _t91 then
                                                                                          else
                                                                                          else
                                                                                          let _t121 = rtcall axion_str_cmp key "\u{1b}"  ; Δ{}
                                                                                          let _t122 = == _t121 0  ; Δ{}
                                                                                          let _t88 = rtcall axion_str_cmp a "scrollDown"  ; Δ{}
                                                                                          let _t89 = == _t88 0  ; Δ{}
                                                                                          ret "q"  ; Δ{}
                                                                                          ret call quit cwd  ; Δ{}
                                                                                          ret if _t122 then
                                                                                          ret if _t89 then
                                                                                        drop _t117 : String
                                                                                        else
                                                                                        else
                                                                                        let _t117 = call readLastQ 0  ; Δ{} · makes String
                                                                                        let _t118 = call searchPrev raw _t117 sel  ; Δ{_t117}
                                                                                        let _t119 = rtcall axion_str_cmp key "q"  ; Δ{}
                                                                                        let _t120 = == _t119 0  ; Δ{}
                                                                                        let _t86 = rtcall axion_str_cmp a "quit"  ; Δ{}
                                                                                        let _t87 = == _t86 0  ; Δ{}
                                                                                        ret "?"  ; Δ{}
                                                                                        ret call loop cwd _t118 marked prog hidden rows cols raw  ; Δ{}
                                                                                        ret if _t120 then
                                                                                        ret if _t87 then
                                                                                      drop _t113 : String
                                                                                      else
                                                                                      else
                                                                                      let _t113 = call readLastQ 0  ; Δ{} · makes String
                                                                                      let _t114 = call searchNext raw _t113 sel  ; Δ{_t113}
                                                                                      let _t115 = rtcall axion_str_cmp key ","  ; Δ{}
                                                                                      let _t116 = == _t115 0  ; Δ{}
                                                                                      let _t84 = rtcall axion_str_cmp a "doHelp"  ; Δ{}
                                                                                      let _t85 = == _t84 0  ; Δ{}
                                                                                      ret "["  ; Δ{}
                                                                                      ret call loop cwd _t114 marked prog hidden rows cols raw  ; Δ{}
                                                                                      ret if _t116 then
                                                                                      ret if _t85 then
                                                                                    else
                                                                                    else
                                                                                    let _t111 = rtcall axion_str_cmp key ";"  ; Δ{}
                                                                                    let _t112 = == _t111 0  ; Δ{}
                                                                                    let _t82 = rtcall axion_str_cmp a "doTabPrev"  ; Δ{}
                                                                                    let _t83 = == _t82 0  ; Δ{}
                                                                                    ret "]"  ; Δ{}
                                                                                    ret call doHelp cwd sel marked prog hidden rows  ; Δ{}
                                                                                    ret if _t112 then
                                                                                    ret if _t83 then
                                                                                  else
                                                                                  else
                                                                                  let _t109 = rtcall axion_str_cmp key "?"  ; Δ{}
                                                                                  let _t110 = == _t109 0  ; Δ{}
                                                                                  let _t80 = rtcall axion_str_cmp a "doTabNext"  ; Δ{}
                                                                                  let _t81 = == _t80 0  ; Δ{}
                                                                                  ret "T"  ; Δ{}
                                                                                  ret call doTabPrev cwd sel marked prog hidden rows  ; Δ{}
                                                                                  ret if _t110 then
                                                                                  ret if _t81 then
                                                                                else
                                                                                else
                                                                                let _t107 = rtcall axion_str_cmp key "["  ; Δ{}
                                                                                let _t108 = == _t107 0  ; Δ{}
                                                                                let _t78 = rtcall axion_str_cmp a "doTabClose"  ; Δ{}
                                                                                let _t79 = == _t78 0  ; Δ{}
                                                                                ret "t"  ; Δ{}
                                                                                ret call doTabNext cwd sel marked prog hidden rows  ; Δ{}
                                                                                ret if _t108 then
                                                                                ret if _t79 then
                                                                              else
                                                                              else
                                                                              let _t105 = rtcall axion_str_cmp key "]"  ; Δ{}
                                                                              let _t106 = == _t105 0  ; Δ{}
                                                                              let _t76 = rtcall axion_str_cmp a "doTabNew"  ; Δ{}
                                                                              let _t77 = == _t76 0  ; Δ{}
                                                                              ret "B"  ; Δ{}
                                                                              ret call doTabClose cwd sel marked prog hidden rows  ; Δ{}
                                                                              ret if _t106 then
                                                                              ret if _t77 then
                                                                            else
                                                                            else
                                                                            let _t103 = rtcall axion_str_cmp key "T"  ; Δ{}
                                                                            let _t104 = == _t103 0  ; Δ{}
                                                                            let _t74 = rtcall axion_str_cmp a "doJumpMark"  ; Δ{}
                                                                            let _t75 = == _t74 0  ; Δ{}
                                                                            ret "b"  ; Δ{}
                                                                            ret call doTabNew cwd sel marked prog hidden rows  ; Δ{}
                                                                            ret if _t104 then
                                                                            ret if _t75 then
                                                                          else
                                                                          else
                                                                          let _t101 = rtcall axion_str_cmp key "t"  ; Δ{}
                                                                          let _t102 = == _t101 0  ; Δ{}
                                                                          let _t72 = rtcall axion_str_cmp a "doSetMark"  ; Δ{}
                                                                          let _t73 = == _t72 0  ; Δ{}
                                                                          ret "i"  ; Δ{}
                                                                          ret call doJumpMark cwd sel marked prog hidden rows  ; Δ{}
                                                                          ret if _t102 then
                                                                          ret if _t73 then
                                                                        else
                                                                        else
                                                                        let _t100 = == _t99 0  ; Δ{}
                                                                        let _t70 = rtcall axion_str_cmp a "doDiskUsage"  ; Δ{}
                                                                        let _t71 = == _t70 0  ; Δ{}
                                                                        let _t99 = rtcall axion_str_cmp key "B"  ; Δ{}
                                                                        ret "P"  ; Δ{}
                                                                        ret call doSetMark cwd sel marked prog hidden rows  ; Δ{}
                                                                        ret if _t100 then
                                                                        ret if _t71 then
                                                                      else
                                                                      else
                                                                      let _t68 = rtcall axion_str_cmp a "doCopyPath"  ; Δ{}
                                                                      let _t69 = == _t68 0  ; Δ{}
                                                                      let _t97 = rtcall axion_str_cmp key "b"  ; Δ{}
                                                                      let _t98 = == _t97 0  ; Δ{}
                                                                      ret "u"  ; Δ{}
                                                                      ret call doDiskUsage cwd sel marked prog hidden rows cols raw  ; Δ{}
                                                                      ret if _t69 then
                                                                      ret if _t98 then
                                                                    else
                                                                    else
                                                                    let _t66 = rtcall axion_str_cmp a "doRestore"  ; Δ{}
                                                                    let _t67 = == _t66 0  ; Δ{}
                                                                    let _t95 = rtcall axion_str_cmp key "i"  ; Δ{}
                                                                    let _t96 = == _t95 0  ; Δ{}
                                                                    ret "F"  ; Δ{}
                                                                    ret call doCopyPath cwd sel marked prog hidden rows cols raw  ; Δ{}
                                                                    ret if _t67 then
                                                                    ret if _t96 then
                                                                  else
                                                                  else
                                                                  let _t64 = rtcall axion_str_cmp a "doFilter"  ; Δ{}
                                                                  let _t65 = == _t64 0  ; Δ{}
                                                                  let _t93 = rtcall axion_str_cmp key "P"  ; Δ{}
                                                                  let _t94 = == _t93 0  ; Δ{}
                                                                  ret "o"  ; Δ{}
                                                                  ret call doRestore cwd sel marked prog hidden rows  ; Δ{}
                                                                  ret if _t65 then
                                                                  ret if _t94 then
                                                                else
                                                                else
                                                                let _t62 = rtcall axion_str_cmp a "doSort"  ; Δ{}
                                                                let _t63 = == _t62 0  ; Δ{}
                                                                let _t91 = rtcall axion_str_cmp key "u"  ; Δ{}
                                                                let _t92 = == _t91 0  ; Δ{}
                                                                ret "!"  ; Δ{}
                                                                ret call doFilter cwd sel marked prog hidden rows  ; Δ{}
                                                                ret if _t63 then
                                                                ret if _t92 then
                                                              else
                                                              else
                                                              let _t60 = rtcall axion_str_cmp a "doShell"  ; Δ{}
                                                              let _t61 = == _t60 0  ; Δ{}
                                                              let _t89 = rtcall axion_str_cmp key "F"  ; Δ{}
                                                              let _t90 = == _t89 0  ; Δ{}
                                                              ret "p"  ; Δ{}
                                                              ret call doSort cwd sel marked prog hidden rows  ; Δ{}
                                                              ret if _t61 then
                                                              ret if _t90 then
                                                            else
                                                            else
                                                            let _t58 = rtcall axion_str_cmp a "doPaste"  ; Δ{}
                                                            let _t59 = == _t58 0  ; Δ{}
                                                            let _t87 = rtcall axion_str_cmp key "o"  ; Δ{}
                                                            let _t88 = == _t87 0  ; Δ{}
                                                            ret "c"  ; Δ{}
                                                            ret call doShell cwd sel marked prog hidden rows  ; Δ{}
                                                            ret if _t59 then
                                                            ret if _t88 then
                                                          else
                                                          else
                                                          let _t56 = rtcall axion_str_cmp a "clearMarks"  ; Δ{}
                                                          let _t57 = == _t56 0  ; Δ{}
                                                          let _t85 = rtcall axion_str_cmp key "!"  ; Δ{}
                                                          let _t86 = == _t85 0  ; Δ{}
                                                          ret "D"  ; Δ{}
                                                          ret call doBulk cwd sel marked prog hidden rows  ; Δ{}
                                                          ret if _t57 then
                                                          ret if _t86 then
                                                        else
                                                        else
                                                        let _t54 = rtcall axion_str_cmp a "markAllTrash"  ; Δ{}
                                                        let _t55 = == _t54 0  ; Δ{}
                                                        let _t83 = rtcall axion_str_cmp key "R"  ; Δ{}
                                                        let _t84 = == _t83 0  ; Δ{}
                                                        ret "S"  ; Δ{}
                                                        ret call doPaste cwd sel marked prog hidden rows  ; Δ{}
                                                        ret if _t55 then
                                                        ret if _t84 then
                                                      else
                                                      else
                                                      let _t52 = rtcall axion_str_cmp a "markAllLink"  ; Δ{}
                                                      let _t53 = == _t52 0  ; Δ{}
                                                      let _t81 = rtcall axion_str_cmp key "p"  ; Δ{}
                                                      let _t82 = == _t81 0  ; Δ{}
                                                      ret "M"  ; Δ{}
                                                      ret call loop cwd sel "" "" hidden rows cols raw  ; Δ{}
                                                      ret if _t53 then
                                                      ret if _t82 then
                                                    drop _t78 : String
                                                    else
                                                    else
                                                    let _d1000008 = call loop cwd sel _t78 "trash" hidden rows cols raw  ; Δ{_t78}
                                                    let _t50 = rtcall axion_str_cmp a "markAllMove"  ; Δ{}
                                                    let _t51 = == _t50 0  ; Δ{}
                                                    let _t78 = call allPathsOf cwd raw  ; Δ{} · makes String
                                                    let _t79 = rtcall axion_str_cmp key "c"  ; Δ{}
                                                    let _t80 = == _t79 0  ; Δ{}
                                                    ret "Y"  ; Δ{}
                                                    ret _d1000008  ; Δ{}
                                                    ret if _t51 then
                                                    ret if _t80 then
                                                  drop _t75 : String
                                                  else
                                                  else
                                                  let _d1000007 = call loop cwd sel _t75 "ln -s" hidden rows cols raw  ; Δ{_t75}
                                                  let _t48 = rtcall axion_str_cmp a "markAllCopy"  ; Δ{}
                                                  let _t49 = == _t48 0  ; Δ{}
                                                  let _t75 = call allPathsOf cwd raw  ; Δ{} · makes String
                                                  let _t76 = rtcall axion_str_cmp key "D"  ; Δ{}
                                                  let _t77 = == _t76 0  ; Δ{}
                                                  ret "d"  ; Δ{}
                                                  ret _d1000007  ; Δ{}
                                                  ret if _t49 then
                                                  ret if _t77 then
                                                drop _t72 : String
                                                else
                                                else
                                                let _d1000006 = call loop cwd sel _t72 "mv" hidden rows cols raw  ; Δ{_t72}
                                                let _t46 = rtcall axion_str_cmp a "markTrash"  ; Δ{}
                                                let _t47 = == _t46 0  ; Δ{}
                                                let _t72 = call allPathsOf cwd raw  ; Δ{} · makes String
                                                let _t73 = rtcall axion_str_cmp key "S"  ; Δ{}
                                                let _t74 = == _t73 0  ; Δ{}
                                                ret "s"  ; Δ{}
                                                ret _d1000006  ; Δ{}
                                                ret if _t47 then
                                                ret if _t74 then
                                              drop _t69 : String
                                              else
                                              else
                                              let _d1000005 = call loop cwd sel _t69 "cp -R" hidden rows cols raw  ; Δ{_t69}
                                              let _t44 = rtcall axion_str_cmp a "markLink"  ; Δ{}
                                              let _t45 = == _t44 0  ; Δ{}
                                              let _t69 = call allPathsOf cwd raw  ; Δ{} · makes String
                                              let _t70 = rtcall axion_str_cmp key "M"  ; Δ{}
                                              let _t71 = == _t70 0  ; Δ{}
                                              ret "m"  ; Δ{}
                                              ret _d1000005  ; Δ{}
                                              ret if _t45 then
                                              ret if _t71 then
                                            drop _t65 : String
                                            drop _t66 : String
                                            else
                                            else
                                            let _d1000004 = call loop cwd sel _t66 "trash" hidden rows cols raw  ; Δ{_t66}
                                            let _t42 = rtcall axion_str_cmp a "markMove"  ; Δ{}
                                            let _t43 = == _t42 0  ; Δ{}
                                            let _t65 = call selPathOf cwd raw sel  ; Δ{} · makes String
                                            let _t66 = call markToggle marked _t65  ; Δ{_t65} · makes String
                                            let _t67 = rtcall axion_str_cmp key "Y"  ; Δ{}
                                            let _t68 = == _t67 0  ; Δ{}
                                            ret "y"  ; Δ{}
                                            ret _d1000004  ; Δ{}
                                            ret if _t43 then
                                            ret if _t68 then
                                          drop _t61 : String
                                          drop _t62 : String
                                          else
                                          else
                                          let _d1000003 = call loop cwd sel _t62 "ln -s" hidden rows cols raw  ; Δ{_t62}
                                          let _t40 = rtcall axion_str_cmp a "markCopy"  ; Δ{}
                                          let _t41 = == _t40 0  ; Δ{}
                                          let _t61 = call selPathOf cwd raw sel  ; Δ{} · makes String
                                          let _t62 = call markToggle marked _t61  ; Δ{_t61} · makes String
                                          let _t63 = rtcall axion_str_cmp key "d"  ; Δ{}
                                          let _t64 = == _t63 0  ; Δ{}
                                          ret "R"  ; Δ{}
                                          ret _d1000003  ; Δ{}
                                          ret if _t41 then
                                          ret if _t64 then
                                        drop _t57 : String
                                        drop _t58 : String
                                        else
                                        else
                                        let _d1000002 = call loop cwd sel _t58 "mv" hidden rows cols raw  ; Δ{_t58}
                                        let _t38 = rtcall axion_str_cmp a "doBulk"  ; Δ{}
                                        let _t39 = == _t38 0  ; Δ{}
                                        let _t57 = call selPathOf cwd raw sel  ; Δ{} · makes String
                                        let _t58 = call markToggle marked _t57  ; Δ{_t57} · makes String
                                        let _t59 = rtcall axion_str_cmp key "s"  ; Δ{}
                                        let _t60 = == _t59 0  ; Δ{}
                                        ret "X"  ; Δ{}
                                        ret _d1000002  ; Δ{}
                                        ret if _t39 then
                                        ret if _t60 then
                                      drop _t53 : String
                                      drop _t54 : String
                                      else
                                      else
                                      let _d1000001 = call loop cwd sel _t54 "cp -R" hidden rows cols raw  ; Δ{_t54}
                                      let _t36 = rtcall axion_str_cmp a "doChmod"  ; Δ{}
                                      let _t37 = == _t36 0  ; Δ{}
                                      let _t53 = call selPathOf cwd raw sel  ; Δ{} · makes String
                                      let _t54 = call markToggle marked _t53  ; Δ{_t53} · makes String
                                      let _t55 = rtcall axion_str_cmp key "m"  ; Δ{}
                                      let _t56 = == _t55 0  ; Δ{}
                                      ret "x"  ; Δ{}
                                      ret _d1000001  ; Δ{}
                                      ret if _t37 then
                                      ret if _t56 then
                                    else
                                    else
                                    let _t34 = rtcall axion_str_cmp a "doAttr"  ; Δ{}
                                    let _t35 = == _t34 0  ; Δ{}
                                    let _t51 = rtcall axion_str_cmp key "y"  ; Δ{}
                                    let _t52 = == _t51 0  ; Δ{}
                                    ret "r"  ; Δ{}
                                    ret call doChmod cwd sel marked prog hidden rows  ; Δ{}
                                    ret if _t35 then
                                    ret if _t52 then
                                  else
                                  else
                                  let _t32 = rtcall axion_str_cmp a "doRename"  ; Δ{}
                                  let _t33 = == _t32 0  ; Δ{}
                                  let _t49 = rtcall axion_str_cmp key "X"  ; Δ{}
                                  let _t50 = == _t49 0  ; Δ{}
                                  ret "f"  ; Δ{}
                                  ret call doAttr cwd sel marked prog hidden rows  ; Δ{}
                                  ret if _t33 then
                                  ret if _t50 then
                                else
                                else
                                let _t30 = rtcall axion_str_cmp a "doMkfile"  ; Δ{}
                                let _t31 = == _t30 0  ; Δ{}
                                let _t47 = rtcall axion_str_cmp key "x"  ; Δ{}
                                let _t48 = == _t47 0  ; Δ{}
                                ret "n"  ; Δ{}
                                ret call doRename cwd sel marked prog hidden rows  ; Δ{}
                                ret if _t31 then
                                ret if _t48 then
                              else
                              else
                              let _t28 = rtcall axion_str_cmp a "doMkdir"  ; Δ{}
                              let _t29 = == _t28 0  ; Δ{}
                              let _t45 = rtcall axion_str_cmp key "r"  ; Δ{}
                              let _t46 = == _t45 0  ; Δ{}
                              ret ","  ; Δ{}
                              ret call doMkfile cwd sel marked prog hidden rows  ; Δ{}
                              ret if _t29 then
                              ret if _t46 then
                            else
                            else
                            let _t26 = rtcall axion_str_cmp a "searchPrev"  ; Δ{}
                            let _t27 = == _t26 0  ; Δ{}
                            let _t43 = rtcall axion_str_cmp key "f"  ; Δ{}
                            let _t44 = == _t43 0  ; Δ{}
                            ret ";"  ; Δ{}
                            ret call doMkdir cwd sel marked prog hidden rows  ; Δ{}
                            ret if _t27 then
                            ret if _t44 then
                          drop _t30 : String
                          drop _t31 : String
                          else
                          else
                          let _d1000000 = call reloop _t31 0 "" "" 0 _t32  ; Δ{_t31}
                          let _t24 = rtcall axion_str_cmp a "searchNext"  ; Δ{}
                          let _t25 = == _t24 0  ; Δ{}
                          let _t30 = rtcall axion_getarg 0  ; Δ{} · makes String
                          let _t31 = call startDir _t30  ; Δ{_t30} · makes String
                          let _t32 = call termRows 0  ; Δ{_t31}
                          let _t41 = rtcall axion_str_cmp key "n"  ; Δ{}
                          let _t42 = == _t41 0  ; Δ{}
                          ret "/"  ; Δ{}
                          ret _d1000000  ; Δ{}
                          ret call doSearch cwd sel marked prog hidden rows cols raw  ; Δ{}
                          ret if _t25 then
                          ret if _t42 then
                        _ ->
                        else
                        else
                        let _t22 = rtcall axion_str_cmp a "doSearch"  ; Δ{}
                        let _t23 = == _t22 0  ; Δ{}
                        let _t39 = rtcall axion_str_cmp key "/"  ; Δ{}
                        let _t40 = == _t39 0  ; Δ{}
                        ret ":"  ; Δ{}
                        ret call doGoDir cwd sel marked prog hidden rows  ; Δ{}
                        ret if _t23 then
                        ret if _t40 then
                      drop _t28 : String
                      drop _t8 : String
                      else
                      else
                      let _t20 = rtcall axion_str_cmp a "doGoDir"  ; Δ{}
                      let _t21 = == _t20 0  ; Δ{}
                      let _t28 = call setupSeq  ; Δ{} · makes String
                      let _t29 = putStr _t28  ; Δ{_t28}
                      let _t37 = rtcall axion_str_cmp key ":"  ; Δ{}
                      let _t38 = == _t37 0  ; Δ{}
                      ret "-"  ; Δ{}
                      ret _t14  ; Δ{}
                      ret call goPrev marked prog hidden rows  ; Δ{}
                      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
                      ret case _t29 of
                      ret if _t21 then
                      ret if _t38 then
                    _ ->
                    _ ->
                    _ ->
                    else
                    else
                    let _t18 = rtcall axion_str_cmp a "prev"  ; Δ{}
                    let _t19 = == _t18 0  ; Δ{}
                    let _t35 = rtcall axion_str_cmp key "-"  ; Δ{}
                    let _t36 = == _t35 0  ; Δ{}
                    ret "~"  ; Δ{}
                    ret call goHome marked prog hidden rows  ; Δ{}
                    ret if _t19 then
                    ret if _t36 then
                  drop _t26 : String
                  drop _t9 : String
                  else
                  else
                  let _t10 = putStr _t9  ; Δ{_t8 _t9}
                  let _t16 = rtcall axion_str_cmp a "home"  ; Δ{}
                  let _t17 = == _t16 0  ; Δ{}
                  let _t17 = rtcall axion_unlink tmp  ; Δ{}
                  let _t26 = call queryCell 0  ; Δ{} · makes String
                  let _t27 = rtcall axion_system _t26  ; Δ{_t26}
                  let _t30 = call countLines raw  ; Δ{}
                  let _t31 = call clampSel sel _t30  ; Δ{}
                  let _t32 = call termRows 0  ; Δ{}
                  let _t33 = rtcall axion_str_cmp key "~"  ; Δ{}
                  let _t34 = == _t33 0  ; Δ{}
                  let _t9 = call setupSeq  ; Δ{_t8} · makes String
                  ret "e"  ; Δ{}
                  ret 0  ; Δ{}
                  ret 1  ; Δ{}
                  ret call reloop cwd _t31 marked prog hidden _t32  ; Δ{}
                  ret case _t10 of
                  ret case _t17 of
                  ret case _t27 of
                  ret if _t17 then
                  ret if _t34 then
                _ ->
                _ ->
                _ ->
                else
                else
                else
                let _t14 = rtcall axion_str_cmp a "refresh"  ; Δ{}
                let _t15 = == _t14 0  ; Δ{}
                let _t26 = == hidden 1  ; Δ{}
                let _t27 = if _t26 then
                let _t28 = call scrollUp poff rows  ; Δ{}
                let _t28 = rtcall axion_str_cmp key "e"  ; Δ{}
                let _t29 = == _t28 0  ; Δ{}
                ret "."  ; Δ{}
                ret 1  ; Δ{}
                ret call hasInfix "compress" m  ; Δ{}
                ret call loopAt cwd sel marked prog hidden rows cols raw _t28  ; Δ{}
                ret call reloop cwd 0 marked prog _t27 rows  ; Δ{}
                ret call step cwd sel marked prog hidden rows cols raw key  ; Δ{}
                ret if _t15 then
                ret if _t29 then
              drop _t10 : List$String
              drop _t10 : String
              drop _t11 : String
              drop _t11 : String
              drop _t12 : String
              drop _t13 : List$String
              drop _t13 : String
              drop _t14 : String
              drop _t15 : String
              drop _t15 : String
              drop _t16 : String
              drop _t17 : String
              drop _t18 : String
              drop _t19 : String
              drop _t19 : String
              drop _t20 : String
              drop _t20 : String
              drop _t21 : String
              drop _t21 : String
              drop _t22 : String
              drop _t22 : String
              drop _t22 : String
              drop _t23 : String
              drop _t23 : String
              drop _t23 : String
              drop _t24 : String
              drop _t24 : String
              drop _t25 : List$String
              drop _t5 : String
              drop _t6 : String
              drop _t7 : String
              drop _t8 : String
              drop _t9 : String
              else
              else
              else
              else
              let _d1000000 = call reloopInto _t22 _t23 marked prog hidden rows  ; Δ{_t22 _t23}
              let _d1000002 = call drawLines _t25 1 px pw ph  ; Δ{_t25} · makes String
              let _t10 = call filter$$nonEmpty _t9  ; Δ{_t9} · moves{_t9} · makes List$String
              let _t10 = call shQuote _t9  ; Δ{_t6 _t8 _t9} · makes String
              let _t11 = call tabiFile 0  ; Δ{_t10 _t6 _t8} · makes String
              let _t11 = rtcall axion_read_file tmp  ; Δ{_t10} · makes String
              let _t12 = call lines _t11  ; Δ{_t10 _t11} · makes List$String
              let _t12 = call shQuote _t11  ; Δ{_t10 _t11 _t6 _t8} · makes String
              let _t12 = rtcall axion_str_cmp a "toggleHidden"  ; Δ{}
              let _t13 = == _t12 0  ; Δ{}
              let _t13 = call filter$$nonEmpty _t12  ; Δ{_t10 _t12} · moves{_t12} · makes List$String
              let _t13 = call pendingFile 0  ; Δ{_t10 _t12 _t6 _t8} · makes String
              let _t14 = call bulkApply _t10 _t13 cwd  ; Δ{_t10 _t13}
              let _t14 = call shQuote _t13  ; Δ{_t10 _t12 _t13 _t6 _t8} · makes String
              let _t15 = call setupSeq  ; Δ{} · makes String
              let _t15 = rtcall axion_strcat _t14 "; test -t 0 && stty -echo -icanon 2>/dev/null"  ; Δ{_t10 _t12 _t14 _t6 _t8} · makes String
              let _t16 = putStr _t15  ; Δ{_t15}
              let _t16 = rtcall axion_strcat " " _t15  ; Δ{_t10 _t12 _t15 _t6 _t8} · makes String
              let _t17 = rtcall axion_strcat _t12 _t16  ; Δ{_t10 _t12 _t16 _t6 _t8} · makes String
              let _t18 = rtcall axion_strcat " " _t17  ; Δ{_t10 _t17 _t6 _t8} · makes String
              let _t19 = call shQuote path  ; Δ{} · makes String
              let _t19 = rtcall axion_strcat _t10 _t18  ; Δ{_t10 _t18 _t6 _t8} · makes String
              let _t20 = call scrollPipe poff ph  ; Δ{_t19} · makes String
              let _t20 = rtcall axion_strcat " " _t19  ; Δ{_t19 _t6 _t8} · makes String
              let _t21 = rtcall axion_strcat " 2>/dev/null" _t20  ; Δ{_t19 _t20} · makes String
              let _t21 = rtcall axion_strcat _t8 _t20  ; Δ{_t20 _t6 _t8} · makes String
              let _t22 = call parentDir cwd  ; Δ{} · makes String
              let _t22 = rtcall axion_strcat " " _t21  ; Δ{_t21 _t6} · makes String
              let _t22 = rtcall axion_strcat _t19 _t21  ; Δ{_t19 _t21} · makes String
              let _t23 = call baseName cwd  ; Δ{_t22} · makes String
              let _t23 = rtcall axion_strcat "file -bL -- " _t22  ; Δ{_t22} · makes String
              let _t23 = rtcall axion_strcat _t6 _t22  ; Δ{_t22 _t6} · makes String
              let _t24 = rtcall axion_run _t23  ; Δ{_t23} · makes String
              let _t24 = rtcall axion_str_cmp key "."  ; Δ{}
              let _t24 = rtcall axion_strcat "rm -f " _t23  ; Δ{_t23} · makes String
              let _t25 = == _t24 0  ; Δ{}
              let _t25 = call lines _t24  ; Δ{_t24} · makes List$String
              let _t25 = call scrollDown poff rows  ; Δ{}
              let _t25 = rtcall axion_system _t24  ; Δ{_t24}
              let _t26 = rtcall axion_str_cmp key "K"  ; Δ{}
              let _t27 = == _t26 0  ; Δ{}
              let _t5 = call filterFile 0  ; Δ{} · makes String
              let _t6 = call hasInfix "xz" m  ; Δ{}
              let _t6 = call shQuote _t5  ; Δ{_t5} · makes String
              let _t7 = call lastqFile 0  ; Δ{_t6} · makes String
              let _t8 = call shQuote _t7  ; Δ{_t6 _t7} · makes String
              let _t8 = rtcall axion_read_key 0  ; Δ{} · makes String
              let _t9 = call lines marked  ; Δ{} · makes List$String
              let _t9 = call tabsFile 0  ; Δ{_t6 _t8} · makes String
              ret ""  ; Δ{}
              ret ""  ; Δ{}
              ret "1;32"  ; Δ{}
              ret "\u{f15b}"  ; Δ{}
              ret "\u{f1c9}"  ; Δ{}
              ret "code"  ; Δ{}
              ret "h"  ; Δ{}
              ret 1  ; Δ{}
              ret 1  ; Δ{}
              ret _d1000000  ; Δ{}
              ret _d1000002  ; Δ{_d1000002} · moves{_d1000002}
              ret call hasPrefix "inode/x-empty" mime  ; Δ{}
              ret call loop cwd sel marked prog hidden rows cols raw  ; Δ{}
              ret call loopAt cwd sel marked prog hidden rows cols raw _t25  ; Δ{}
              ret call pollKey cwd sel marked prog hidden rows cols raw poff  ; Δ{}
              ret call reloop cwd sel marked prog hidden rows  ; Δ{}
              ret call reloop cwd sel marked prog hidden rows  ; Δ{}
              ret call reloop cwd sel marked prog hidden rows  ; Δ{}
              ret call step cwd sel marked prog hidden rows cols raw k  ; Δ{}
              ret call textPreview path px pw ph poff  ; Δ{} · makes String
              ret case _t16 of
              ret case _t25 of
              ret case _t8 of
              ret if _t13 then
              ret if _t25 then
              ret if _t27 then
              ret if _t6 then
            _ ->
            _ ->
            _ ->
            _ ->
            _ ->
            _ ->
            _ ->
            drop _t10 : List$String
            drop _t10 : List$String
            drop _t10 : List$String
            drop _t12 : String
            drop _t13 : String
            drop _t14 : String
            drop _t15 : List$String
            drop _t15 : String
            drop _t16 : List$String
            drop _t20 : String
            drop _t22 : String
            drop _t3 : String
            drop acc : String
            drop acc : String
            else
            else
            else
            else
            else
            else
            else
            else
            else
            else
            let _d1000000 = call favOrIgnore cwd sel marked prog hidden rows _t20  ; Δ{_t20}
            let _d1000000 = rtcall axion_rename o _t3  ; Δ{_t3}
            let _d1000001 = call drawLines _t16 1 px pw ph  ; Δ{_t16} · makes String
            let _d1000002 = call gotoDir cwd _t22 sel marked prog hidden rows  ; Δ{_t22}
            let _t10 = call codeExts  ; Δ{} · makes List$String
            let _t10 = call codeExts  ; Δ{} · makes List$String
            let _t10 = call codeExts  ; Δ{} · makes List$String
            let _t10 = rtcall axion_str_cmp a "parent"  ; Δ{}
            let _t11 = == _t10 0  ; Δ{}
            let _t11 = call elemBy$String e _t10  ; Δ{_t10}
            let _t11 = call elemBy$String e _t10  ; Δ{_t10}
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
            let _t18 = rtcall axion_str_at 0 k  ; Δ{}
            let _t18 = rtcall axion_strcat acc k  ; Δ{} · makes String
            let _t20 = rtcall axion_str_cmp key "h"  ; Δ{}
            let _t20 = rtcall axion_str_len key  ; Δ{}
            let _t20 = showInt n  ; Δ{} · makes String
            let _t21 = - _t20 3  ; Δ{}
            let _t21 = == _t20 0  ; Δ{}
            let _t21 = rtcall axion_str_at 0 k  ; Δ{}
            let _t22 = == _t21 27  ; Δ{}
            let _t22 = rtcall axion_substr 3 _t21 key  ; Δ{} · makes String
            let _t23 = rtcall axion_str_cmp key "J"  ; Δ{}
            let _t24 = == _t23 0  ; Δ{}
            let _t3 = call </> cwd n  ; Δ{} · makes String
            let _t5 = call hasInfix "bzip" m  ; Δ{}
            ret "0;33"  ; Δ{}
            ret "\u{f0f6}"  ; Δ{}
            ret "doc"  ; Δ{}
            ret "l"  ; Δ{}
            ret 0  ; Δ{}
            ret 0  ; Δ{}
            ret 1  ; Δ{}
            ret 1  ; Δ{}
            ret 1  ; Δ{}
            ret == _t18 10  ; Δ{}
            ret _d1000000  ; Δ{}
            ret _d1000000  ; Δ{}
            ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
            ret _d1000002  ; Δ{}
            ret call cmdGo prompt rows cwd _t17  ; Δ{_t17} · moves{_t17} · makes String
            ret call cmdGo prompt rows cwd _t18  ; Δ{_t18} · moves{_t18} · makes String
            ret call open cwd sel marked prog hidden rows raw  ; Δ{}
            ret if _t11 then
            ret if _t11 then
            ret if _t11 then
            ret if _t11 then
            ret if _t18 then
            ret if _t21 then
            ret if _t22 then
            ret if _t24 then
            ret if _t5 then
          drop _t0 : String
          drop _t0 : String
          drop _t1 : String
          drop _t11 : String
          drop _t11 : String
          drop _t16 : String
          drop _t17 : String
          drop _t18 : String
          drop _t2 : List$String
          drop _t4 : String
          drop _t4 : String
          drop _t4 : String
          drop _t4 : String
          drop _t5 : String
          drop _t5 : String
          drop _t6 : String
          drop _t6 : String
          drop _t7 : String
          drop _t7 : String
          drop _t7 : String
          drop _t8 : List$String
          drop _t8 : List$String
          drop _t8 : List$String
          drop _t8 : String
          drop _t8 : String
          drop _t8 : String
          drop _t8 : String
          drop a : String
          drop a : String
          drop acc : String
          else
          else
          else
          else
          else
          else
          else
          else
          else
          else
          else
          else
          else
          let _d1000000 = call fileColor lsc _t8  ; Δ{_t8} · makes String
          let _d1000000 = call fileIcon icfg _t8  ; Δ{_t8} · makes String
          let _d1000000 = call searchKey cwd sel marked prog hidden rows cols raw osel acc _t7  ; Δ{_t7}
          let _d1000000 = call searchLoop cwd sel marked prog hidden rows cols raw osel _t16  ; Δ{_t16}
          let _d1000000 = putStr _t4  ; Δ{_t4}
          let _d1000000 = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
          let _d1000001 = call doUserCmd cwd sel marked prog hidden rows cols raw _t18  ; Δ{_t18}
          let _d1000001 = call searchLoop cwd sel marked prog hidden rows cols raw osel _t17  ; Δ{_t17}
          let _d1000001 = rtcall axion_strcat _t5 _t7  ; Δ{_t5 _t7} · makes String
          let _d1000002 = call dup a  ; Δ{a} · makes String
          let _t0 = call </> cwd n  ; Δ{} · makes String
          let _t0 = call fallbackTy y  ; Δ{} · makes String
          let _t1 = call rowFor lsc icfg y _t0 row sel marked cwd listW prev  ; Δ{_t0} · makes String
          let _t1 = rtcall axion_str_cmp o _t0  ; Δ{_t0}
          let _t10 = call clampSel sel _t9  ; Δ{}
          let _t10 = rtcall axion_str_at 0 k  ; Δ{}
          let _t11 = call isArchiveMime mime  ; Δ{}
          let _t12 = call dropLast acc  ; Δ{} · makes String
          let _t12 = rtcall axion_str_cmp k "g"  ; Δ{}
          let _t13 = rtcall axion_str_at 0 k  ; Δ{}
          let _t14 = - n 1  ; Δ{}
          let _t14 = == _t13 9  ; Δ{}
          let _t14 = call countLines raw  ; Δ{}
          let _t14 = rtcall axion_str_at 0 k  ; Δ{}
          let _t14 = rtcall axion_str_at 0 key  ; Δ{}
          let _t15 = - _t14 1  ; Δ{}
          let _t15 = call clampSel _t14 total  ; Δ{}
          let _t16 = call countLines raw  ; Δ{}
          let _t16 = call dropLast acc  ; Δ{} · makes String
          let _t16 = rtcall axion_str_at 0 k  ; Δ{}
          let _t16 = rtcall axion_str_len key  ; Δ{}
          let _t17 = - _t16 1  ; Δ{}
          let _t17 = == _t16 13  ; Δ{}
          let _t17 = call clampSel _t15 _t16  ; Δ{}
          let _t17 = rtcall axion_strcat acc k  ; Δ{} · makes String
          let _t18 = rtcall axion_str_cmp key "l"  ; Δ{}
          let _t18 = rtcall axion_substr 1 _t17 key  ; Δ{} · makes String
          let _t19 = == _t18 0  ; Δ{}
          let _t19 = call hasPrefix "cd " key  ; Δ{}
          let _t19 = if _t17 then
          let _t2 = == _t1 0  ; Δ{}
          let _t2 = con Nil  ; Δ{_t1} · makes List$String
          let _t3 = + row 1  ; Δ{_t1 _t2}
          let _t4 = call buildConfig 0  ; Δ{}
          let _t4 = call drawRows lsc icfg ys _t2 _t3 sel marked cwd listW prev  ; Δ{_t1 _t2} · makes String
          let _t4 = call editorCmd 0  ; Δ{} · makes String
          let _t4 = call hasInfix "gzip" m  ; Δ{}
          let _t4 = call resetSeq  ; Δ{} · makes String
          let _t4 = call setupSeq  ; Δ{} · makes String
          let _t4 = if _t2 then
          let _t5 = == _t4 0  ; Δ{}
          let _t5 = call readMainKey 0  ; Δ{} · makes String
          let _t5 = call rowFor lsc icfg y ty row sel marked cwd listW prev  ; Δ{} · makes String
          let _t5 = call shQuote tmp  ; Δ{_t4} · makes String
          let _t5 = putStr _t4  ; Δ{_t4}
          let _t6 = + row 1  ; Δ{_t5}
          let _t6 = call prefetch cwd sel rows raw cols  ; Δ{}
          let _t6 = if _t5 then
          let _t6 = rtcall axion_strcat " " _t5  ; Δ{_t4 _t5} · makes String
          let _t7 = call actionKey a  ; Δ{a} · makes String
          let _t7 = call bulkApply os ns cwd  ; Δ{}
          let _t7 = call drawRows lsc icfg ys tyss _t6 sel marked cwd listW prev  ; Δ{_t5} · makes String
          let _t7 = call nEntries cwd hidden  ; Δ{}
          let _t7 = putStr "\n[any key]"  ; Δ{}
          let _t7 = rtcall axion_read_key 0  ; Δ{} · makes String
          let _t7 = rtcall axion_str_at 1 key  ; Δ{}
          let _t7 = rtcall axion_strcat _t4 _t6  ; Δ{_t4 _t6} · makes String
          let _t8 = call docExts  ; Δ{} · makes List$String
          let _t8 = call docExts  ; Δ{} · makes List$String
          let _t8 = call docExts  ; Δ{} · makes List$String
          let _t8 = call extOf raw  ; Δ{} · makes String
          let _t8 = call extOf raw  ; Δ{} · makes String
          let _t8 = call markCount marked  ; Δ{}
          let _t8 = call setupSeq  ; Δ{} · makes String
          let _t8 = call setupSeq  ; Δ{} · makes String
          let _t8 = rtcall axion_str_cmp a "open"  ; Δ{}
          let _t8 = rtcall axion_system _t7  ; Δ{_t7}
          let _t9 = + _t7 _t8  ; Δ{}
          let _t9 = == _t8 0  ; Δ{}
          let _t9 = call elemBy$String e _t8  ; Δ{_t8}
          let _t9 = call elemBy$String e _t8  ; Δ{_t8}
          let _t9 = call elemBy$String e _t8  ; Δ{_t8}
          let _t9 = putStr _t8  ; Δ{_t8}
          let _t9 = putStr _t8  ; Δ{_t8}
          ret ""  ; Δ{}
          ret "1;31"  ; Δ{}
          ret "G"  ; Δ{}
          ret "\u{f1c6}"  ; Δ{}
          ret "archive"  ; Δ{}
          ret "copying"  ; Δ{}
          ret "h"  ; Δ{}
          ret "working"  ; Δ{}
          ret + _t6 _t7  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret == _t10 8  ; Δ{}
          ret == _t12 0  ; Δ{}
          ret == _t14 33  ; Δ{}
          ret == _t14 8  ; Δ{}
          ret == _t7 33  ; Δ{}
          ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
          ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
          ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
          ret _d1000000  ; Δ{}
          ret _d1000000  ; Δ{}
          ret _d1000000  ; Δ{}
          ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
          ret _d1000001  ; Δ{}
          ret _d1000001  ; Δ{}
          ret _d1000002  ; Δ{_d1000002} · moves{_d1000002}
          ret call actionPick s _t7  ; Δ{_t7} · moves{_t7} · makes String
          ret call cmdGo prompt rows cwd _t12  ; Δ{_t12} · moves{_t12} · makes String
          ret call exColor lsc  ; Δ{} · makes String
          ret call exIcon icfg  ; Δ{} · makes String
          ret call loop cwd _t15 marked prog hidden rows cols raw  ; Δ{}
          ret call loop cwd _t17 marked prog hidden rows cols raw  ; Δ{}
          ret call pixHeader "[pdf] " path mime px pw ph  ; Δ{} · makes String
          ret call reloop cwd _t10 "" "" hidden rows  ; Δ{}
          ret call reloop cwd sel marked prog hidden rows  ; Δ{}
          ret call stepAt cwd sel marked prog hidden rows cols raw poff _t5  ; Δ{_t5} · moves{_t5}
          ret case _t4 of
          ret case _t5 of
          ret case _t6 of
          ret case _t7 of
          ret case _t8 of
          ret case _t9 of
          ret case _t9 of
          ret if _t11 then
          ret if _t14 then
          ret if _t19 then
          ret if _t19 then
          ret if _t19 then
          ret if _t4 then
          ret if _t9 then
          ret if _t9 then
          ret if _t9 then
          ret if _t9 then
        Cons n ns ->
        Cons ty tyss ->
        Nil ->
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
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        drop _t1 : String
        drop _t10 : String
        drop _t11 : String
        drop _t11 : String
        drop _t11 : String
        drop _t11 : String
        drop _t12 : String
        drop _t12 : String
        drop _t13 : String
        drop _t2 : String
        drop _t2 : String
        drop _t2 : String
        drop _t3 : String
        drop _t3 : String
        drop _t4 : String
        drop _t4 : String
        drop _t5 : String
        drop _t5 : String
        drop _t5 : String
        drop _t6 : List$String
        drop _t6 : List$String
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
        drop a : String
        drop acc : String
        drop b2 : String
        drop k : String
        drop k : String
        drop y : String
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
        else
        else
        else
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
        let _d1000000 = call doUserCmdTty cwd sel marked prog hidden rows raw _t11  ; Δ{_t11}
        let _d1000000 = call hasInfix q _t1  ; Δ{_t1}
        let _d1000000 = call hasInfix q _t2  ; Δ{_t2}
        let _d1000000 = rtcall axion_strcat _t11 _t13  ; Δ{_t11 _t13} · makes String
        let _d1000000 = rtcall axion_strcat _t9 _t11  ; Δ{_t11 _t9} · makes String
        let _d1000001 = call dup a  ; Δ{a} · makes String
        let _d1000001 = rtcall axion_strcat _t9 _t12  ; Δ{_t12 _t9} · makes String
        let _d1000002 = call gotoDir cwd _t11 sel marked prog hidden rows  ; Δ{_t11}
        let _d1000002 = rtcall axion_system _t5  ; Δ{_t5}
        let _d1000003 = call runBuiltin cwd sel marked prog hidden rows cols raw _t12  ; Δ{_t12}
        let _t1 = + i 1  ; Δ{}
        let _t1 = + r 1  ; Δ{}
        let _t1 = + r 1  ; Δ{}
        let _t1 = - i 1  ; Δ{}
        let _t1 = call count p ys  ; Δ{}
        let _t1 = call filter$$neStr _cap0 ys  ; Δ{y ys} · moves{ys} · makes List$String
        let _t1 = call filter$$nonEmpty ys  ; Δ{y ys} · moves{ys} · makes List$String
        let _t1 = call rdtKeep hidden fq ys  ; Δ{y ys} · moves{ys} · makes List$String
        let _t1 = call stripSlash y  ; Δ{} · makes String
        let _t10 = + i 1  ; Δ{_t9}
        let _t10 = + r 1  ; Δ{_t9}
        let _t10 = - _t9 2  ; Δ{}
        let _t10 = - _t9 3  ; Δ{}
        let _t10 = call hasPrefix "application/pdf" mime  ; Δ{}
        let _t10 = rtcall axion_str_cmp k "G"  ; Δ{}
        let _t10 = rtcall axion_strcat _t8 _t9  ; Δ{_t7 _t8 _t9} · makes String
        let _t11 = + vis 1  ; Δ{_t9}
        let _t11 = == _t10 0  ; Δ{}
        let _t11 = call drawLines ys _t10 px pw maxRow  ; Δ{_t9} · makes String
        let _t11 = if _t9 then
        let _t11 = rtcall axion_strcat _t7 _t10  ; Δ{_t10 _t7} · makes String
        let _t11 = rtcall axion_substr 2 _t10 key  ; Δ{} · makes String
        let _t11 = rtcall axion_substr 3 _t10 item  ; Δ{} · makes String
        let _t12 = + r 1  ; Δ{_t11}
        let _t12 = call actionKey item  ; Δ{} · makes String
        let _t12 = call clipGo s _t10 n _t11 w  ; Δ{_t9} · makes String
        let _t12 = rtcall axion_str_at 0 k  ; Δ{}
        let _t12 = rtcall axion_str_cmp key "G"  ; Δ{}
        let _t12 = rtcall axion_str_len key  ; Δ{}
        let _t13 = == _t12 0  ; Δ{}
        let _t13 = == _t12 127  ; Δ{}
        let _t13 = > _t12 1  ; Δ{}
        let _t13 = call drawLinesAnsi ys _t12 px pw maxRow  ; Δ{_t11} · makes String
        let _t13 = if _t11 then
        let _t15 = if _t13 then
        let _t15 = if _t13 then
        let _t2 = call stripSlash y  ; Δ{} · makes String
        let _t2 = showInt r  ; Δ{} · makes String
        let _t2 = showInt r  ; Δ{} · makes String
        let _t3 = + i 1  ; Δ{}
        let _t3 = + i 1  ; Δ{}
        let _t3 = call hasInfix "rar" m  ; Δ{}
        let _t3 = showInt px  ; Δ{_t2} · makes String
        let _t3 = showInt px  ; Δ{_t2} · makes String
        let _t4 = rtcall axion_strcat _t3 "H"  ; Δ{_t2 _t3} · makes String
        let _t4 = rtcall axion_strcat _t3 "H"  ; Δ{_t2 _t3} · makes String
        let _t5 = call pdfCmd path cols rows  ; Δ{} · makes String
        let _t5 = con Cons y ds  ; Δ{y ys} · moves{y} · makes List$String
        let _t5 = rtcall axion_str_at 0 key  ; Δ{}
        let _t5 = rtcall axion_strcat ";" _t4  ; Δ{_t2 _t4} · makes String
        let _t5 = rtcall axion_strcat ";" _t4  ; Δ{_t2 _t4} · makes String
        let _t6 = == _t5 33  ; Δ{}
        let _t6 = call archiveExts  ; Δ{} · makes List$String
        let _t6 = call archiveExts  ; Δ{} · makes List$String
        let _t6 = call archiveExts  ; Δ{} · makes List$String
        let _t6 = call hasPrefix "cd " a  ; Δ{a}
        let _t6 = con Cons y fs  ; Δ{y ys} · moves{y} · makes List$String
        let _t6 = rtcall axion_str_cmp a "bottom"  ; Δ{}
        let _t6 = rtcall axion_str_cmp b "D"  ; Δ{}
        let _t6 = rtcall axion_str_cmp prog "cp -R"  ; Δ{}
        let _t6 = rtcall axion_str_cmp ty "x"  ; Δ{}
        let _t6 = rtcall axion_str_cmp ty "x"  ; Δ{}
        let _t6 = rtcall axion_strcat _t2 _t5  ; Δ{_t2 _t5} · makes String
        let _t6 = rtcall axion_strcat _t2 _t5  ; Δ{_t2 _t5} · makes String
        let _t7 = == _t6 0  ; Δ{}
        let _t7 = == _t6 0  ; Δ{}
        let _t7 = == _t6 0  ; Δ{}
        let _t7 = == _t6 0  ; Δ{}
        let _t7 = == _t6 0  ; Δ{}
        let _t7 = call csi _t6  ; Δ{_t6} · makes String
        let _t7 = call csi _t6  ; Δ{_t6} · makes String
        let _t7 = call elemBy$String e _t6  ; Δ{_t6}
        let _t7 = call elemBy$String e _t6  ; Δ{_t6}
        let _t7 = call elemBy$String e _t6  ; Δ{_t6}
        let _t7 = rtcall axion_str_len fav  ; Δ{fav}
        let _t8 = + i 1  ; Δ{}
        let _t8 = - sel n  ; Δ{}
        let _t8 = call clip y pw  ; Δ{_t7} · makes String
        let _t8 = call clipAnsi y pw  ; Δ{_t7} · makes String
        let _t8 = rtcall axion_str_at 0 k  ; Δ{}
        let _t9 = == _t8 127  ; Δ{}
        let _t9 = call csi "0m"  ; Δ{_t7 _t8} · makes String
        let _t9 = call wrapSel _t8 total  ; Δ{}
        let _t9 = rtcall axion_str_len item  ; Δ{}
        let _t9 = rtcall axion_str_len key  ; Δ{}
        let _t9 = rtcall axion_strcat _t7 _t8  ; Δ{_t7 _t8} · makes String
        let _t9 = rtcall axion_substr i 1 s  ; Δ{} · makes String
        let b2 = rtcall axion_read_key_timeout 25  ; Δ{k} · makes String
        ret ""  ; Δ{}
        ret "0;36"  ; Δ{}
        ret "\u{1b}"  ; Δ{}
        ret "\u{f1c7}"  ; Δ{}
        ret "audio"  ; Δ{}
        ret "g"  ; Δ{}
        ret "l"  ; Δ{}
        ret "linking"  ; Δ{}
        ret + 1 _t1  ; Δ{}
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
        ret 1  ; Δ{}
        ret 1  ; Δ{}
        ret 1  ; Δ{}
        ret 1  ; Δ{}
        ret == c 13  ; Δ{}
        ret > _t7 0  ; Δ{fav}
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
        ret _d1000000  ; Δ{}
        ret _d1000000  ; Δ{}
        ret _d1000000  ; Δ{}
        ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
        ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
        ret _d1000002  ; Δ{}
        ret _d1000002  ; Δ{}
        ret _d1000003  ; Δ{}
        ret best  ; Δ{}
        ret call clipGo s _t8 n vis w  ; Δ{} · makes String
        ret call count p ys  ; Δ{}
        ret call drawLines ys _t1 px pw maxRow  ; Δ{} · makes String
        ret call drawLinesAnsi ys _t1 px pw maxRow  ; Δ{} · makes String
        ret call dup y  ; Δ{} · makes String
        ret call elemBy$String x ys  ; Δ{}
        ret call filter$$neStr _cap0 ys  ; Δ{ys} · moves{ys} · makes List$String
        ret call filter$$nonEmpty ys  ; Δ{ys} · moves{ys} · makes List$String
        ret call firstPrefix ys q  ; Δ{} · makes String
        ret call hasImgTool 0  ; Δ{}
        ret call hasImgTool 0  ; Δ{}
        ret call indexOfName ys target _t3 dflt  ; Δ{}
        ret call ippGo ys acc  ; Δ{}
        ret call kmVal y  ; Δ{} · makes String
        ret call laGo ys k  ; Δ{} · makes String
        ret call loop cwd 0 marked prog hidden rows cols raw  ; Δ{}
        ret call loop cwd _t9 marked prog hidden rows cols raw  ; Δ{}
        ret call loop cwd osel marked prog hidden rows cols raw  ; Δ{}
        ret call matchFrom ys q _t3 lo  ; Δ{}
        ret call matchIndex ys q _t1 dflt  ; Δ{}
        ret call orColor lsc  ; Δ{} · makes String
        ret call orIcon icfg  ; Δ{} · makes String
        ret call pick _t1 ys  ; Δ{} · makes String
        ret call pixHeader "[video] " path mime px pw ph  ; Δ{} · makes String
        ret call rdtKeep hidden fq ys  ; Δ{ys} · moves{ys} · makes List$String
        ret call rdtPartGo ys _t5 fs  ; Δ{_t5 ys} · moves{_t5 ys} · makes List$String
        ret call rdtPartGo ys ds _t6  ; Δ{_t6 ys} · moves{_t6 ys} · makes List$String
        ret call runPaste cwd marked prog  ; Δ{}
        ret call stripSlash y  ; Δ{} · makes String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
        ret i  ; Δ{}
        ret i  ; Δ{}
        ret i  ; Δ{}
        ret i  ; Δ{}
        ret i  ; Δ{}
        ret i  ; Δ{}
        ret if _t10 then
        ret if _t11 then
        ret if _t13 then
        ret if _t13 then
        ret if _t15 then
        ret if _t15 then
        ret if _t3 then
        ret if _t6 then
        ret if _t6 then
        ret if _t7 then
        ret if _t7 then
        ret if _t7 then
        ret if _t7 then
        ret if _t7 then
        ret if _t7 then
        ret if _t7 then
        ret if _t7 then
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
      drop _t1 : String
      drop _t1 : String
      drop _t10 : String
      drop _t10 : String
      drop _t10 : String
      drop _t11 : String
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
      drop _t4 : List$String
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
      drop _t7 : String
      drop _t7 : String
      drop _t7 : String
      drop _t7 : String
      drop _t8 : List$String
      drop _t8 : String
      drop _t8 : String
      drop _t8 : String
      drop _t9 : String
      drop _t9 : String
      drop a : String
      drop b1 : String
      drop b2 : String
      drop e : String
      drop k : String
      drop k : String
      drop m
      drop m
      drop nm : String
      drop nm : String
      drop v : String
      drop v : String
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
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
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
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
      let _d1000000 = call confirm _t5 rows  ; Δ{_t5}
      let _d1000000 = call countKey cwd sel marked prog hidden rows cols raw acc _t2  ; Δ{_t2}
      let _d1000000 = call dup a  ; Δ{a} · makes String
      let _d1000000 = call hasInfix _t5 _t6  ; Δ{_t5 _t6}
      let _d1000000 = call loop cwd sel marked prog hidden rows _t1 _t3  ; Δ{_t3}
      let _d1000000 = call loop cwd sel marked prog hidden rows _t7 _t11  ; Δ{_t11}
      let _d1000000 = call loopSel cwd child marked prog hidden rows _t10  ; Δ{_t10}
      let _d1000000 = call loopSel cwd child marked prog hidden rows _t2  ; Δ{_t2}
      let _d1000000 = call reloopDispatch cwd sel marked prog hidden rows _t3  ; Δ{_t3}
      let _d1000000 = call reloopIntoDispatch cwd child marked prog hidden rows _t3  ; Δ{_t3}
      let _d1000000 = rtcall axion_rename _t5 _t6  ; Δ{_t5 _t6}
      let _d1000000 = rtcall axion_strcat "'\\''" _t4  ; Δ{_t4} · makes String
      let _d1000000 = rtcall axion_strcat "\n" _t5  ; Δ{_t5} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
      let _d1000000 = rtcall axion_strcat _t2 _t3  ; Δ{_t2 _t3} · makes String
      let _d1000000 = rtcall axion_strcat _t5 _t6  ; Δ{_t5 _t6} · makes String
      let _d1000000 = rtcall axion_strcat rep _t4  ; Δ{_t4} · makes String
      let _d1000000 = rtcall axion_strcat s _t1  ; Δ{_t1} · makes String
      let _d1000001 = call doUserCmd cwd sel marked prog hidden rows cols raw _t7  ; Δ{_t7}
      let _d1000001 = rtcall axion_strcat _t5 _t7  ; Δ{_t5 _t7} · makes String
      let _d1000001 = rtcall axion_strcat _t5 _t7  ; Δ{_t5 _t7} · makes String
      let _d1000001 = rtcall axion_strcat _t6 _t8  ; Δ{_t6 _t8} · makes String
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
      let _t0 = call baseName y  ; Δ{} · makes String
      let _t0 = call eq$String x y  ; Δ{}
      let _t0 = call hasInfix q y  ; Δ{}
      let _t0 = call kmKey y  ; Δ{} · makes String
      let _t0 = call kmKey y  ; Δ{} · makes String
      let _t0 = call length ys  ; Δ{}
      let _t0 = call neStr _cap0 y  ; Δ{y ys}
      let _t0 = call nonEmpty y  ; Δ{y ys}
      let _t0 = call rdtApp zs ys  ; Δ{z zs} · moves{zs} · makes List$String
      let _t0 = call rdtCode y  ; Δ{y ys} · makes String
      let _t0 = call rdtRawName y  ; Δ{y ys} · makes String
      let _t0 = call rdtVisible hidden fq y  ; Δ{y ys}
      let _t0 = call shQuote y  ; Δ{} · makes String
      let _t0 = call stripSlash y  ; Δ{} · makes String
      let _t0 = call stripSlash y  ; Δ{} · makes String
      let _t0 = call stripSlash y  ; Δ{} · makes String
      let _t0 = call unlines ss  ; Δ{} · makes String
      let _t0 = callclo p y  ; Δ{}
      let _t0 = con Cons z acc  ; Δ{z zs} · moves{z} · makes List$String
      let _t0 = con Nil  ; Δ{} · makes List$String
      let _t1 = < i hi  ; Δ{}
      let _t1 = call </> cwd _t0  ; Δ{_t0} · makes String
      let _t1 = call bnGo ys  ; Δ{_t0} · makes String
      let _t1 = call hasPrefix q _t0  ; Δ{_t0}
      let _t1 = call lsCmd cwd hidden  ; Δ{} · makes String
      let _t1 = call map$$rdtCode ys  ; Δ{_t0 ys} · moves{ys} · makes List$String
      let _t1 = call map$$rdtRawName ys  ; Δ{_t0 ys} · moves{ys} · makes List$String
      let _t1 = call qlGo ys  ; Δ{_t0} · makes String
      let _t1 = call rdtRev ds _t0  ; Δ{_t0} · moves{_t0} · makes List$String
      let _t1 = call seqStarts _t0 acc  ; Δ{_t0}
      let _t1 = call sortFile 0  ; Δ{} · makes String
      let _t1 = call sortFile 0  ; Δ{} · makes String
      let _t1 = call termCols 0  ; Δ{}
      let _t1 = rtcall axion_str_cmp _t0 k  ; Δ{_t0}
      let _t1 = rtcall axion_str_cmp _t0 target  ; Δ{_t0}
      let _t1 = rtcall axion_strcat "\n" _t0  ; Δ{_t0} · makes String
      let _t10 = + i 1  ; Δ{}
      let _t10 = call rdtRaw _t0 hidden _t9  ; Δ{_t0 _t9} · makes String
      let _t10 = call trim _t9  ; Δ{_t0 _t9} · makes String
      let _t10 = rtcall axion_read_key 0  ; Δ{} · makes String
      let _t10 = rtcall axion_str_at 0 k  ; Δ{}
      let _t10 = rtcall axion_str_cmp key "g"  ; Δ{}
      let _t11 = == _t10 0  ; Δ{}
      let _t11 = == _t10 27  ; Δ{}
      let _t11 = call rdtRaw _t0 hidden _t10  ; Δ{_t0 _t10} · makes String
      let _t11 = rtcall axion_read_key 0  ; Δ{} · makes String
      let _t11 = rtcall axion_read_key 0  ; Δ{} · makes String
      let _t2 = - sel mx  ; Δ{}
      let _t2 = == _t1 0  ; Δ{}
      let _t2 = == _t1 0  ; Δ{}
      let _t2 = == c 10  ; Δ{}
      let _t2 = call >=$Int i n  ; Δ{}
      let _t2 = call >=$Int i n  ; Δ{}
      let _t2 = call countLines raw  ; Δ{}
      let _t2 = call countLines raw  ; Δ{}
      let _t2 = call editorCmd 0  ; Δ{} · makes String
      let _t2 = call hasInfix "x-7z" m  ; Δ{}
      let _t2 = call imageDelayMs  ; Δ{}
      let _t2 = call lsCmd cwd hidden  ; Δ{} · makes String
      let _t2 = call resetSeq  ; Δ{} · makes String
      let _t2 = call selPath cwd hidden sel  ; Δ{} · makes String
      let _t2 = call shQuote cwd  ; Δ{} · makes String
      let _t2 = call userCmdTty cwd raw sel cmd  ; Δ{} · makes String
      let _t2 = con Nil  ; Δ{_t1} · makes List$String
      let _t2 = if _t0 then
      let _t2 = rtcall axion_read_file _t1  ; Δ{_t1} · makes String
      let _t2 = rtcall axion_read_file _t1  ; Δ{_t1} · makes String
      let _t2 = rtcall axion_read_key 0  ; Δ{} · makes String
      let _t2 = rtcall axion_run _t1  ; Δ{_t1} · makes String
      let _t2 = rtcall axion_strcat " " _t1  ; Δ{_t0 _t1} · makes String
      let _t2 = rtcall axion_strcat "\n" _t1  ; Δ{_t0 _t1} · makes String
      let _t2 = rtcall axion_strcat _t1 "\n"  ; Δ{_t1} · makes String
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 2  ; Δ{}
      let _t3 = + j 1  ; Δ{}
      let _t3 = + j 1  ; Δ{}
      let _t3 = - i 1  ; Δ{}
      let _t3 = > _t2 0  ; Δ{}
      let _t3 = > _t2 0  ; Δ{}
      let _t3 = call baseName dest  ; Δ{} · makes String
      let _t3 = call envOr "SHELL" "sh"  ; Δ{_t2} · makes String
      let _t3 = call joinPaths cwd ys  ; Δ{_t2} · makes String
      let _t3 = call markCount marked  ; Δ{}
      let _t3 = call rdtRev fs _t2  ; Δ{_t1 _t2} · moves{_t2} · makes List$String
      let _t3 = call readMainKeyTO _t2  ; Δ{} · makes String
      let _t3 = call selPath cwd hidden sel  ; Δ{_t2} · makes String
      let _t3 = call shQuote _t2  ; Δ{_t2} · makes String
      let _t3 = call trim _t2  ; Δ{_t2} · makes String
      let _t3 = call trim _t2  ; Δ{_t2} · makes String
      let _t3 = call videoCmd path cols rows  ; Δ{} · makes String
      let _t3 = call writeCaps 0  ; Δ{}
      let _t3 = if _t1 then
      let _t3 = putStr _t2  ; Δ{_t2}
      let _t3 = rtcall axion_run _t2  ; Δ{_t2} · makes String
      let _t3 = rtcall axion_str_at i s  ; Δ{}
      let _t3 = rtcall axion_str_len key  ; Δ{}
      let _t3 = rtcall axion_system "test -t 0 && stty sane 2>/dev/null"  ; Δ{}
      let _t3 = rtcall axion_system _t2  ; Δ{_t2}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + sel n  ; Δ{}
      let _t4 = - j 1  ; Δ{}
      let _t4 = - j i  ; Δ{}
      let _t4 = > _t3 0  ; Δ{}
      let _t4 = > _t3 2  ; Δ{}
      let _t4 = call audioExts  ; Δ{} · makes List$String
      let _t4 = call audioExts  ; Δ{} · makes List$String
      let _t4 = call audioExts  ; Δ{} · makes List$String
      let _t4 = call hasPrefix "application/pdf" mime  ; Δ{}
      let _t4 = call infoMime _t1  ; Δ{_t1} · makes String
      let _t4 = call prefetch cwd sel rows raw cols  ; Δ{}
      let _t4 = call rdtIsDir y  ; Δ{y ys}
      let _t4 = call shEsc s _t3 n  ; Δ{} · makes String
      let _t4 = call shQuote _t3  ; Δ{_t2 _t3} · makes String
      let _t4 = call spGo cmd rep _t3  ; Δ{} · makes String
      let _t4 = if _t3 then
      let _t4 = rtcall axion_str_at 0 k  ; Δ{}
      let _t4 = rtcall axion_str_at 0 k  ; Δ{}
      let _t4 = rtcall axion_str_at 0 k  ; Δ{}
      let _t4 = rtcall axion_str_at _t3 s  ; Δ{}
      let _t4 = rtcall axion_str_cmp a "top"  ; Δ{}
      let _t4 = rtcall axion_str_cmp b "C"  ; Δ{}
      let _t4 = rtcall axion_str_cmp prog "ln -s"  ; Δ{}
      let _t4 = rtcall axion_str_cmp ty "b"  ; Δ{}
      let _t4 = rtcall axion_str_cmp ty "b"  ; Δ{}
      let _t4 = rtcall axion_str_len b1  ; Δ{b1 k}
      let _t4 = rtcall axion_strcat " && " _t3  ; Δ{_t2 _t3} · makes String
      let _t4 = rtcall axion_strcat "stat -- " _t3  ; Δ{_t3} · makes String
      let _t4 = rtcall axion_strcat _t3 "? [y/N] "  ; Δ{_t3} · makes String
      let _t5 = * acc 10  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t5 = == _t4 0  ; Δ{k}
      let _t5 = == _t4 0  ; Δ{}
      let _t5 = == _t4 0  ; Δ{}
      let _t5 = == _t4 0  ; Δ{}
      let _t5 = == _t4 0  ; Δ{}
      let _t5 = == _t4 0  ; Δ{}
      let _t5 = call elemBy$String e _t4  ; Δ{_t4}
      let _t5 = call elemBy$String e _t4  ; Δ{_t4}
      let _t5 = call elemBy$String e _t4  ; Δ{_t4}
      let _t5 = call hasPrefix "!" a  ; Δ{a}
      let _t5 = call nEntries cwd hidden  ; Δ{}
      let _t5 = call previewImage cwd sel rows raw cols _t4  ; Δ{_t4}
      let _t5 = call searchPrompt rows acc  ; Δ{} · makes String
      let _t5 = call selPath cwd hidden sel  ; Δ{} · makes String
      let _t5 = call t2n s _t4  ; Δ{} · makes String
      let _t5 = call toLower fq  ; Δ{nm} · makes String
      let _t5 = call wrapSel _t4 total  ; Δ{}
      let _t5 = if _t4 then
      let _t5 = rtcall axion_run _t4  ; Δ{_t4} · makes String
      let _t5 = rtcall axion_str_at 0 key  ; Δ{fav}
      let _t5 = rtcall axion_str_len item  ; Δ{}
      let _t5 = rtcall axion_strcat " " _t4  ; Δ{_t2 _t4} · makes String
      let _t5 = rtcall axion_strcat "overwrite " _t4  ; Δ{_t4} · makes String
      let _t5 = rtcall axion_strcat _t2 _t4  ; Δ{_t2 _t4} · makes String
      let _t5 = rtcall axion_substr i 1 cmd  ; Δ{} · makes String
      let _t5 = rtcall axion_substr i 1 s  ; Δ{} · makes String
      let _t5 = rtcall axion_substr i _t4 s  ; Δ{} · makes String
      let _t6 = + i 1  ; Δ{_t5}
      let _t6 = + i 1  ; Δ{_t5}
      let _t6 = - _t5 1  ; Δ{}
      let _t6 = call </> cwd nm  ; Δ{_t5} · makes String
      let _t6 = call <=$Int _t5 57  ; Δ{fav}
      let _t6 = call clampSel sel _t5  ; Δ{}
      let _t6 = call clipGo s j n vis w  ; Δ{_t5} · makes String
      let _t6 = call nEntries cwd hidden  ; Δ{}
      let _t6 = call nEntries cwd hidden  ; Δ{}
      let _t6 = call okOrErr _t5 "paste failed" rows  ; Δ{}
      let _t6 = call toLower nm  ; Δ{_t5 nm} · makes String
      let _t6 = putStr _t5  ; Δ{_t5}
      let _t6 = putStr _t5  ; Δ{_t5}
      let _t6 = rtcall axion_read_key 0  ; Δ{} · makes String
      let _t6 = rtcall axion_str_at 0 k  ; Δ{}
      let _t6 = rtcall axion_str_at 0 k  ; Δ{}
      let _t6 = rtcall axion_str_at _t5 cmd  ; Δ{}
      let _t6 = rtcall axion_str_at i s  ; Δ{}
      let _t6 = rtcall axion_str_cmp k "k"  ; Δ{}
      let _t6 = rtcall axion_strcat "cd " _t5  ; Δ{_t5} · makes String
      let _t6 = rtcall axion_strcat _t2 _t5  ; Δ{_t2 _t5} · makes String
      let _t6 = rtcall axion_substr i 1 s  ; Δ{} · makes String
      let _t6 = rtcall axion_substr i plen s  ; Δ{} · makes String
      let _t7 = + _t6 1  ; Δ{}
      let _t7 = + _t6 1  ; Δ{}
      let _t7 = + i 1  ; Δ{_t6}
      let _t7 = - _t6 48  ; Δ{}
      let _t7 = - sel 1  ; Δ{}
      let _t7 = == _t6 0  ; Δ{}
      let _t7 = == _t6 27  ; Δ{}
      let _t7 = call >=$Int vis w  ; Δ{}
      let _t7 = call filterFile 0  ; Δ{_t0} · makes String
      let _t7 = call shEsc s _t6 n  ; Δ{_t5} · makes String
      let _t7 = call spGo cmd rep _t6  ; Δ{_t5} · makes String
      let _t7 = call termCols 0  ; Δ{_t0}
      let _t7 = rtcall axion_str_cmp _t6 pat  ; Δ{_t6}
      let _t7 = rtcall axion_substr 1 _t6 item  ; Δ{} · makes String
      let _t7 = rtcall axion_system _t6  ; Δ{_t6}
      let _t7 = rtcall axion_system _t6  ; Δ{_t6}
      let _t8 = + _t5 _t7  ; Δ{}
      let _t8 = call clampSel sel _t7  ; Δ{}
      let _t8 = call clampSel sel _t7  ; Δ{}
      let _t8 = call countLines raw  ; Δ{}
      let _t8 = call filterFile 0  ; Δ{_t0} · makes String
      let _t8 = call hasPrefix "cd " item  ; Δ{}
      let _t8 = call lines raw  ; Δ{} · makes List$String
      let _t8 = call t2n s _t7  ; Δ{_t6} · makes String
      let _t8 = if _t4 then
      let _t8 = rtcall axion_read_file _t7  ; Δ{_t0 _t7} · makes String
      let _t9 = + i plen  ; Δ{}
      let _t9 = call hasPrefix "video/" mime  ; Δ{}
      let _t9 = call searchSel _t8 acc osel  ; Δ{_t8}
      let _t9 = call trim _t8  ; Δ{_t0 _t8} · makes String
      let _t9 = call wrapSel _t7 _t8  ; Δ{}
      let _t9 = rtcall axion_read_file _t8  ; Δ{_t0 _t8} · makes String
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
      ret ""  ; Δ{}
      ret "-S"  ; Δ{}
      ret "1;35"  ; Δ{}
      ret "\u{1b}"  ; Δ{}
      ret "\u{f1c8}"  ; Δ{}
      ret "j"  ; Δ{}
      ret "k"  ; Δ{}
      ret "moving"  ; Δ{}
      ret "vi"  ; Δ{}
      ret "video"  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret + _t2 1  ; Δ{}
      ret + c 32  ; Δ{}
      ret + i 1  ; Δ{}
      ret + i 1  ; Δ{}
      ret - 0 1  ; Δ{}
      ret - n 1  ; Δ{}
      ret 0  ; Δ{fav}
      ret 0  ; Δ{nm}
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
      ret 1  ; Δ{nm}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret == _t4 10  ; Δ{}
      ret == _t4 58  ; Δ{}
      ret == _t6 10  ; Δ{}
      ret == _t6 115  ; Δ{}
      ret == _t7 0  ; Δ{}
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
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret _d1000001  ; Δ{}
      ret _d1000001  ; Δ{}
      ret acc  ; Δ{}
      ret acc  ; Δ{}
      ret best  ; Δ{}
      ret c  ; Δ{}
      ret call </> cwd nm  ; Δ{} · makes String
      ret call <=$Int _t3 126  ; Δ{}
      ret call <=$Int _t4 57  ; Δ{}
      ret call <=$Int _t4 57  ; Δ{}
      ret call clGo s _t3 n  ; Δ{}
      ret call confirm "overwrite existing file(s)? [y/N] " rows  ; Δ{}
      ret call doRunList cwd sel marked prog hidden rows cols raw key  ; Δ{}
      ret call dup nm  ; Δ{} · makes String
      ret call dup s  ; Δ{} · makes String
      ret call endSearch cwd marked prog hidden rows cols raw acc _t9  ; Δ{}
      ret call escFinal s _t3 n  ; Δ{}
      ret call escFinal s _t5 n  ; Δ{}
      ret call findChar c s _t3 n  ; Δ{}
      ret call infixGo q s _t5 lim  ; Δ{}
      ret call lastIndex c s _t4 i  ; Δ{}
      ret call lastIndex c s _t5 best  ; Δ{}
      ret call lnColor lsc  ; Δ{} · makes String
      ret call lnIcon icfg  ; Δ{} · makes String
      ret call loop cwd _t5 marked prog hidden rows cols raw  ; Δ{}
      ret call loop cwd _t9 marked prog hidden rows cols raw  ; Δ{}
      ret call loop cwd msel marked prog hidden rows cols raw  ; Δ{}
      ret call loop cwd sel marked prog hidden rows cols raw  ; Δ{}
      ret call loop cwd sel marked prog hidden rows cols raw  ; Δ{}
      ret call loop cwd sel marked prog hidden rows cols raw  ; Δ{}
      ret call lscEnd s _t3 n  ; Δ{}
      ret call lscScan s pat _t10 n plen  ; Δ{} · makes String
      ret call lscTake s _t9 n  ; Δ{} · makes String
      ret call matchBefore ys q _t0 hi _t4  ; Δ{}
      ret call nlScan s _t4  ; Δ{}
      ret call pixHeader "[image] " path mime px pw ph  ; Δ{} · makes String
      ret call rdtApp _t1 _t3  ; Δ{_t1 _t3} · moves{_t1 _t3} · makes List$String
      ret call rdtRev zs _t0  ; Δ{_t0 zs} · moves{_t0 zs} · makes List$String
      ret call readIntGo s _t4 _t8  ; Δ{} · makes Maybe$Int
      ret call reloop cwd 0 marked prog hidden rows  ; Δ{}
      ret call reloop cwd _t6 "" "" hidden rows  ; Δ{}
      ret call reloop cwd _t8 marked prog hidden rows  ; Δ{}
      ret call reloop cwd _t8 marked prog hidden rows  ; Δ{}
      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
      ret call reloop cwd sel marked prog hidden rows  ; Δ{}
      ret call settleKey cwd sel marked prog hidden rows cols raw poff _t3  ; Δ{_t3} · moves{_t3}
      ret call tabScan s _t4  ; Δ{}
      ret call trimEnd s _t4  ; Δ{}
      ret call trimStart s _t4  ; Δ{}
      ret call wordEnd s _t3 n  ; Δ{}
      ret callclo f x  ; Δ{x} · moves{x}
      ret case _t11 of
      ret case _t11 of
      ret case _t3 of
      ret case _t3 of
      ret case _t3 of
      ret case _t3 of
      ret case _t4 of
      ret case _t5 of
      ret case _t6 of
      ret case _t6 of
      ret case _t6 of
      ret case _t6 of
      ret case _t7 of
      ret case _t7 of
      ret case news of
      ret case tys of
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$String
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$String
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret d  ; Δ{}
      ret dflt  ; Δ{}
      ret dflt  ; Δ{}
      ret e  ; Δ{e} · moves{e}
      ret i  ; Δ{}
      ret i  ; Δ{}
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
      ret if _t0 then
      ret if _t0 then
      ret if _t1 then
      ret if _t1 then
      ret if _t11 then
      ret if _t11 then
      ret if _t2 then
      ret if _t2 then
      ret if _t2 then
      ret if _t2 then
      ret if _t2 then
      ret if _t2 then
      ret if _t2 then
      ret if _t3 then
      ret if _t3 then
      ret if _t4 then
      ret if _t4 then
      ret if _t5 then
      ret if _t5 then
      ret if _t5 then
      ret if _t5 then
      ret if _t5 then
      ret if _t5 then
      ret if _t5 then
      ret if _t5 then
      ret if _t5 then
      ret if _t5 then
      ret if _t6 then
      ret if _t7 then
      ret if _t7 then
      ret if _t7 then
      ret if _t8 then
      ret if _t8 then
      ret if _t9 then
      ret j  ; Δ{}
      ret j  ; Δ{}
      ret k  ; Δ{k} · moves{k}
      ret rtcall axion_read_key 0  ; Δ{} · makes String
      ret ys  ; Δ{}
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
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
    Cons z zs ->
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
    drop _t2 : String
    drop _t2 : String
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
    drop _t8 : String
    drop _t8 : String
    drop _t8 : String
    drop _t9 : String
    drop _t9 : String
    drop _t9 : String
    drop _t9 : String
    drop a : String
    drop acc : String
    drop acc : String
    drop b1 : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop c : String
    drop cc : String
    drop cc : String
    drop cc : String
    drop cc : String
    drop comp : String
    drop e : String
    drop e : String
    drop fav : String
    drop fav : String
    drop k : String
    drop kc : String
    drop key : String
    drop key : String
    drop km : String
    drop km : String
    drop l : String
    drop l : String
    drop nm : String
    drop s : String
    drop tb : String
    drop tb : String
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
    else
    else
    else
    else
    else
    else
    else
    else
    else
    else
    else
    else
    else
    else
    else
    else
    else
    else
    let _d1000000 = call confirm _t3 rows  ; Δ{_t3}
    let _d1000000 = call countLoop cwd sel marked prog hidden rows cols raw _t1  ; Δ{_t1}
    let _d1000000 = call doUserCmdTty cwd sel marked prog hidden rows raw _t3  ; Δ{_t3}
    let _d1000000 = call drawLines _t7 1 px pw ph  ; Δ{_t7} · makes String
    let _d1000000 = call drawLines _t8 1 px pw ph  ; Δ{_t8} · makes String
    let _d1000000 = call drawLinesAnsi _t7 1 px pw ph  ; Δ{_t7} · makes String
    let _d1000000 = call drawPreview _t0 _t1 _t2 mx mime poff  ; Δ{_t0} · makes String
    let _d1000000 = call dup c  ; Δ{c} · makes String
    let _d1000000 = call dup c  ; Δ{c} · makes String
    let _d1000000 = call dup c  ; Δ{c} · makes String
    let _d1000000 = call dup c  ; Δ{c} · makes String
    let _d1000000 = call dup c  ; Δ{c} · makes String
    let _d1000000 = call dup c  ; Δ{c} · makes String
    let _d1000000 = call dup c  ; Δ{c} · makes String
    let _d1000000 = call dup c  ; Δ{c} · makes String
    let _d1000000 = call dup c  ; Δ{c} · makes String
    let _d1000000 = call dup c  ; Δ{c} · makes String
    let _d1000000 = call dup cc  ; Δ{cc} · makes String
    let _d1000000 = call dup cc  ; Δ{cc} · makes String
    let _d1000000 = call flashFail _t3 rows  ; Δ{_t3}
    let _d1000000 = call gotoTo cwd sel marked prog hidden rows _t3  ; Δ{_t3}
    let _d1000000 = call previewPix _t5 cols rows mime  ; Δ{_t5}
    let _d1000000 = call reloop _t1 0 marked prog hidden rows  ; Δ{_t1}
    let _d1000000 = call reloop _t2 0 marked prog hidden rows  ; Δ{_t2}
    let _d1000000 = call reloop fav 0 marked prog hidden rows  ; Δ{fav}
    let _d1000000 = call runItem cwd sel marked prog hidden rows cols raw _t4  ; Δ{_t4}
    let _d1000000 = call seqNext km acc _t1  ; Δ{_t1} · makes String
    let _d1000000 = call seqResolve km _t3  ; Δ{_t3 km} · makes String
    let _d1000000 = call sizedCell _t3 listW prev  ; Δ{_t3} · makes String
    let _d1000000 = call stepCanon cwd sel marked prog hidden rows cols raw poff _t2  ; Δ{_t2}
    let _d1000000 = call toLower _t6  ; Δ{_t6} · makes String
    let _d1000000 = call trim _t9  ; Δ{_t9} · makes String
    let _d1000000 = call unlines _t2  ; Δ{_t2} · makes String
    let _d1000000 = call warmLoop _t3 _t4  ; Δ{_t3 _t4} · makes String
    let _d1000000 = call windowLines _t4 start mx  ; Δ{_t4} · makes List$String
    let _d1000000 = rtcall axion_mkdir_p _t3  ; Δ{_t3}
    let _d1000000 = rtcall axion_strcat "  " l  ; Δ{l} · makes String
    let _d1000000 = rtcall axion_strcat "  " tb  ; Δ{tb} · makes String
    let _d1000000 = rtcall axion_strcat _t1 "/"  ; Δ{_t1} · makes String
    let _d1000000 = rtcall axion_strcat _t3 _t5  ; Δ{_t3 _t5} · makes String
    let _d1000000 = rtcall axion_strcat _t6 _t10  ; Δ{_t10 _t6} · makes String
    let _d1000000 = rtcall axion_strcat a _t0  ; Δ{_t0} · makes String
    let _d1000000 = rtcall axion_strcat new _t2  ; Δ{_t2} · makes String
    let _d1000000 = rtcall axion_substr 0 n _t1  ; Δ{_t1} · makes String
    let _d1000000 = rtcall axion_system _t1  ; Δ{_t1}
    let _d1000000 = rtcall axion_system _t10  ; Δ{_t10}
    let _d1000000 = rtcall axion_system _t2  ; Δ{_t2}
    let _d1000000 = rtcall axion_system _t3  ; Δ{_t3}
    let _d1000000 = rtcall axion_system _t5  ; Δ{_t5}
    let _d1000000 = rtcall axion_write_file _t3 ""  ; Δ{_t3}
    let _d1000001 = call drawLines _t18 1 px pw ph  ; Δ{_t18} · makes String
    let _d1000001 = call warmLoop _t5 _t8  ; Δ{_t5 _t8} · makes String
    let _d1000001 = rtcall axion_strcat m _t3  ; Δ{_t3} · makes String
    let _d1000001 = rtcall axion_strcat mark _t8  ; Δ{_t8} · makes String
    let _d1000001 = rtcall axion_system _t18  ; Δ{_t18}
    let _d1000001 = rtcall axion_system _t4  ; Δ{_t4}
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
    let _t1 = + i 1  ; Δ{}
    let _t1 = + i 1  ; Δ{}
    let _t1 = + j 1  ; Δ{}
    let _t1 = + k 1  ; Δ{}
    let _t1 = - j 1  ; Δ{}
    let _t1 = < i 0  ; Δ{}
    let _t1 = < i 0  ; Δ{}
    let _t1 = < sel mx  ; Δ{}
    let _t1 = == c 9  ; Δ{}
    let _t1 = call <=$Int c 90  ; Δ{}
    let _t1 = call baseName path  ; Δ{} · makes String
    let _t1 = call classifyBody cwd hidden  ; Δ{} · makes String
    let _t1 = call dup dest  ; Δ{} · makes String
    let _t1 = call errDetail 0  ; Δ{} · makes String
    let _t1 = call findChar 10 s i n  ; Δ{}
    let _t1 = call grow " " n  ; Δ{} · makes String
    let _t1 = call hasInfix "tar" m  ; Δ{}
    let _t1 = call hasPrefix "." nm  ; Δ{nm}
    let _t1 = call icatCmd path cols rows  ; Δ{} · makes String
    let _t1 = call lines m  ; Δ{} · makes List$String
    let _t1 = call paneX cols  ; Δ{_t0}
    let _t1 = call previewOn cols  ; Δ{}
    let _t1 = call previewOn cols  ; Δ{}
    let _t1 = call rdtName ln  ; Δ{} · makes String
    let _t1 = call shQuote path  ; Δ{} · makes String
    let _t1 = rtcall axion_read_key 0  ; Δ{} · makes String
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at j s  ; Δ{}
    let _t1 = rtcall axion_str_len item  ; Δ{}
    let _t1 = rtcall axion_str_len q  ; Δ{}
    let _t1 = rtcall axion_str_len s  ; Δ{}
    let _t1 = rtcall axion_strcat acc k  ; Δ{} · makes String
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
    let _t2 = - _t1 2  ; Δ{}
    let _t2 = - idx 1  ; Δ{}
    let _t2 = - j i  ; Δ{}
    let _t2 = == _t1 27  ; Δ{}
    let _t2 = == _t1 39  ; Δ{}
    let _t2 = == _t1 58  ; Δ{}
    let _t2 = == _t1 91  ; Δ{}
    let _t2 = == _t1 c  ; Δ{}
    let _t2 = == i 0  ; Δ{}
    let _t2 = call </> cwd nm  ; Δ{} · makes String
    let _t2 = call >=$Int _t1 64  ; Δ{}
    let _t2 = call >=$Int _t1 n  ; Δ{}
    let _t2 = call bulkTmp 0  ; Δ{} · makes String
    let _t2 = call dup mime  ; Δ{_t1} · makes String
    let _t2 = call expandDir cwd nm  ; Δ{} · makes String
    let _t2 = call filter$$neStr p _t1  ; Δ{_t1} · moves{_t1} · makes List$String
    let _t2 = call hasInfix "\t" key  ; Δ{}
    let _t2 = call hasPrefix "video/" mime  ; Δ{}
    let _t2 = call isPctS cmd i  ; Δ{}
    let _t2 = call isSpace _t1  ; Δ{}
    let _t2 = call lines raw  ; Δ{} · makes List$String
    let _t2 = call lines raw  ; Δ{} · makes List$String
    let _t2 = call lines raw  ; Δ{} · makes List$String
    let _t2 = call lowerChar _t1  ; Δ{}
    let _t2 = call markCount marked  ; Δ{}
    let _t2 = call markSetCmd letter cwd  ; Δ{} · makes String
    let _t2 = call paneW cols  ; Δ{_t0}
    let _t2 = call pasteConfirmed cwd marked prog rows  ; Δ{}
    let _t2 = call pathMissing dest  ; Δ{}
    let _t2 = call readInt acc  ; Δ{} · makes Maybe$Int
    let _t2 = call scrollPipe poff ph  ; Δ{_t1} · makes String
    let _t2 = call selPathOf cwd raw i  ; Δ{} · makes String
    let _t2 = call selPathOf cwd raw sel  ; Δ{} · makes String
    let _t2 = call seqKey key  ; Δ{} · makes String
    let _t2 = call shQuote letter  ; Δ{} · makes String
    let _t2 = call termRows 0  ; Δ{}
    let _t2 = call trashDir 0  ; Δ{} · makes String
    let _t2 = call videoExts  ; Δ{} · makes List$String
    let _t2 = call videoExts  ; Δ{} · makes List$String
    let _t2 = call videoExts  ; Δ{} · makes List$String
    let _t2 = rtcall axion_str_at 0 k  ; Δ{k}
    let _t2 = rtcall axion_str_at 0 k  ; Δ{k}
    let _t2 = rtcall axion_str_at 0 k  ; Δ{}
    let _t2 = rtcall axion_str_at 0 k  ; Δ{}
    let _t2 = rtcall axion_str_at 0 k  ; Δ{}
    let _t2 = rtcall axion_str_at _t1 s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_cmp a "up"  ; Δ{}
    let _t2 = rtcall axion_str_cmp b "B"  ; Δ{}
    let _t2 = rtcall axion_str_cmp k "Y"  ; Δ{}
    let _t2 = rtcall axion_str_cmp k "j"  ; Δ{}
    let _t2 = rtcall axion_str_cmp prog "mv"  ; Δ{}
    let _t2 = rtcall axion_str_cmp s "-t"  ; Δ{}
    let _t2 = rtcall axion_str_cmp ty "l"  ; Δ{}
    let _t2 = rtcall axion_str_cmp ty "l"  ; Δ{}
    let _t2 = rtcall axion_str_len e  ; Δ{e v}
    let _t2 = rtcall axion_str_len line  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t2 = rtcall axion_strcat " " name  ; Δ{} · makes String
    let _t2 = rtcall axion_strcat ": " _t1  ; Δ{_t1} · makes String
    let _t2 = rtcall axion_strcat "\n" old  ; Δ{} · makes String
    let _t2 = rtcall axion_strcat _t1 " ) &"  ; Δ{_t1} · makes String
    let _t2 = rtcall axion_strcat acc k  ; Δ{} · makes String
    let _t2 = rtcall axion_strcat s s  ; Δ{} · makes String
    let _t2 = rtcall axion_substr i _t1 s  ; Δ{} · makes String
    let _t2 = showInt col  ; Δ{_t1} · makes String
    let _t3 = + from 1  ; Δ{_t2}
    let _t3 = - 0 1  ; Δ{_t2}
    let _t3 = - _t2 1  ; Δ{}
    let _t3 = - _t2 i  ; Δ{}
    let _t3 = - _t2 i  ; Δ{}
    let _t3 = - _t2 k  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = == _t2 1  ; Δ{}
    let _t3 = == _t2 10  ; Δ{}
    let _t3 = == _t2 13  ; Δ{}
    let _t3 = == _t2 27  ; Δ{k}
    let _t3 = == _t2 9  ; Δ{}
    let _t3 = == _t2 9  ; Δ{}
    let _t3 = == _t2 c  ; Δ{}
    let _t3 = > _t2 0  ; Δ{e v}
    let _t3 = call </> cwd _t0  ; Δ{_t0} · makes String
    let _t3 = call </> cwd _t0  ; Δ{_t0} · makes String
    let _t3 = call >=$Int _t2 48  ; Δ{}
    let _t3 = call >=$Int _t2 49  ; Δ{}
    let _t3 = call absPath _t2  ; Δ{_t2} · makes String
    let _t3 = call bookmarkFile 0  ; Δ{_t2} · makes String
    let _t3 = call codeExts  ; Δ{e} · makes List$String
    let _t3 = call countLines raw  ; Δ{}
    let _t3 = call elemBy$String e _t2  ; Δ{_t2}
    let _t3 = call elemBy$String e _t2  ; Δ{_t2}
    let _t3 = call elemBy$String e _t2  ; Δ{_t2}
    let _t3 = call findChar 10 s i _t2  ; Δ{}
    let _t3 = call findChar 10 s i n  ; Δ{}
    let _t3 = call fromMaybe 1 _t2  ; Δ{_t2} · moves{_t2}
    let _t3 = call hasPrefix "/" nm  ; Δ{}
    let _t3 = call isDigit _t2  ; Δ{}
    let _t3 = call isSpace _t2  ; Δ{}
    let _t3 = call isSpace _t2  ; Δ{}
    let _t3 = call paneW cols  ; Δ{}
    let _t3 = call resolveSeq km key  ; Δ{km} · makes String
    let _t3 = call searchSel _t2 acc osel  ; Δ{_t2}
    let _t3 = call selPath cwd hidden sel  ; Δ{_t2} · makes String
    let _t3 = call shQuote _t2  ; Δ{_t2} · makes String
    let _t3 = call shQuote _t2  ; Δ{_t2} · makes String
    let _t3 = call trashPrompt _t2  ; Δ{} · makes String
    let _t3 = call winPaths cwd sel raw  ; Δ{} · makes String
    let _t3 = call wordEnd s i n  ; Δ{}
    let _t3 = rtcall axion_chr _t2  ; Δ{} · makes String
    let _t3 = rtcall axion_str_at 0 key  ; Δ{fav}
    let _t3 = rtcall axion_str_at i cmd  ; Δ{}
    let _t3 = rtcall axion_str_cmp q _t2  ; Δ{_t2}
    let _t3 = rtcall axion_str_len fq  ; Δ{nm}
    let _t3 = rtcall axion_str_len p  ; Δ{}
    let _t3 = rtcall axion_str_len s  ; Δ{}
    let _t3 = rtcall axion_str_len s  ; Δ{}
    let _t3 = rtcall axion_strcat "  " _t2  ; Δ{_t1 _t2} · makes String
    let _t3 = rtcall axion_strcat " 2>/dev/null" _t2  ; Δ{_t1 _t2} · makes String
    let _t3 = rtcall axion_strcat "( " _t2  ; Δ{_t2} · makes String
    let _t3 = rtcall axion_strcat _t2 "H"  ; Δ{_t1 _t2} · makes String
    let _t3 = rtcall axion_strcat label _t2  ; Δ{_t2} · makes String
    let _t3 = rtcall axion_strcat mark _t2  ; Δ{_t2} · makes String
    let _t3 = rtcall axion_strcat p "\n"  ; Δ{} · makes String
    let _t3 = rtcall axion_substr 2 _t2 item  ; Δ{} · makes String
    let _t3 = rtcall axion_substr i _t2 s  ; Δ{} · makes String
    let _t4 = + _t3 1  ; Δ{}
    let _t4 = + i 1  ; Δ{_t3}
    let _t4 = + j 1  ; Δ{_t3}
    let _t4 = - _t3 1  ; Δ{}
    let _t4 = - _t3 1  ; Δ{}
    let _t4 = - _t3 1  ; Δ{}
    let _t4 = - _t3 i  ; Δ{}
    let _t4 = - _t3 k  ; Δ{}
    let _t4 = == _t3 0  ; Δ{nm}
    let _t4 = == _t3 0  ; Δ{}
    let _t4 = == _t3 37  ; Δ{}
    let _t4 = call >=$Int _t3 49  ; Δ{fav}
    let _t4 = call anyCollide cwd marked  ; Δ{}
    let _t4 = call classifyBody cwd hidden  ; Δ{} · makes String
    let _t4 = call countLines raw  ; Δ{}
    let _t4 = call dropFirstLine c  ; Δ{c} · makes String
    let _t4 = call entryIcon icfg ty raw  ; Δ{} · makes String
    let _t4 = call hasInfix "\t" a  ; Δ{a}
    let _t4 = call hasPrefix "!" item  ; Δ{}
    let _t4 = call matchBefore _t2 q 0 from _t3  ; Δ{_t2}
    let _t4 = call matchFrom _t2 q 0 _t3  ; Δ{_t2}
    let _t4 = call maxItems rows  ; Δ{}
    let _t4 = call okToClobber _t2 _t3 rows  ; Δ{_t2 _t3}
    let _t4 = call popItem 0  ; Δ{} · makes String
    let _t4 = call prefetchBodyKitten  ; Δ{_t3} · makes String
    let _t4 = call quoteLines marked  ; Δ{_t3} · makes String
    let _t4 = call shQuote _t3  ; Δ{_t2 _t3} · makes String
    let _t4 = call wrapSel _t2 _t3  ; Δ{}
    let _t4 = if _t2 then
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
    let _t5 = - left 1  ; Δ{_t3}
    let _t5 = - listW 3  ; Δ{_t4}
    let _t5 = == _t4 0  ; Δ{k}
    let _t5 = == _t4 13  ; Δ{}
    let _t5 = call clampSel sel _t4  ; Δ{}
    let _t5 = call codePreviewCmd path poff ph  ; Δ{} · makes String
    let _t5 = call errRedir  ; Δ{_t3 _t4} · makes String
    let _t5 = call paneX cols  ; Δ{}
    let _t5 = call prefetchCmd cwd sel rows raw cols  ; Δ{} · makes String
    let _t5 = call selPathOf cwd raw sel  ; Δ{} · makes String
    let _t5 = call toLowerGo s _t4 n  ; Δ{_t3} · makes String
    let _t5 = call winPaths cwd sel raw  ; Δ{} · makes String
    let _t5 = if _t2 then
    let _t5 = if _t3 then
    let _t5 = rtcall axion_str_cmp _t4 p  ; Δ{_t4}
    let _t5 = rtcall axion_str_cmp key "k"  ; Δ{}
    let _t5 = rtcall axion_strcat "ls -Up -- " _t4  ; Δ{_t4} · makes String
    let _t5 = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
    let _t5 = rtcall axion_strcat _t4 "; t=$(printf '\\t'); [ -f \"$f\" ] && while IFS=\"$t\" read -r k v; do [ \"$k\" = \"$L\" ] && { printf '%s' \"$v\"; break; }; done < \"$f\""  ; Δ{_t2 _t4} · makes String
    let _t5 = rtcall axion_strcat acc _t4  ; Δ{_t4} · makes String
    let _t5 = rtcall axion_strcat label _t4  ; Δ{_t4} · makes String
    let _t6 = - _t5 1  ; Δ{}
    let _t6 = == _t5 0  ; Δ{}
    let _t6 = call csi _t5  ; Δ{_t5} · makes String
    let _t6 = call paneW cols  ; Δ{_t5}
    let _t6 = call sizedCell name _t5 prev  ; Δ{_t4} · makes String
    let _t6 = call termRows 0  ; Δ{}
    let _t6 = call wlGo s _t4 n _t5  ; Δ{_t3} · makes List$String
    let _t6 = con Nil  ; Δ{_t5} · makes List$String
    let _t6 = rtcall axion_run _t5  ; Δ{_t5} · makes String
    let _t6 = rtcall axion_run _t5  ; Δ{_t5} · makes String
    let _t6 = rtcall axion_str_len q  ; Δ{}
    let _t6 = rtcall axion_strcat "; do b=${src##*/}; dest=\"$d/$b\"; n=1; while [ -e \"$dest\" ]; do dest=\"$d/$b.$n\"; n=$((n+1)); done; mv -- \"$src\" \"$dest\" && printf '%s\\t%s\\n' \"$dest\" \"$src\" >> \"$L\"; done" _t5  ; Δ{_t3 _t4 _t5} · makes String
    let _t6 = rtcall axion_strcat "; f=" _t5  ; Δ{_t2 _t5} · makes String
    let _t6 = rtcall axion_substr _t2 _t5 s  ; Δ{} · makes String
    let _t7 = call lines _t6  ; Δ{_t6} · makes List$String
    let _t7 = call lines _t6  ; Δ{_t6} · makes List$String
    let _t7 = call maxItems rows  ; Δ{_t5}
    let _t7 = call paint "90" "│"  ; Δ{_t6} · makes String
    let _t7 = call paneX cols  ; Δ{}
    let _t7 = con Cons "(install kitty or img2sixel for a pixel preview)" _t6  ; Δ{_t5 _t6} · moves{_t6} · makes List$String
    let _t7 = if _t5 then
    let _t7 = rtcall axion_strcat " " _t6  ; Δ{_t4 _t6} · makes String
    let _t7 = rtcall axion_strcat _t2 _t6  ; Δ{_t2 _t6} · makes String
    let _t7 = rtcall axion_strcat _t4 _t6  ; Δ{_t3 _t4 _t6} · makes String
    let _t7 = rtcall axion_substr _t5 _t6 s  ; Δ{} · makes String
    let _t8 = + poff 1  ; Δ{}
    let _t8 = + r 1  ; Δ{_t6 _t7}
    let _t8 = call hasPrefix "image/" mime  ; Δ{}
    let _t8 = call paneW cols  ; Δ{}
    let _t8 = call prefetchBodySixel _t6 _t7  ; Δ{_t5} · makes String
    let _t8 = con Cons _t5 _t7  ; Δ{_t5 _t7} · moves{_t5 _t7} · makes List$String
    let _t8 = if _t5 then
    let _t8 = rtcall axion_str_cmp _t7 q  ; Δ{_t7}
    let _t8 = rtcall axion_strcat "; L=\"$HOME/.cache/axfm/trashlog\"; mkdir -p \"$d\" \"${L%/*}\" && for src in " _t7  ; Δ{_t3 _t7} · makes String
    let _t8 = rtcall axion_strcat "L=" _t7  ; Δ{_t7} · makes String
    let _t8 = rtcall axion_strcat _t4 _t7  ; Δ{_t4 _t7} · makes String
    let _t9 = call maxItems rows  ; Δ{}
    let _t9 = call sepGo col _t8 mx  ; Δ{_t6 _t7} · makes String
    let _t9 = rtcall axion_run _t8  ; Δ{_t8} · makes String
    let _t9 = rtcall axion_strcat _t3 _t8  ; Δ{_t3 _t8} · makes String
    let _t9 = showInt _t8  ; Δ{} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let b1 = rtcall axion_read_key_timeout 25  ; Δ{k} · makes String
    let e = rtcall axion_getenv "EDITOR"  ; Δ{v} · makes String
    let j = call findChar 10 s i n  ; Δ{}
    let j = call findChar 10 s i n  ; Δ{}
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
    ret "1;31"  ; Δ{}
    ret "1;32"  ; Δ{}
    ret "1;34"  ; Δ{}
    ret "1;35"  ; Δ{}
    ret "1;36"  ; Δ{}
    ret "\u{f07b}"  ; Δ{}
    ret "\u{f0c1}"  ; Δ{}
    ret "\u{f127}"  ; Δ{}
    ret "\u{f1c5}"  ; Δ{}
    ret "\u{f489}"  ; Δ{}
    ret "chmod +x -- "  ; Δ{}
    ret "chmod -x -- "  ; Δ{}
    ret "d"  ; Δ{}
    ret "f"  ; Δ{}
    ret "image"  ; Δ{}
    ret "j"  ; Δ{}
    ret "k"  ; Δ{}
    ret "ls -Ap --group-directories-first $o -- "  ; Δ{}
    ret "ls -p --group-directories-first $o -- "  ; Δ{}
    ret "trashing"  ; Δ{}
    ret + 1 _t4  ; Δ{}
    ret - 0 1  ; Δ{}
    ret - 0 1  ; Δ{}
    ret - rows 3  ; Δ{}
    ret 0  ; Δ{fav}
    ret 0  ; Δ{k}
    ret 0  ; Δ{tys}
    ret 0  ; Δ{tys}
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
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{nm}
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
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret == _t2 0  ; Δ{}
    ret == _t2 27  ; Δ{k}
    ret == _t2 rows  ; Δ{}
    ret == _t5 0  ; Δ{}
    ret == _t8 0  ; Δ{}
    ret == x y  ; Δ{}
    ret > total 0  ; Δ{tys}
    ret > total 0  ; Δ{tys}
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
    ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
    ret _d1000001  ; Δ{}
    ret _d1000001  ; Δ{}
    ret _d1000002  ; Δ{}
    ret a  ; Δ{}
    ret a  ; Δ{}
    ret a  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret best  ; Δ{}
    ret c  ; Δ{}
    ret call <=$Int c 57  ; Δ{}
    ret call >=$Int i n  ; Δ{}
    ret call >=$Int i n  ; Δ{}
    ret call applyCount cwd sel marked prog hidden rows cols raw k _t3  ; Δ{}
    ret call bottomMatch raw q from  ; Δ{}
    ret call bulkRun cwd marked _t2  ; Δ{_t2} · moves{_t2}
    ret call catOrBuiltin lsc ext  ; Δ{} · makes String
    ret call catOrBuiltinIcon icfg ext  ; Δ{} · makes String
    ret call clip plain listW  ; Δ{} · makes String
    ret call colorForExt ext  ; Δ{} · makes String
    ret call consLine s i n _t1  ; Δ{} · makes List$String
    ret call consWord s i n _t3  ; Δ{} · makes List$String
    ret call dirColor lsc  ; Δ{} · makes String
    ret call dirIcon icfg  ; Δ{} · makes String
    ret call doPasteRun cwd sel marked prog hidden rows  ; Δ{}
    ret call doPasteRun cwd sel marked prog hidden rows  ; Δ{}
    ret call drawSep _t0 mx  ; Δ{} · makes String
    ret call dup a  ; Δ{} · makes String
    ret call dup acc  ; Δ{} · makes String
    ret call dup d  ; Δ{} · makes String
    ret call dup dflt  ; Δ{} · makes String
    ret call dup key  ; Δ{} · makes String
    ret call dup line  ; Δ{} · makes String
    ret call dup old  ; Δ{} · makes String
    ret call dup s  ; Δ{} · makes String
    ret call dup s  ; Δ{} · makes String
    ret call dup s  ; Δ{} · makes String
    ret call dup s  ; Δ{} · makes String
    ret call endSearch cwd marked prog hidden rows cols raw acc _t3  ; Δ{}
    ret call fit plain listW  ; Δ{} · makes String
    ret call flashFail label rows  ; Δ{}
    ret call frameWait cwd sel marked prog hidden rows cols raw poff  ; Δ{}
    ret call fullWait cwd sel marked prog hidden rows cols raw poff  ; Δ{}
    ret call grow _t2 need  ; Δ{_t2} · moves{_t2} · makes String
    ret call hasPrefix "~/" nm  ; Δ{}
    ret call hasPrefix acc b  ; Δ{}
    ret call iconForExt ext  ; Δ{} · makes String
    ret call kittenRenderSrc _t3 _t4 _t6 0  ; Δ{} · makes String
    ret call loGo s _t2 _t4 n  ; Δ{}
    ret call loop cwd _t4 marked prog hidden rows cols raw  ; Δ{}
    ret call loop cwd sel marked prog hidden rows cols raw  ; Δ{}
    ret call loop cwd sel marked prog hidden rows cols raw  ; Δ{}
    ret call loop cwd sel marked prog hidden rows cols raw  ; Δ{}
    ret call markInfo marked prog  ; Δ{} · makes String
    ret call matchIndex xs acc 0 dflt  ; Δ{}
    ret call metaShow info  ; Δ{} · makes String
    ret call nextOrTop raw q from _t4  ; Δ{}
    ret call openFile cwd sel marked prog hidden rows  ; Δ{}
    ret call openOther cwd sel marked prog hidden rows  ; Δ{}
    ret call openText cwd sel marked prog hidden rows  ; Δ{}
    ret call paint "7" cell  ; Δ{} · makes String
    ret call paint col cell  ; Δ{} · makes String
    ret call pasteIfYes cwd sel marked prog hidden rows _t2  ; Δ{}
    ret call pollKey cwd sel marked prog hidden rows cols raw poff  ; Δ{}
    ret call prevOrBottom raw q from _t4  ; Δ{}
    ret call rdtName ln  ; Δ{} · makes String
    ret call readIntGo s 0 0  ; Δ{} · makes Maybe$Int
    ret call reloop cwd _t5 marked prog hidden _t6  ; Δ{}
    ret call reloop cwd sel marked prog hidden rows  ; Δ{}
    ret call reloop cwd sel marked prog hidden rows  ; Δ{}
    ret call reloop cwd sel marked prog hidden rows  ; Δ{}
    ret call reloop cwd sel marked prog hidden rows  ; Δ{}
    ret call reloopIntoNative cwd child marked prog hidden rows  ; Δ{}
    ret call reloopIntoShell cwd child marked prog hidden rows  ; Δ{}
    ret call reloopNative cwd sel marked prog hidden rows  ; Δ{}
    ret call reloopShell cwd sel marked prog hidden rows  ; Δ{}
    ret call resizeCheck cwd sel marked prog hidden rows cols raw poff  ; Δ{}
    ret call resolveSeq km _t2  ; Δ{_t2} · moves{_t2} · makes String
    ret call settleStart cwd sel marked prog hidden rows cols raw poff  ; Δ{}
    ret call settledFull cwd sel marked prog hidden rows cols raw poff  ; Δ{}
    ret call sixelRenderSrc _t7 _t8 _t9  ; Δ{} · makes String
    ret call step cwd sel marked prog hidden rows cols raw k  ; Δ{}
    ret call step cwd sel marked prog hidden rows cols raw key  ; Δ{}
    ret call stepAt cwd sel marked prog hidden rows cols raw poff key  ; Δ{}
    ret call stepAt cwd sel marked prog hidden rows cols raw poff key  ; Δ{}
    ret call tildeExpand nm  ; Δ{} · makes String
    ret call topMatch raw q from  ; Δ{}
    ret call windowGo cwd raw _t1 hi _t5  ; Δ{_t5} · moves{_t5} · makes String
    ret call wordsFrom s _t2 n  ; Δ{} · makes List$String
    ret call wordsStep s i n  ; Δ{} · makes List$String
    ret call workShow prog n rows  ; Δ{} · makes String
    ret cols  ; Δ{}
    ret comp  ; Δ{}
    ret con Cons _t3 _t6  ; Δ{_t3 _t6} · moves{_t3 _t6} · makes List$String
    ret con Just acc  ; Δ{} · makes Maybe$Int
    ret con Nil  ; Δ{} · makes List$String
    ret con Nil  ; Δ{} · makes List$String
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
    ret i  ; Δ{}
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
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t4 then
    ret if _t4 then
    ret if _t4 then
    ret if _t4 then
    ret if _t4 then
    ret if _t4 then
    ret if _t4 then
    ret if _t4 then
    ret if _t4 then
    ret if _t5 then
    ret if _t5 then
    ret if _t6 then
    ret if _t7 then
    ret if _t8 then
    ret if _t8 then
    ret j  ; Δ{}
    ret k  ; Δ{k} · moves{k}
    ret kc  ; Δ{}
    ret n  ; Δ{}
    ret n  ; Δ{}
    ret n  ; Δ{}
    ret n  ; Δ{}
    ret p  ; Δ{}
    ret rtcall axion_strcat a b  ; Δ{} · makes String
    ret rtcall axion_strcat s ""  ; Δ{} · makes String
    ret rtcall axion_substr 0 _t2 s  ; Δ{} · makes String
    ret rtcall axion_substr 0 _t3 s  ; Δ{} · makes String
    ret rtcall axion_substr 0 i line  ; Δ{} · makes String
    ret rtcall axion_substr 0 i s  ; Δ{} · makes String
    ret rtcall axion_substr 0 k s  ; Δ{} · makes String
    ret rtcall axion_substr 0 w s  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 line  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 s  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 s  ; Δ{} · makes String
    ret rtcall axion_substr i _t4 s  ; Δ{} · makes String
    ret s  ; Δ{}
    ret v  ; Δ{v} · moves{v}
    ret v  ; Δ{v} · moves{v}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t11}
  ; Δ{_t11}
  ; Δ{_t1}
  ; Δ{_t6}
  ; Δ{_t8}
  ; Δ{_t8}
  ; Δ{a}
  ; Δ{a}
  ; Δ{a}
  ; Δ{a}
  ; Δ{cc}
  ; Δ{cc}
  ; Δ{c}
  ; Δ{c}
  ; Δ{c}
  ; Δ{c}
  ; Δ{c}
  ; Δ{c}
  ; Δ{c}
  ; Δ{c}
  ; Δ{c}
  ; Δ{c}
  ; Δ{c}
  ; Δ{e v}
  ; Δ{e}
  ; Δ{fav}
  ; Δ{fav}
  ; Δ{fav}
  ; Δ{fav}
  ; Δ{km}
  ; Δ{k}
  ; Δ{k}
  ; Δ{k}
  ; Δ{k}
  ; Δ{k}
  ; Δ{k}
  ; Δ{l}
  ; Δ{nm}
  ; Δ{nm}
  ; Δ{nm}
  ; Δ{nm}
  ; Δ{tb}
  ; Δ{tys}
  ; Δ{tys}
  ; Δ{v}
  ; Δ{v}
  ; Δ{y ys}
  ; Δ{y ys}
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
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
  drop _t10 : String
  drop _t10 : String
  drop _t10 : String
  drop _t10 : String
  drop _t10 : String
  drop _t10 : String
  drop _t10 : String
  drop _t11 : String
  drop _t11 : String
  drop _t11 : String
  drop _t11 : String
  drop _t11 : String
  drop _t11 : String
  drop _t11 : String
  drop _t11 : String
  drop _t11 : String
  drop _t12 : String
  drop _t12 : String
  drop _t12 : String
  drop _t12 : String
  drop _t12 : String
  drop _t12 : String
  drop _t12 : String
  drop _t13 : String
  drop _t13 : String
  drop _t13 : String
  drop _t13 : String
  drop _t13 : String
  drop _t13 : String
  drop _t14 : String
  drop _t14 : String
  drop _t14 : String
  drop _t14 : String
  drop _t15 : String
  drop _t15 : String
  drop _t16 : String
  drop _t17 : String
  drop _t18 : String
  drop _t19 : String
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
  drop _t3 : String
  drop _t3 : String
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
  drop _t5 : List$String
  drop _t5 : List$String
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
  drop _t8 : String
  drop _t8 : String
  drop _t8 : String
  drop _t8 : String
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
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop _t9 : String
  drop c : String
  drop pat : String
  drop q : String
  drop rng : String
  drop sed : String
  drop tys : List$String
  drop tys : List$String
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
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
  let _d1000000 = call </> cwd _t1  ; Δ{_t1} · makes String
  let _d1000000 = call absPath _t0  ; Δ{_t0} · makes String
  let _d1000000 = call bnGo _t1  ; Δ{_t1} · makes String
  let _d1000000 = call colsOf _t0  ; Δ{_t0}
  let _d1000000 = call confirmYes _t0  ; Δ{_t0}
  let _d1000000 = call elemBy$String p _t0  ; Δ{_t0}
  let _d1000000 = call gotoDir cwd _t0 sel marked prog hidden rows  ; Δ{_t0}
  let _d1000000 = call gotoTo cwd sel marked prog hidden rows _t2  ; Δ{_t2}
  let _d1000000 = call gotoTo cwd sel marked prog hidden rows _t3  ; Δ{_t3}
  let _d1000000 = call gotoTo cwd sel marked prog hidden rows _t3  ; Δ{_t3}
  let _d1000000 = call ippGo _t0 acc  ; Δ{_t0}
  let _d1000000 = call joinPaths cwd _t0  ; Δ{_t0} · makes String
  let _d1000000 = call joinPaths cwd _t0  ; Δ{_t0} · makes String
  let _d1000000 = call laGo _t0 k  ; Δ{_t0} · makes String
  let _d1000000 = call length _t0  ; Δ{_t0}
  let _d1000000 = call length _t1  ; Δ{_t1}
  let _d1000000 = call lines _t1  ; Δ{_t1} · makes List$String
  let _d1000000 = call lscScan lsc pat 0 _t0 _t1  ; Δ{pat} · makes String
  let _d1000000 = call lscVal lsc _t1  ; Δ{_t1} · makes String
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
  let _d1000000 = call trim _t1  ; Δ{_t1} · makes String
  let _d1000000 = call trim _t1  ; Δ{_t1} · makes String
  let _d1000000 = call trim _t3  ; Δ{_t3} · makes String
  let _d1000000 = call trim _t3  ; Δ{_t3} · makes String
  let _d1000000 = call trim _t3  ; Δ{_t3} · makes String
  let _d1000000 = call trim _t3  ; Δ{_t3} · makes String
  let _d1000000 = call trim _t3  ; Δ{_t3} · makes String
  let _d1000000 = call trim _t5  ; Δ{_t5} · makes String
  let _d1000000 = call unlines _t1  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_read_file _t0  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_run _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat "  " _t3  ; Δ{_t3} · makes String
  let _d1000000 = rtcall axion_strcat "  axfm — key bindings\n\n" _t13  ; Δ{_t13} · makes String
  let _d1000000 = rtcall axion_strcat " [" _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat " | tail -n +" _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat "'" _t2  ; Δ{_t2} · makes String
  let _d1000000 = rtcall axion_strcat "(" _t5  ; Δ{_t5} · makes String
  let _d1000000 = rtcall axion_strcat "/tmp/axfm-bulk-" _t0  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat "L=" _t8  ; Δ{_t8} · makes String
  let _d1000000 = rtcall axion_strcat "P=" _t10  ; Δ{_t10} · makes String
  let _d1000000 = rtcall axion_strcat "P=" _t12  ; Δ{_t12} · makes String
  let _d1000000 = rtcall axion_strcat "[ -s \"$HOME/.cache/axfm/cell\" ] && exit 0; " _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat "bat --color=always --style=plain --paging=never --line-range " _t20  ; Δ{_t20} · makes String
  let _d1000000 = rtcall axion_strcat "cd " _t7  ; Δ{_t7} · makes String
  let _d1000000 = rtcall axion_strcat "cd " _t8  ; Δ{_t8} · makes String
  let _d1000000 = rtcall axion_strcat "cfg=" _t6  ; Δ{_t6} · makes String
  let _d1000000 = rtcall axion_strcat "cfg=" _t6  ; Δ{_t6} · makes String
  let _d1000000 = rtcall axion_strcat "cfg=" _t8  ; Δ{_t8} · makes String
  let _d1000000 = rtcall axion_strcat "cw=7; ch=14; [ -r \"$HOME/.cache/axfm/cell\" ] && read cw ch < \"$HOME/.cache/axfm/cell\"; W=$(( " _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat "d=" _t11  ; Δ{_t11} · makes String
  let _d1000000 = rtcall axion_strcat "f=" _t9  ; Δ{_t9} · makes String
  let _d1000000 = rtcall axion_strcat "f=" _t9  ; Δ{_t9} · makes String
  let _d1000000 = rtcall axion_strcat "for src in " _t2  ; Δ{_t2} · makes String
  let _d1000000 = rtcall axion_strcat "kitten icat --clear --stdin=no --scale-up --place=" _t10  ; Δ{_t10} · makes String
  let _d1000000 = rtcall axion_strcat "km=" _t14  ; Δ{_t14} · makes String
  let _d1000000 = rtcall axion_strcat "l=\"$HOME/.cache/axfm/trashlog\"; [ -s \"$l\" ] || exit 0; last=$(tail -n1 \"$l\"); t=$(printf '\\t'); dest=${last%%$t*}; orig=${last#*$t}; rc=0; if [ -e \"$dest\" ]; then mkdir -p \"${orig%/*}\" && mv -- \"$dest\" \"$orig\" || rc=1; fi; sed -i '$ d' \"$l\"; exit $rc" _t0  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat "m=$(file -bL --mime-type \"$src\" 2>/dev/null); case \"$m\" in video/*) " _t13  ; Δ{_t13} · makes String
  let _d1000000 = rtcall axion_strcat "m=$(file -bL --mime-type \"$src\" 2>/dev/null); case \"$m\" in video/*) " _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat "o=''; [ -r \"$HOME/.cache/axfm/sort\" ] && read o < \"$HOME/.cache/axfm/sort\" 2>/dev/null; fq=''; [ -r \"$HOME/.cache/axfm/filter\" ] && read fq < \"$HOME/.cache/axfm/filter\" 2>/dev/null; " _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat "printf '\\033[1;" _t4  ; Δ{_t4} · makes String
  let _d1000000 = rtcall axion_strcat "src=" _t3  ; Δ{_t3} · makes String
  let _d1000000 = rtcall axion_strcat "src=" _t6  ; Δ{_t6} · makes String
  let _d1000000 = rtcall axion_strcat "src=" _t6  ; Δ{_t6} · makes String
  let _d1000000 = rtcall axion_strcat "t=0; test -t 1 && t=1; r=''; k=0; case \"$TERM\" in *kitty*) k=1 ;; esac; [ -n \"$KITTY_WINDOW_ID\" ] && k=1; " _t3  ; Δ{_t3} · makes String
  let _d1000000 = rtcall axion_strcat "tb=''; tf=" _t7  ; Δ{_t7} · makes String
  let _d1000000 = rtcall axion_strcat "trash " _t1  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_strcat "{ bsdtar -tf " _t7  ; Δ{_t7} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/axfm.d"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/bookmarks"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/caps"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/colors"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/err"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/filter"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/icons"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/keymap"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/lastq"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/pending"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/sort"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/tabi"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/tabs"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.cache/axfm/types"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.config/axfm/config.lua"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 "/.local/share/axfm/trash"  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t1 _t11  ; Δ{_t1 _t11} · makes String
  let _d1000000 = rtcall axion_strcat _t1 _t14  ; Δ{_t1 _t14} · makes String
  let _d1000000 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t2 _t10  ; Δ{_t10 _t2} · makes String
  let _d1000000 = rtcall axion_strcat _t2 _t7  ; Δ{_t2 _t7} · makes String
  let _d1000000 = rtcall axion_strcat _t2 _t7  ; Δ{_t2 _t7} · makes String
  let _d1000000 = rtcall axion_strcat _t3 _t15  ; Δ{_t15 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t3 _t9  ; Δ{_t3 _t9} · makes String
  let _d1000000 = rtcall axion_strcat _t6 "\n"  ; Δ{_t6} · makes String
  let _d1000000 = rtcall axion_strcat c _t2  ; Δ{_t2 c} · makes String
  let _d1000000 = rtcall axion_strcat cwd _t3  ; Δ{_t3} · makes String
  let _d1000000 = rtcall axion_system _t0  ; Δ{_t0}
  let _d1000000 = rtcall axion_system _t0  ; Δ{_t0}
  let _d1000000 = rtcall axion_system _t2  ; Δ{_t2}
  let _d1000000 = rtcall axion_system _t8  ; Δ{_t8}
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = + i 1  ; Δ{}
  let _t0 = + i plen  ; Δ{}
  let _t0 = + poff 1  ; Δ{}
  let _t0 = + poff 1  ; Δ{}
  let _t0 = + sel 1  ; Δ{}
  let _t0 = - 0 1  ; Δ{}
  let _t0 = - 0 1  ; Δ{}
  let _t0 = - 0 1  ; Δ{}
  let _t0 = - j i  ; Δ{}
  let _t0 = - j i  ; Δ{}
  let _t0 = - rows 1  ; Δ{}
  let _t0 = - rows 1  ; Δ{}
  let _t0 = - rows 3  ; Δ{}
  let _t0 = - sel 2  ; Δ{}
  let _t0 = < i 0  ; Δ{}
  let _t0 = < i 0  ; Δ{}
  let _t0 = < i 0  ; Δ{}
  let _t0 = < i 0  ; Δ{}
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
  let _t0 = == hidden 1  ; Δ{nm}
  let _t0 = == hidden 1  ; Δ{}
  let _t0 = == i sel  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = > h 2  ; Δ{}
  let _t0 = > i hi  ; Δ{}
  let _t0 = > i lim  ; Δ{}
  let _t0 = > j 0  ; Δ{}
  let _t0 = > n 0  ; Δ{}
  let _t0 = > r mx  ; Δ{}
  let _t0 = call <=$Int idx 0  ; Δ{}
  let _t0 = call <=$Int left 0  ; Δ{}
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
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int j n  ; Δ{}
  let _t0 = call baseName path  ; Δ{} · makes String
  let _t0 = call baseNames marked  ; Δ{} · makes String
  let _t0 = call buildConfigGuard  ; Δ{} · makes String
  let _t0 = call capLine 0  ; Δ{} · makes String
  let _t0 = call capsFile 0  ; Δ{} · makes String
  let _t0 = call capsFile 0  ; Δ{} · makes String
  let _t0 = call catOf ext  ; Δ{} · makes String
  let _t0 = call catOf ext  ; Δ{} · makes String
  let _t0 = call cdFile 0  ; Δ{} · makes String
  let _t0 = call classifyNow cwd hidden  ; Δ{}
  let _t0 = call classifyNow cwd hidden  ; Δ{}
  let _t0 = call cmdLine "filter> " rows cwd  ; Δ{} · makes String
  let _t0 = call cmdLine "go to dir: " rows cwd  ; Δ{} · makes String
  let _t0 = call cmdLine "mkdir: " rows cwd  ; Δ{} · makes String
  let _t0 = call cmdLine "mkfile: " rows cwd  ; Δ{} · makes String
  let _t0 = call colorsFile 0  ; Δ{} · makes String
  let _t0 = call configFile 0  ; Δ{} · makes String
  let _t0 = call configFile 0  ; Δ{} · makes String
  let _t0 = call configFile 0  ; Δ{} · makes String
  let _t0 = call confirmKey "jump to mark: " rows  ; Δ{} · makes String
  let _t0 = call confirmKey "set mark (letter): " rows  ; Δ{} · makes String
  let _t0 = call confirmKey prompt rows  ; Δ{} · makes String
  let _t0 = call countPrompt rows acc  ; Δ{} · makes String
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
  let _t0 = call envOr "HOME" "."  ; Δ{} · makes String
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
  let _t0 = call hasPrefix "!!" item  ; Δ{}
  let _t0 = call hasPrefix "image/" mime  ; Δ{}
  let _t0 = call hasPrefix "inode/directory" mime  ; Δ{}
  let _t0 = call hasSuffix "/" s  ; Δ{}
  let _t0 = call hasSuffix "/" y  ; Δ{}
  let _t0 = call iconsFile 0  ; Δ{} · makes String
  let _t0 = call imageExts  ; Δ{} · makes List$String
  let _t0 = call imageExts  ; Δ{} · makes List$String
  let _t0 = call imageExts  ; Δ{} · makes List$String
  let _t0 = call imgClearSeq  ; Δ{} · makes String
  let _t0 = call infoSize info  ; Δ{} · makes String
  let _t0 = call infoSize info  ; Δ{} · makes String
  let _t0 = call isDigitK k  ; Δ{}
  let _t0 = call isDirPath dest  ; Δ{}
  let _t0 = call isProperPrefix km acc  ; Δ{}
  let _t0 = call keymapFile 0  ; Δ{} · makes String
  let _t0 = call keymapFile 0  ; Δ{} · makes String
  let _t0 = call lastqFile 0  ; Δ{} · makes String
  let _t0 = call lastqFile 0  ; Δ{} · makes String
  let _t0 = call lineAt raw sel  ; Δ{} · makes String
  let _t0 = call lineOffset s start  ; Δ{}
  let _t0 = call lines content  ; Δ{} · makes List$String
  let _t0 = call lines info  ; Δ{} · makes List$String
  let _t0 = call lines info  ; Δ{} · makes List$String
  let _t0 = call lines info  ; Δ{} · makes List$String
  let _t0 = call lines info  ; Δ{} · makes List$String
  let _t0 = call lines info  ; Δ{} · makes List$String
  let _t0 = call lines km  ; Δ{} · makes List$String
  let _t0 = call lines m  ; Δ{} · makes List$String
  let _t0 = call lines m  ; Δ{} · makes List$String
  let _t0 = call lines m  ; Δ{} · makes List$String
  let _t0 = call lines m  ; Δ{} · makes List$String
  let _t0 = call lines raw  ; Δ{} · makes List$String
  let _t0 = call lines raw  ; Δ{} · makes List$String
  let _t0 = call lines raw  ; Δ{} · makes List$String
  let _t0 = call lines raw  ; Δ{} · makes List$String
  let _t0 = call lines raw  ; Δ{} · makes List$String
  let _t0 = call lines rdt  ; Δ{} · makes List$String
  let _t0 = call listFrame cwd sel marked prog rows raw cols poff  ; Δ{} · makes String
  let _t0 = call listWidth cols  ; Δ{}
  let _t0 = call lsCmd cwd hidden  ; Δ{} · makes String
  let _t0 = call lscEnd s j n  ; Δ{}
  let _t0 = call markCount marked  ; Δ{}
  let _t0 = call markCount marked  ; Δ{}
  let _t0 = call markCount marked  ; Δ{}
  let _t0 = call markCount marked  ; Δ{}
  let _t0 = call markCount marked  ; Δ{}
  let _t0 = call markedHas m p  ; Δ{}
  let _t0 = call markedHas marked full  ; Δ{}
  let _t0 = call onTty 0  ; Δ{}
  let _t0 = call onTty 0  ; Δ{}
  let _t0 = call onTty 0  ; Δ{}
  let _t0 = call onTty 0  ; Δ{}
  let _t0 = call paneW cols  ; Δ{}
  let _t0 = call paneX cols  ; Δ{}
  let _t0 = call pendingFile 0  ; Δ{} · makes String
  let _t0 = call pendingFile 0  ; Δ{} · makes String
  let _t0 = call pendingFile 0  ; Δ{} · makes String
  let _t0 = call pickRenderer 0  ; Δ{} · makes String
  let _t0 = call pickRenderer 0  ; Δ{} · makes String
  let _t0 = call pickRenderer 0  ; Δ{} · makes String
  let _t0 = call previewOn cols  ; Δ{tys}
  let _t0 = call previewOn cols  ; Δ{tys}
  let _t0 = call rdtEntries rdt hidden fq  ; Δ{} · makes List$String
  let _t0 = call rdtEntries rdt hidden fq  ; Δ{} · makes List$String
  let _t0 = call rdtIsDir ln  ; Δ{}
  let _t0 = call readMainKeyTO 500  ; Δ{} · makes String
  let _t0 = call resetSeq  ; Δ{} · makes String
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
  let _t0 = call selPathOf cwd raw sel  ; Δ{} · makes String
  let _t0 = call selPathOf cwd raw sel  ; Δ{} · makes String
  let _t0 = call selPathOf cwd raw sel  ; Δ{} · makes String
  let _t0 = call shQuote cwd  ; Δ{} · makes String
  let _t0 = call shQuote cwd  ; Δ{} · makes String
  let _t0 = call shQuote cwd  ; Δ{} · makes String
  let _t0 = call shQuote cwd  ; Δ{} · makes String
  let _t0 = call shQuote cwd  ; Δ{} · makes String
  let _t0 = call shQuote cwd  ; Δ{} · makes String
  let _t0 = call shQuote d  ; Δ{} · makes String
  let _t0 = call shQuote letter  ; Δ{} · makes String
  let _t0 = call shQuote p  ; Δ{} · makes String
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
  let _t0 = call shQuote path  ; Δ{} · makes String
  let _t0 = call shQuote path  ; Δ{} · makes String
  let _t0 = call sortFile 0  ; Δ{} · makes String
  let _t0 = call splitMin  ; Δ{}
  let _t0 = call startDirRaw a  ; Δ{} · makes String
  let _t0 = call stripSlash raw  ; Δ{} · makes String
  let _t0 = call syncTab cwd  ; Δ{}
  let _t0 = call syncTab cwd  ; Δ{}
  let _t0 = call syncTabCmd cwd  ; Δ{} · makes String
  let _t0 = call tabCloseCmd 0  ; Δ{} · makes String
  let _t0 = call tabGoCmd delta  ; Δ{} · makes String
  let _t0 = call tabNewCmd cwd  ; Δ{} · makes String
  let _t0 = call tabsFile 0  ; Δ{} · makes String
  let _t0 = call tabsFile 0  ; Δ{} · makes String
  let _t0 = call tabsFile 0  ; Δ{} · makes String
  let _t0 = call termCols 0  ; Δ{}
  let _t0 = call trimStart s 0  ; Δ{}
  let _t0 = call typesFile 0  ; Δ{} · makes String
  let _t0 = call userCmd cwd raw sel cmd  ; Δ{} · makes String
  let _t0 = call videoThumbVar  ; Δ{} · makes String
  let _t0 = call videoThumbVar  ; Δ{} · makes String
  let _t0 = call words s  ; Δ{} · makes List$String
  let _t0 = call words sz  ; Δ{} · makes List$String
  let _t0 = call writeCapsCmd  ; Δ{} · makes String
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = rtcall axion_rand_hex 8  ; Δ{} · makes String
  let _t0 = rtcall axion_readdir_typed cwd  ; Δ{} · makes String
  let _t0 = rtcall axion_readdir_typed cwd  ; Δ{} · makes String
  let _t0 = rtcall axion_run "stty size"  ; Δ{} · makes String
  let _t0 = rtcall axion_run "stty size"  ; Δ{} · makes String
  let _t0 = rtcall axion_str_at 0 ln  ; Δ{}
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_cmp a "down"  ; Δ{}
  let _t0 = rtcall axion_str_cmp a b  ; Δ{}
  let _t0 = rtcall axion_str_cmp b "A"  ; Δ{}
  let _t0 = rtcall axion_str_cmp dest src  ; Δ{}
  let _t0 = rtcall axion_str_cmp k ""  ; Δ{}
  let _t0 = rtcall axion_str_cmp k ""  ; Δ{}
  let _t0 = rtcall axion_str_cmp k ""  ; Δ{}
  let _t0 = rtcall axion_str_cmp k "y"  ; Δ{}
  let _t0 = rtcall axion_str_cmp key ""  ; Δ{}
  let _t0 = rtcall axion_str_cmp key ""  ; Δ{}
  let _t0 = rtcall axion_str_cmp key "j"  ; Δ{}
  let _t0 = rtcall axion_str_cmp nm "~"  ; Δ{}
  let _t0 = rtcall axion_str_cmp prog "trash"  ; Δ{}
  let _t0 = rtcall axion_str_cmp prog "trash"  ; Δ{}
  let _t0 = rtcall axion_str_cmp prog "trash"  ; Δ{}
  let _t0 = rtcall axion_str_cmp s "-S"  ; Δ{}
  let _t0 = rtcall axion_str_cmp ty "d"  ; Δ{}
  let _t0 = rtcall axion_str_cmp ty "d"  ; Δ{}
  let _t0 = rtcall axion_str_cmp x y  ; Δ{}
  let _t0 = rtcall axion_str_len a  ; Δ{a}
  let _t0 = rtcall axion_str_len a  ; Δ{}
  let _t0 = rtcall axion_str_len acc  ; Δ{}
  let _t0 = rtcall axion_str_len b  ; Δ{}
  let _t0 = rtcall axion_str_len c  ; Δ{c}
  let _t0 = rtcall axion_str_len c  ; Δ{c}
  let _t0 = rtcall axion_str_len c  ; Δ{c}
  let _t0 = rtcall axion_str_len c  ; Δ{c}
  let _t0 = rtcall axion_str_len c  ; Δ{c}
  let _t0 = rtcall axion_str_len c  ; Δ{c}
  let _t0 = rtcall axion_str_len c  ; Δ{c}
  let _t0 = rtcall axion_str_len c  ; Δ{c}
  let _t0 = rtcall axion_str_len c  ; Δ{c}
  let _t0 = rtcall axion_str_len cc  ; Δ{cc}
  let _t0 = rtcall axion_str_len cmd  ; Δ{}
  let _t0 = rtcall axion_str_len comp  ; Δ{}
  let _t0 = rtcall axion_str_len d  ; Δ{}
  let _t0 = rtcall axion_str_len icfg  ; Δ{}
  let _t0 = rtcall axion_str_len k  ; Δ{k}
  let _t0 = rtcall axion_str_len k  ; Δ{k}
  let _t0 = rtcall axion_str_len k  ; Δ{}
  let _t0 = rtcall axion_str_len k  ; Δ{}
  let _t0 = rtcall axion_str_len k  ; Δ{}
  let _t0 = rtcall axion_str_len k  ; Δ{}
  let _t0 = rtcall axion_str_len kc  ; Δ{}
  let _t0 = rtcall axion_str_len key  ; Δ{}
  let _t0 = rtcall axion_str_len key  ; Δ{}
  let _t0 = rtcall axion_str_len l  ; Δ{l}
  let _t0 = rtcall axion_str_len letter  ; Δ{}
  let _t0 = rtcall axion_str_len letter  ; Δ{}
  let _t0 = rtcall axion_str_len ln  ; Δ{}
  let _t0 = rtcall axion_str_len lsc  ; Δ{pat}
  let _t0 = rtcall axion_str_len nm  ; Δ{}
  let _t0 = rtcall axion_str_len nm  ; Δ{}
  let _t0 = rtcall axion_str_len old  ; Δ{}
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
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len sortf  ; Δ{}
  let _t0 = rtcall axion_str_len sortf  ; Δ{}
  let _t0 = rtcall axion_str_len tb  ; Δ{tb}
  let _t0 = rtcall axion_str_len v  ; Δ{v}
  let _t0 = rtcall axion_str_len v  ; Δ{v}
  let _t0 = rtcall axion_strcat "  keys are remappable in ~/.config/axfm/config.lua\n\n" "  press any key to close"  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat "*." ext  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat "*." ext  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat "FFF_FAV" key  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat "[ -n \"${1:-}\" ] && [ -n \"${2:-}\" ] || exit 0; sz=$(stty size <&3 2>/dev/null); rr=${sz%% *}; cc=${sz##* }; " "[ \"${rr:-0}\" -gt 0 ] && [ \"${cc:-0}\" -gt 0 ] || exit 0; cw=$(( $2 / cc )); ch=$(( $1 / rr )); [ \"$cw\" -gt 0 ] && [ \"$ch\" -gt 0 ] || exit 0; printf '%s %s' \"$cw\" \"$ch\" > \"$HOME/.cache/axfm/cell\""  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat body "; done >/dev/null 2>&1 &"  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat c "m"  ; Δ{} · makes String
  let _t0 = showInt n  ; Δ{} · makes String
  let _t0 = showInt pw  ; Δ{} · makes String
  let _t0 = showInt pwc  ; Δ{} · makes String
  let _t0 = showInt px  ; Δ{} · makes String
  let _t0 = showInt rows  ; Δ{} · makes String
  let _t0 = showInt rows  ; Δ{} · makes String
  let _t0 = showInt rows  ; Δ{} · makes String
  let _t0 = showInt rows  ; Δ{} · makes String
  let _t0 = showInt rows  ; Δ{} · makes String
  let _t0 = showInt rows  ; Δ{} · makes String
  let _t0 = showInt rows  ; Δ{} · makes String
  let _t1 = - _t0 1  ; Δ{}
  let _t1 = - _t0 j  ; Δ{}
  let _t1 = - cols _t0  ; Δ{}
  let _t1 = - w _t0  ; Δ{c}
  let _t1 = < _t0 1  ; Δ{}
  let _t1 = < i _t0  ; Δ{}
  let _t1 = < k 0  ; Δ{}
  let _t1 = < p 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{a}
  let _t1 = == _t0 0  ; Δ{k}
  let _t1 = == _t0 0  ; Δ{l}
  let _t1 = == _t0 0  ; Δ{tb}
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
  let _t1 = > _t0 0  ; Δ{cc}
  let _t1 = > _t0 0  ; Δ{c}
  let _t1 = > _t0 0  ; Δ{c}
  let _t1 = > _t0 0  ; Δ{c}
  let _t1 = > _t0 0  ; Δ{c}
  let _t1 = > _t0 0  ; Δ{c}
  let _t1 = > _t0 0  ; Δ{c}
  let _t1 = > _t0 0  ; Δ{c}
  let _t1 = > _t0 0  ; Δ{c}
  let _t1 = > _t0 0  ; Δ{k}
  let _t1 = > _t0 0  ; Δ{v}
  let _t1 = > _t0 0  ; Δ{v}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = > _t0 4096  ; Δ{}
  let _t1 = > _t0 n  ; Δ{}
  let _t1 = > _t0 w  ; Δ{}
  let _t1 = call </> cwd _t0  ; Δ{_t0} · makes String
  let _t1 = call >=$Int _t0 need  ; Δ{}
  let _t1 = call >=$Int cols _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call buildColorsCmd  ; Δ{_t0} · makes String
  let _t1 = call clampSel _t0 n  ; Δ{}
  let _t1 = call copyToClip _t0  ; Δ{_t0}
  let _t1 = call countLines raw  ; Δ{_t0}
  let _t1 = call csi "2J"  ; Δ{_t0} · makes String
  let _t1 = call csi "?25l"  ; Δ{_t0} · makes String
  let _t1 = call csi "H"  ; Δ{_t0} · makes String
  let _t1 = call csi _t0  ; Δ{_t0} · makes String
  let _t1 = call duOf _t0  ; Δ{_t0} · makes String
  let _t1 = call elemBy$String e _t0  ; Δ{_t0}
  let _t1 = call elemBy$String e _t0  ; Δ{_t0}
  let _t1 = call elemBy$String e _t0  ; Δ{_t0}
  let _t1 = call esc  ; Δ{_t0} · makes String
  let _t1 = call filter$$nonEmpty _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = call filter$$nonEmpty _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = call filter$$nonEmpty _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = call filterFile 0  ; Δ{_t0} · makes String
  let _t1 = call firstLine c  ; Δ{c} · makes String
  let _t1 = call firstWord _t0  ; Δ{_t0} · makes String
  let _t1 = call hasSuffix "/" a  ; Δ{}
  let _t1 = call homeClear  ; Δ{_t0} · makes String
  let _t1 = call imgClearSeq  ; Δ{tys} · makes String
  let _t1 = call imgClearSeq  ; Δ{tys} · makes String
  let _t1 = call indexOfName _t0 child 0 0  ; Δ{_t0}
  let _t1 = call infoMtime info  ; Δ{_t0} · makes String
  let _t1 = call isDirPath _t0  ; Δ{_t0}
  let _t1 = call isExecPath _t0  ; Δ{_t0}
  let _t1 = call isSpace _t0  ; Δ{}
  let _t1 = call isTextPath _t0  ; Δ{_t0}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = call map$$rdtCode _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = call map$$rdtRawName _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = call markPath _t0  ; Δ{_t0} · makes String
  let _t1 = call markSet _t0 cwd  ; Δ{_t0}
  let _t1 = call matchFrom _t0 q 0 0  ; Δ{_t0}
  let _t1 = call pdfThumbVar  ; Δ{_t0} · makes String
  let _t1 = call pdfThumbVar  ; Δ{_t0} · makes String
  let _t1 = call pendingFile 0  ; Δ{q} · makes String
  let _t1 = call pick 0 _t0  ; Δ{_t0} · makes String
  let _t1 = call pick 1 _t0  ; Δ{_t0} · makes String
  let _t1 = call pick 1 _t0  ; Δ{_t0} · makes String
  let _t1 = call pick 2 _t0  ; Δ{_t0} · makes String
  let _t1 = call pick 3 _t0  ; Δ{_t0} · makes String
  let _t1 = call pick 4 _t0  ; Δ{_t0} · makes String
  let _t1 = call pick sel _t0  ; Δ{_t0} · makes String
  let _t1 = call quoteLines marked  ; Δ{_t0} · makes String
  let _t1 = call rdtKeep hidden fq _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = call readFileTrim _t0  ; Δ{_t0} · makes String
  let _t1 = call renderSrc cols rows  ; Δ{_t0} · makes String
  let _t1 = call selInfo _t0  ; Δ{_t0} · makes String
  let _t1 = call selInfo _t0  ; Δ{_t0} · makes String
  let _t1 = call selPathOf cwd raw msel  ; Δ{} · makes String
  let _t1 = call selPathOf cwd raw sel  ; Δ{_t0} · makes String
  let _t1 = call selPathOf cwd raw sel  ; Δ{_t0} · makes String
  let _t1 = call shEsc s 0 _t0  ; Δ{} · makes String
  let _t1 = call shQuote _t0  ; Δ{_t0} · makes String
  let _t1 = call shQuote _t0  ; Δ{_t0} · makes String
  let _t1 = call shQuote _t0  ; Δ{_t0} · makes String
  let _t1 = call shQuote _t0  ; Δ{_t0} · makes String
  let _t1 = call shQuote _t0  ; Δ{_t0} · makes String
  let _t1 = call shQuote _t0  ; Δ{_t0} · makes String
  let _t1 = call shQuote _t0  ; Δ{_t0} · makes String
  let _t1 = call shQuote _t0  ; Δ{_t0} · makes String
  let _t1 = call shQuote _t0  ; Δ{_t0} · makes String
  let _t1 = call shQuote cwd  ; Δ{_t0} · makes String
  let _t1 = call shQuote d  ; Δ{_t0} · makes String
  let _t1 = call shQuote path  ; Δ{_t0} · makes String
  let _t1 = call sixelDecode pwc phc  ; Δ{_t0} · makes String
  let _t1 = call sixelDecode pwc phc  ; Δ{_t0} · makes String
  let _t1 = call sortFile 0  ; Δ{_t0} · makes String
  let _t1 = call stripSlash _t0  ; Δ{_t0} · makes String
  let _t1 = call tabBarCmd  ; Δ{_t0} · makes String
  let _t1 = call tabToNl items  ; Δ{_t0} · makes String
  let _t1 = call tabsFile 0  ; Δ{_t0} · makes String
  let _t1 = call tabsFile 0  ; Δ{_t0} · makes String
  let _t1 = call typesFile 0  ; Δ{_t0} · makes String
  let _t1 = call typesFile 0  ; Δ{_t0} · makes String
  let _t1 = call typesFile 0  ; Δ{_t0} · makes String
  let _t1 = call videoThumbVar  ; Δ{_t0} · makes String
  let _t1 = call workMsg prog _t0 rows  ; Δ{} · makes String
  let _t1 = con Cons "aac" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = con Cons "axi" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = con Cons "heic" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = con Cons "md" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = con Cons "mpeg" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = con Cons "tgz" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = if _t0 then
  let _t1 = if _t0 then
  let _t1 = if _t0 then
  let _t1 = putStr _t0  ; Δ{_t0}
  let _t1 = putStr _t0  ; Δ{_t0}
  let _t1 = putStr _t0  ; Δ{_t0}
  let _t1 = putStr _t0  ; Δ{_t0}
  let _t1 = putStr _t0  ; Δ{_t0}
  let _t1 = putStr _t0  ; Δ{_t0}
  let _t1 = rtcall axion_read_file _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_read_file _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_read_file _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_run _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_run _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_run _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_str_cmp _t0 "1"  ; Δ{_t0}
  let _t1 = rtcall axion_str_cmp _t0 "kitten"  ; Δ{_t0}
  let _t1 = rtcall axion_str_cmp _t0 "kitten"  ; Δ{_t0}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len acc  ; Δ{}
  let _t1 = rtcall axion_str_len c  ; Δ{c}
  let _t1 = rtcall axion_str_len c  ; Δ{c}
  let _t1 = rtcall axion_str_len cmd  ; Δ{}
  let _t1 = rtcall axion_str_len e  ; Δ{e}
  let _t1 = rtcall axion_str_len key  ; Δ{fav}
  let _t1 = rtcall axion_str_len km  ; Δ{km}
  let _t1 = rtcall axion_str_len nm  ; Δ{_t0}
  let _t1 = rtcall axion_str_len pat  ; Δ{pat}
  let _t1 = rtcall axion_str_len q  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_strcat "  P  copy path        R  bulk-rename     !  shell    q  quit\n\n" _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "; do " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "[" s  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "hw=$(printf %s \"$r\"|sed -n 's/.*4;\\([0-9]*\\);\\([0-9]*\\)t.*/\\1 \\2/p'); set -- $hw; " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "test -d " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "test -e " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "test -x " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " 2>/dev/null | grep -q '^text/\\|^inode/x-empty'"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " 2>/dev/null"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " 2>/dev/null"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " item(s)? [y/N] "  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " to: "  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "/*"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "/*"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "/.cache/axfm"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "; printf %s \"$p\" | { wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || xsel -b 2>/dev/null; }"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "; printf '%s: ' \"$(basename -- \"$f\")\"; du -sh -- \"$f\" 2>/dev/null | cut -f1 | grep . || printf '%s' '—'"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 ";1H"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 ";1H"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 ";1H"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 ";1H"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 ";1H"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 ";1H"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 ";1H"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat acc "\n"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat cwd "\n"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t1 = rtcall axion_system _t0  ; Δ{_t0}
  let _t1 = rtcall axion_system _t0  ; Δ{_t0}
  let _t1 = rtcall axion_system _t0  ; Δ{_t0}
  let _t1 = rtcall axion_write_file tmp _t0  ; Δ{_t0}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt ph  ; Δ{_t0} · makes String
  let _t1 = showInt phc  ; Δ{_t0} · makes String
  let _t10 = call statusLine cwd total sel marked prog rows info  ; Δ{_t1 _t2 _t6 _t7 _t9} · makes String
  let _t10 = con Cons "xml" _t9  ; Δ{_t9} · moves{_t9} · makes List$String
  let _t10 = putStr _t9  ; Δ{_t9}
  let _t10 = putStr _t9  ; Δ{_t9}
  let _t10 = rtcall axion_strcat "  /  search (live)   ; / ,  next / prev match    o  cycle sort\n" _t9  ; Δ{_t9} · makes String
  let _t10 = rtcall axion_strcat " ;; application/pdf) " _t9  ; Δ{_t0 _t1 _t9} · makes String
  let _t10 = rtcall axion_strcat "," _t9  ; Δ{_t6 _t9 rng} · makes String
  let _t10 = rtcall axion_strcat "; t=" _t9  ; Δ{_t0 _t9} · makes String
  let _t10 = rtcall axion_strcat _t0 _t9  ; Δ{_t0 _t9} · makes String
  let _t10 = rtcall axion_strcat _t0 _t9  ; Δ{_t0 _t9} · makes String
  let _t10 = rtcall axion_strcat _t2 _t9  ; Δ{_t0 _t2 _t9} · makes String
  let _t10 = rtcall axion_strcat _t3 _t9  ; Δ{_t2 _t3 _t9} · makes String
  let _t10 = rtcall axion_strcat _t5 _t9  ; Δ{_t1 _t3 _t5 _t9} · makes String
  let _t10 = rtcall axion_strcat _t6 _t9  ; Δ{_t1 _t2 _t6 _t9} · makes String
  let _t10 = rtcall axion_strcat _t8 _t9  ; Δ{_t3 _t4 _t5 _t6 _t7 _t8 _t9} · makes String
  let _t11 = call shQuote path  ; Δ{rng sed} · makes String
  let _t11 = con Cons "scss" _t10  ; Δ{_t10} · moves{_t10} · makes List$String
  let _t11 = rtcall axion_strcat "  J / K             scroll preview      .       toggle hidden\n" _t10  ; Δ{_t10} · makes String
  let _t11 = rtcall axion_strcat "; f=" _t10  ; Δ{_t0 _t10} · makes String
  let _t11 = rtcall axion_strcat "; ic=" _t10  ; Δ{_t1 _t10 _t3} · makes String
  let _t11 = rtcall axion_strcat _t0 _t10  ; Δ{_t0 _t10} · makes String
  let _t11 = rtcall axion_strcat _t1 _t10  ; Δ{_t0 _t1 _t10} · makes String
  let _t11 = rtcall axion_strcat _t2 _t10  ; Δ{_t1 _t10 _t2} · makes String
  let _t11 = rtcall axion_strcat _t7 _t10  ; Δ{_t10 _t3 _t4 _t5 _t6 _t7} · makes String
  let _t11 = rtcall axion_strcat _t9 _t10  ; Δ{_t1 _t10 _t2 _t6 _t7 _t9} · makes String
  let _t12 = call shQuote sed  ; Δ{_t11 rng sed} · makes String
  let _t12 = con Cons "css" _t11  ; Δ{_t11} · moves{_t11} · makes List$String
  let _t12 = rtcall axion_strcat "  l  Enter  (or ->) open               h  (or <-)  parent dir\n" _t11  ; Δ{_t11} · makes String
  let _t12 = rtcall axion_strcat "src=\"$th\"; " _t11  ; Δ{_t0 _t11} · makes String
  let _t12 = rtcall axion_strcat _t0 _t11  ; Δ{_t0 _t11} · makes String
  let _t12 = rtcall axion_strcat _t3 _t11  ; Δ{_t1 _t11 _t3} · makes String
  let _t12 = rtcall axion_strcat _t6 _t11  ; Δ{_t11 _t3 _t4 _t5 _t6} · makes String
  let _t12 = rtcall axion_strcat _t7 _t11  ; Δ{_t1 _t11 _t2 _t6 _t7} · makes String
  let _t13 = call shQuote path  ; Δ{_t11 _t12 rng} · makes String
  let _t13 = con Cons "html" _t12  ; Δ{_t12} · moves{_t12} · makes List$String
  let _t13 = rtcall axion_strcat "  j k  (or arrows)  move cursor        g / G   top / bottom\n" _t12  ; Δ{_t12} · makes String
  let _t13 = rtcall axion_strcat "; cf=" _t12  ; Δ{_t1 _t12} · makes String
  let _t13 = rtcall axion_strcat _t0 _t12  ; Δ{_t0 _t12} · makes String
  let _t13 = rtcall axion_strcat _t5 _t12  ; Δ{_t12 _t3 _t4 _t5} · makes String
  let _t13 = rtcall axion_strcat _t6 _t12  ; Δ{_t1 _t12 _t2 _t6} · makes String
  let _t14 = con Cons "json" _t13  ; Δ{_t13} · moves{_t13} · makes List$String
  let _t14 = rtcall axion_strcat _t1 _t13  ; Δ{_t1 _t13} · makes String
  let _t14 = rtcall axion_strcat _t13 " 2>/dev/null"  ; Δ{_t11 _t12 _t13 rng} · makes String
  let _t14 = rtcall axion_strcat _t2 _t13  ; Δ{_t1 _t13 _t2} · makes String
  let _t14 = rtcall axion_strcat _t4 _t13  ; Δ{_t13 _t3 _t4} · makes String
  let _t15 = call paint "7" _t14  ; Δ{_t14 _t3} · makes String
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
  let _t2 = + sel 4  ; Δ{}
  let _t2 = - 0 1  ; Δ{_t0}
  let _t2 = - _t0 _t1  ; Δ{}
  let _t2 = - _t1 1  ; Δ{_t0}
  let _t2 = < _t0 _t1  ; Δ{}
  let _t2 = == _t1 0  ; Δ{e}
  let _t2 = == _t1 0  ; Δ{km}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = > _t1 0  ; Δ{_t0}
  let _t2 = > _t1 0  ; Δ{_t0}
  let _t2 = > _t1 0  ; Δ{c}
  let _t2 = > _t1 0  ; Δ{c}
  let _t2 = > _t1 0  ; Δ{fav}
  let _t2 = > _t1 0  ; Δ{}
  let _t2 = call absPath _t1  ; Δ{_t1} · makes String
  let _t2 = call bookmarkFile 0  ; Δ{_t0 _t1} · makes String
  let _t2 = call buildIconsCmd  ; Δ{_t0 _t1} · makes String
  let _t2 = call colorsFile 0  ; Δ{_t1} · makes String
  let _t2 = call colorsFile 0  ; Δ{_t1} · makes String
  let _t2 = call csi "2J"  ; Δ{_t0 _t1} · makes String
  let _t2 = call csi "?1049l"  ; Δ{_t0 _t1} · makes String
  let _t2 = call csi "m"  ; Δ{_t1} · makes String
  let _t2 = call csi _t1  ; Δ{_t1} · makes String
  let _t2 = call csi _t1  ; Δ{_t1} · makes String
  let _t2 = call csi _t1  ; Δ{_t1} · makes String
  let _t2 = call csi _t1  ; Δ{_t1} · makes String
  let _t2 = call csi _t1  ; Δ{_t1} · makes String
  let _t2 = call csi _t1  ; Δ{_t1} · makes String
  let _t2 = call csi _t1  ; Δ{_t1} · makes String
  let _t2 = call dropFirstLine q  ; Δ{_t1 q} · makes String
  let _t2 = call filterFile 0  ; Δ{_t0 _t1} · makes String
  let _t2 = call filterFile 0  ; Δ{_t0 _t1} · makes String
  let _t2 = call flashInfo _t1 rows  ; Δ{_t1}
  let _t2 = call helpText  ; Δ{_t0 _t1} · makes String
  let _t2 = call homeClear  ; Δ{_t1 tys} · makes String
  let _t2 = call homeClear  ; Δ{_t1 tys} · makes String
  let _t2 = call iconsFile 0  ; Δ{_t1} · makes String
  let _t2 = call keymapFile 0  ; Δ{_t1} · makes String
  let _t2 = call lines _t1  ; Δ{_t1} · makes List$String
  let _t2 = call lines _t1  ; Δ{_t1} · makes List$String
  let _t2 = call markChar marked _t1  ; Δ{_t1} · makes String
  let _t2 = call okOr _t1 "no clipboard tool (install wl-clipboard, xclip, or xsel)" rows  ; Δ{}
  let _t2 = call okOr _t1 "set mark failed" rows  ; Δ{}
  let _t2 = call okOrErr _t1 "restore failed" rows  ; Δ{}
  let _t2 = call pdfThumbVar  ; Δ{_t0 _t1} · makes String
  let _t2 = call pendingFile 0  ; Δ{_t0 _t1} · makes String
  let _t2 = call readFileTrim _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = call readInt _t1  ; Δ{_t1} · makes Maybe$Int
  let _t2 = call readInt _t1  ; Δ{_t1} · makes Maybe$Int
  let _t2 = call render cwd sel marked prog rows raw cols _t1 poff  ; Δ{_t1} · makes String
  let _t2 = call render cwd sel marked prog rows raw cols _t1 poff  ; Δ{_t1} · makes String
  let _t2 = call renderSrc cols rows  ; Δ{_t0 _t1} · makes String
  let _t2 = call renderSrc cols rows  ; Δ{_t0 _t1} · makes String
  let _t2 = call selInfo _t1  ; Δ{_t1} · makes String
  let _t2 = call shQuote _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = call shQuote _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = call shQuote _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = call shQuote _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = call shQuote _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = call shQuote cwd  ; Δ{} · makes String
  let _t2 = call shQuote path  ; Δ{_t0 _t1} · makes String
  let _t2 = call spaces _t1  ; Δ{c} · makes String
  let _t2 = call tabiFile 0  ; Δ{_t1} · makes String
  let _t2 = call tabiFile 0  ; Δ{_t1} · makes String
  let _t2 = call tabiFile 0  ; Δ{_t1} · makes String
  let _t2 = call termCols 0  ; Δ{}
  let _t2 = call trim _t1  ; Δ{_t1} · makes String
  let _t2 = call trim _t1  ; Δ{_t1} · makes String
  let _t2 = call trimEnd s _t1  ; Δ{}
  let _t2 = call unlines _t1  ; Δ{_t1} · makes String
  let _t2 = call wordsFrom s j n  ; Δ{_t1} · makes List$String
  let _t2 = con Cons "ico" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = con Cons "m4a" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = con Cons "mpg" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = con Cons "nix" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = con Cons "odt" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = con Cons "zst" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = con Nil  ; Δ{_t1} · makes List$String
  let _t2 = if _t0 then
  let _t2 = if _t1 then
  let _t2 = if _t1 then
  let _t2 = putStr _t1  ; Δ{_t1}
  let _t2 = rtcall axion_getenv "LS_COLORS"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_mkdir_p _t1  ; Δ{_t1}
  let _t2 = rtcall axion_str_cmp _t1 cwd  ; Δ{_t1 c}
  let _t2 = rtcall axion_str_len _t1  ; Δ{_t1}
  let _t2 = rtcall axion_str_len cc  ; Δ{cc}
  let _t2 = rtcall axion_strcat "  " _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat "  Y M S D  mark ALL for the same        p  paste    u  undo trash\n" _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat " 2>/dev/null && pwd || printf %s " _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat "; " _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat "; file -bL --mime-type -- \"$f\" 2>/dev/null; o=$(stat -c '%s|%y' -- \"$f\" 2>/dev/null); s=${o%%|*}; t=${o#*|}; t=${t%%.*}; h=$(printf %s \"$s\" | numfmt --to=iec 2>/dev/null); if [ -L \"$f\" ]; then r=$(readlink \"$f\"); if [ -e \"$f\" ]; then l=\"-> $r\"; else l=\"-> $r (broken)\"; fi; else l=\"\"; fi; printf '%s\\n%s\\n%s\\n' \"${h:-$s}\" \"$t\" \"$l\"; " _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat "cat " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "f=" _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "file -bL --mime-type " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "file -bL --mime-type -- " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "p=" _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "printf '%s\\n%s\\n' \"$t\" \"$r\" > " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "r=$(dd bs=64 count=1 <&3 2>/dev/null); stty \"$old\" <&3; " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "rename " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t0 "\n"  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat _t1 " * ${ch:-14} )); k=\"$HOME/.cache/axfm/sixel/$(printf %s \"$src\"|md5sum|cut -c1-32)_${W}x${H}.six\"; mkdir -p \"${k%/*}\"; if [ ! -f \"$k\" ] || [ \"$src\" -nt \"$k\" ]; then dim=$(identify -format '%wx%h' \"$src\"[0] 2>/dev/null); [ -n \"$dim\" ] || dim=$(file -bL -- \"$src\" 2>/dev/null|grep -oE '[0-9]+ ?x ?[0-9]+'|tr -d ' '|sort -t x -k1,1n|tail -1); iw=${dim%x*}; ih=${dim#*x}; if [ -n \"$dim\" ] && [ \"$((iw*H))\" -ge \"$((ih*W))\" ]; then f=\"-w $W\"; else f=\"-h $H\"; fi; [ -n \"$dim\" ] || f=\"-w $W\"; img2sixel -S -d none $f -- \"$src\" >\"$k.$$.t\" 2>/dev/null && mv \"$k.$$.t\" \"$k\"; fi"  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat _t1 " >/dev/null 2>&1 &"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t1 "'"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t1 "; cat \"$k\" 2>/dev/null; printf '\\033[?25l'"  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat _t1 "; do [ -e \"$d/$(basename -- \"$src\")\" ] && exit 0; done; exit 1"  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat _t1 ";1H"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t1 ";1H"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t1 "\\"  ; Δ{_t0 _t1} · makes String
  let _t2 = rtcall axion_strcat _t1 "cat \"$th\" >/dev/null 2>&1 ;; *) cat \"$src\" >/dev/null 2>&1 ;; esac"  ; Δ{_t0 _t1} · makes String
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
  let _t3 = == _t2 0  ; Δ{c}
  let _t3 = > _t2 0  ; Δ{cc}
  let _t3 = > _t2 0  ; Δ{}
  let _t3 = call absPath _t2  ; Δ{_t2} · makes String
  let _t3 = call absPath _t2  ; Δ{_t2} · makes String
  let _t3 = call buildKeymapCmd  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = call clampSel _t2 n  ; Δ{}
  let _t3 = call cmdLine _t2 rows cwd  ; Δ{_t2} · makes String
  let _t3 = call csi "?25h"  ; Δ{_t2} · makes String
  let _t3 = call csi "?25h"  ; Δ{_t2} · makes String
  let _t3 = call csi "?25h"  ; Δ{_t2} · makes String
  let _t3 = call csi "?25h"  ; Δ{_t2} · makes String
  let _t3 = call csi "?25h"  ; Δ{_t2} · makes String
  let _t3 = call csi "?25h"  ; Δ{_t2} · makes String
  let _t3 = call csi "K"  ; Δ{_t2} · makes String
  let _t3 = call csi _t2  ; Δ{_t2} · makes String
  let _t3 = call csi _t2  ; Δ{_t2} · makes String
  let _t3 = call dup raw  ; Δ{_t2} · makes String
  let _t3 = call linesFrom s _t2 n  ; Δ{_t1} · makes List$String
  let _t3 = call lsColors 0  ; Δ{_t1 _t2 tys} · makes String
  let _t3 = call lsColors 0  ; Δ{_t1 _t2 tys} · makes String
  let _t3 = call matchBefore _t0 q 0 _t1 _t2  ; Δ{_t0}
  let _t3 = call nextSort _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = call pick 0 _t2  ; Δ{_t2} · makes String
  let _t3 = call pick n _t2  ; Δ{_t2} · makes String
  let _t3 = call render cwd msel marked prog rows raw cols _t2 0  ; Δ{_t2} · makes String
  let _t3 = call selPath cwd hidden sel  ; Δ{} · makes String
  let _t3 = call shQuote _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = call shQuote _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = call shQuote _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = call shQuote _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = call shQuote _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = call shQuote _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = call shQuote _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = call shQuote _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = call shQuote cwd  ; Δ{_t0 _t2} · makes String
  let _t3 = call sixelDecode pwc phc  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = call substPct cmd "\"$f\""  ; Δ{_t0 _t2} · makes String
  let _t3 = call substPct cmd "\"$f\""  ; Δ{_t0 _t2} · makes String
  let _t3 = call tabiFile 0  ; Δ{_t0 _t2} · makes String
  let _t3 = call tabiFile 0  ; Δ{_t0 _t2} · makes String
  let _t3 = call trimStart s 0  ; Δ{}
  let _t3 = con Cons "docx" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t3 = con Cons "m4v" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t3 = con Cons "opus" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t3 = con Cons "patch" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t3 = con Cons "rar" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t3 = con Cons "tiff" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t3 = con Nil  ; Δ{_t1 _t2} · makes List$String
  let _t3 = if _t1 then
  let _t3 = if _t1 then
  let _t3 = if _t1 then
  let _t3 = putStr _t2  ; Δ{_t1 _t2}
  let _t3 = putStr _t2  ; Δ{_t2}
  let _t3 = rtcall axion_read_file _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_read_file _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_read_file _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_run _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_run _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_run _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_strcat "  y m s d  mark for cp / mv / ln / trash           c  clear marks\n" _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_strcat " * ${cw:-7} )); H=$(( " _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat " | head -n " _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_strcat ":" _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_strcat "; for src in " _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat "H'; " _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat "\n" _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_strcat "] (" _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_strcat "_Ga=d,d=A" _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat "cat \"$th\" >/dev/null 2>&1 ;; application/pdf) " _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat "if [ \"$k\" = 1 ] && command -v kitten >/dev/null 2>&1; then r=kitten; elif command -v img2sixel >/dev/null 2>&1; then r=img2sixel; fi; " _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_strcat "nohup xdg-open " _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_strcat "old=$(stty -g <&3) || exit 0; stty raw -echo min 0 time 1 <&3; printf '\\033[14t' >/dev/tty; " _t2  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_strcat "src=\"$th\"; " _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_strcat "src=\"$th\"; " _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
  let _t3 = rtcall axion_strcat _t1 _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_strcat _t1 _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_strcat _t1 _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_strcat _t2 " 2>/dev/null | { if [ -n \"$fq\" ]; then grep -iF -- \"$fq\"; else cat; fi; }"  ; Δ{_t2} · makes String
  let _t3 = rtcall axion_strcat _t2 ")"  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_strcat _t2 "; } 2>/dev/null"  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_strcat s _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_substr 1 _t2 nm  ; Δ{_t0} · makes String
  let _t3 = rtcall axion_system _t2  ; Δ{_t2}
  let _t3 = rtcall axion_write_file _t1 _t2  ; Δ{_t1 _t2 q}
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
  let _t4 = call csi "K"  ; Δ{_t2 _t3} · makes String
  let _t4 = call csi "K"  ; Δ{_t2 _t3} · makes String
  let _t4 = call csi "K"  ; Δ{_t2 _t3} · makes String
  let _t4 = call csi "K"  ; Δ{_t2 _t3} · makes String
  let _t4 = call csi "K"  ; Δ{_t2 _t3} · makes String
  let _t4 = call csi "K"  ; Δ{_t2 _t3} · makes String
  let _t4 = call enqueueItems _t1 _t3  ; Δ{_t0 _t1 _t3} · makes String
  let _t4 = call firstLine q  ; Δ{q} · makes String
  let _t4 = call iconsFile 0  ; Δ{_t1 _t3} · makes String
  let _t4 = call iconsOf 0  ; Δ{_t1 _t2 _t3 tys} · makes String
  let _t4 = call iconsOf 0  ; Δ{_t1 _t2 _t3 tys} · makes String
  let _t4 = call lsCmd cwd hidden  ; Δ{_t0 _t2 _t3} · makes String
  let _t4 = call okOr _t3 "bulk-rename: some renames failed" rows  ; Δ{}
  let _t4 = call posStr sel total  ; Δ{_t3} · makes String
  let _t4 = call posStr sel total  ; Δ{_t3} · makes String
  let _t4 = call progVerb prog  ; Δ{_t2 _t3} · makes String
  let _t4 = call renameMaybe cwd hidden sel _t3 rows  ; Δ{_t3}
  let _t4 = call rowCell icfg ty raw _t2 _t3 listW prev  ; Δ{_t2 _t3} · makes String
  let _t4 = call shQuote _t3  ; Δ{_t0 _t2 _t3} · makes String
  let _t4 = call shQuote _t3  ; Δ{_t0 _t2 _t3} · makes String
  let _t4 = call shQuote _t3  ; Δ{_t3} · makes String
  let _t4 = call sixelDecode pwc phc  ; Δ{_t0 _t1 _t2 _t3} · makes String
  let _t4 = call trim _t3  ; Δ{_t0 _t1 _t3} · makes String
  let _t4 = call trim _t3  ; Δ{_t0 _t1 _t3} · makes String
  let _t4 = con Cons "7z" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t4 = con Cons "diff" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t4 = con Cons "doc" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t4 = con Cons "ogg" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t4 = con Cons "svg" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t4 = con Cons "wmv" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t4 = if _t0 then
  let _t4 = if _t0 then
  let _t4 = if _t2 then
  let _t4 = if _t2 then
  let _t4 = if _t2 then
  let _t4 = putStr _t3  ; Δ{_t3}
  let _t4 = rtcall axion_strcat "  <N> j/k/G  repeat / go to line N (count prefix)\n" _t3  ; Δ{_t3} · makes String
  let _t4 = rtcall axion_strcat " || unzip -l " _t3  ; Δ{_t0 _t1 _t3} · makes String
  let _t4 = rtcall axion_strcat "/" _t3  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat ":" _t3  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat "; " _t3  ; Δ{_t0 _t1 _t2 _t3} · makes String
  let _t4 = rtcall axion_strcat "; " _t3  ; Δ{_t0 _t2 _t3} · makes String
  let _t4 = rtcall axion_strcat "; if [ -s \"$tf\" ]; then n=$(grep -c '' \"$tf\"); if [ \"$n\" -gt 1 ]; then ai=0; [ -r \"$ti\" ] && read ai < \"$ti\"; [ -z \"$ai\" ] && ai=0; k=0; " "while IFS= read -r d; do b=${d##*/}; [ -z \"$b\" ] && b=/; if [ \"$k\" = \"$ai\" ]; then tb=\"$tb [$((k+1)):$b]\"; else tb=\"$tb $((k+1)):$b\"; fi; k=$((k+1)); done < \"$tf\"; fi; fi; printf '%s\\n' \"$tb\""  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat "cd -- " _t3  ; Δ{_t3} · makes String
  let _t4 = rtcall axion_strcat "command -v stty >/dev/null 2>&1 || exit 0; { exec 3</dev/tty; } 2>/dev/null || exit 0; " _t3  ; Δ{_t3} · makes String
  let _t4 = rtcall axion_strcat "f=" _t3  ; Δ{_t3} · makes String
  let _t4 = rtcall axion_strcat "tmp=\"$f.$$\"; k=0; while IFS= read -r dd; do [ \"$k\" = \"$ai\" ] || printf '%s\\n' \"$dd\"; k=$((k+1)); done < \"$f\" > \"$tmp\"; mv \"$tmp\" \"$f\"; " "ni=$ai; [ \"$ni\" -ge \"$((n-1))\" ] && ni=$((n-2)); printf '%s' \"$ni\" > \"$i\"; sed -n \"$((ni+1))p\" \"$f\""  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat "while IFS= read -r line; do case \"$line\" in *local*=*{*}*) name=$(printf '%s\\n' \"$line\" | sed -n 's/.*local[[:space:]]\\{1,\\}\\([A-Za-z_][A-Za-z0-9_]*\\)[[:space:]]*=.*/\\1/p'); [ -n \"$name\" ] || continue; body=$(printf '%s\\n' \"$line\" | sed -n 's/.*{\\(.*\\)}.*/\\1/p'); items=$(printf '%s\\n' \"$body\" | grep -o '\"[^\"]*\"' | sed 's/^\"//; s/\"$//' | paste -sd \"$T\" -); [ -n \"$items\" ] && printf '%s\\t%s\\n' \"$name\" \"$items\" >> \"$defs\" ;; esac; done < \"$src\"; " "while IFS= read -r line; do case \"$line\" in *key*action*) k=$(printf '%s\\n' \"$line\" | sed -n 's/.*key[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); [ -n \"$k\" ] || continue; ap=${line#*action}; case \"$ap\" in *{*) body=$(printf '%s\\n' \"$ap\" | sed -n 's/.*{\\(.*\\)}.*/\\1/p'); items=$(printf '%s\\n' \"$body\" | grep -o '\"[^\"]*\"' | sed 's/^\"//; s/\"$//' | paste -sd \"$T\" -) ;; *) x=$(printf '%s\\n' \"$ap\" | sed -n 's/[^\"]*\"\\([^\"]*\\)\".*/\\1/p'); d=$(grep \"^$x$T\" \"$defs\" 2>/dev/null | head -n1); if [ -n \"$d\" ]; then items=${d#*$T}; else items=\"$x\"; fi ;; esac; [ -n \"$items\" ] && printf '%s\\t%s\\n' \"$k\" \"$items\" >> \"$km\" ;; esac; done < \"$src\"; rm -f \"$src\" \"$defs\"; true"  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _t4 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _t4 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _t4 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _t4 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t0 _t1 _t3} · makes String
  let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t0 _t1 _t3} · makes String
  let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t3} · makes String
  let _t4 = rtcall axion_strcat _t3 " -- \"$src\"; printf '\\033[?25l'"  ; Δ{_t0 _t1 _t2 _t3} · makes String
  let _t4 = rtcall axion_strcat _t3 " ; } >/dev/null 2>&1"  ; Δ{_t0 _t2 _t3} · makes String
  let _t4 = rtcall axion_strcat _t3 "; mkdir -p \"${f%/*}\"; t=$(printf '\\t'); tmp=\"$f.$$\"; : > \"$tmp\"; [ -f \"$f\" ] && while IFS=\"$t\" read -r k v; do [ \"$k\" = \"$L\" ] || printf '%s\\t%s\\n' \"$k\" \"$v\"; done < \"$f\" >> \"$tmp\"; printf '%s\\t%s\\n' \"$L\" \"$P\" >> \"$tmp\" && mv \"$tmp\" \"$f\""  ; Δ{_t0 _t1 _t3} · makes String
  let _t4 = rtcall axion_strcat _t3 "; tmp=\"$cf.$$\"; mkdir -p \"${cf%/*}\"; : > \"$tmp\"; [ -r \"$cfg\" ] && sed '/^[[:space:]]*--/d' \"$cfg\" | while IFS= read -r line; do case \"$line\" in *color*=*) m=$(printf '%s\\n' \"$line\" | sed -n 's/.*match[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); v=$(printf '%s\\n' \"$line\" | sed -n 's/.*color[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); [ -n \"$m\" ] || continue; case \"$v\" in \\#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) r=$((0x$(printf %s \"$v\"|cut -c2-3))); g=$((0x$(printf %s \"$v\"|cut -c4-5))); b=$((0x$(printf %s \"$v\"|cut -c6-7))); v=\"38;2;$r;$g;$b\" ;; esac; printf '%s=%s:' \"$m\" \"$v\" >> \"$tmp\" ;; esac; done; mv \"$tmp\" \"$cf\"; true"  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat _t3 "; tmp=\"$icf.$$\"; mkdir -p \"${icf%/*}\"; : > \"$tmp\"; if [ -r \"$cfg\" ] && sed '/^[[:space:]]*--/d' \"$cfg\" | grep -qE 'icons[[:space:]]*=[[:space:]]*false'; then :; else printf ':' > \"$tmp\"; [ -r \"$cfg\" ] && sed '/^[[:space:]]*--/d' \"$cfg\" | while IFS= read -r line; do case \"$line\" in *icon*=*) m=$(printf '%s\\n' \"$line\" | sed -n 's/.*match[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); v=$(printf '%s\\n' \"$line\" | sed -n 's/.*icon[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'); [ -n \"$m\" ] || continue; printf '%s=%s:' \"$m\" \"$v\" >> \"$tmp\" ;; esac; done; fi; mv \"$tmp\" \"$icf\"; true"  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat _t3 "\n"  ; Δ{_t0 _t3} · makes String
  let _t4 = rtcall axion_strcat delta " + n) % n )); printf '%s' \"$ni\" > \"$i\"; sed -n \"$((ni+1))p\" \"$f\""  ; Δ{_t1 _t3} · makes String
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
  let _t5 = call entryColor lsc ty raw  ; Δ{_t4} · makes String
  let _t5 = call errRedir  ; Δ{_t4} · makes String
  let _t5 = call markSeg marked prog  ; Δ{_t3 _t4} · makes String
  let _t5 = call okOr _t4 "mkdir failed" rows  ; Δ{}
  let _t5 = call okOr _t4 "mkfile failed" rows  ; Δ{}
  let _t5 = call okOr _t4 "rename failed" rows  ; Δ{}
  let _t5 = call paint "1;31" msg  ; Δ{_t2 _t3 _t4} · makes String
  let _t5 = call paint "1;36" msg  ; Δ{_t2 _t3 _t4} · makes String
  let _t5 = call rdtTypes cwd _t0 hidden _t4  ; Δ{_t0 _t1 _t4} · makes String
  let _t5 = call rdtTypes cwd _t0 hidden _t4  ; Δ{_t0 _t1 _t4} · makes String
  let _t5 = call shQuote _t4  ; Δ{_t1 _t3 _t4} · makes String
  let _t5 = call tabSeg info  ; Δ{_t3 _t4} · makes String
  let _t5 = call windowLines raw start mx  ; Δ{_t1 _t2 _t3 _t4 tys} · makes List$String
  let _t5 = call windowLines raw start mx  ; Δ{_t1 _t2 _t3 _t4 tys} · makes List$String
  let _t5 = con Cons "bz2" _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t5 = con Cons "conf" _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t5 = con Cons "djvu" _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t5 = con Cons "flv" _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t5 = con Cons "wav" _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t5 = con Cons "webp" _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t5 = putStr _t4  ; Δ{_t4}
  let _t5 = rtcall axion_run _t4  ; Δ{_t4} · makes String
  let _t5 = rtcall axion_strcat "  t  new tab           T  close tab      ] / [  next / prev tab\n" _t4  ; Δ{_t4} · makes String
  let _t5 = rtcall axion_strcat "/" acc  ; Δ{_t2 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat "; " _t4  ; Δ{_t0 _t4} · makes String
  let _t5 = rtcall axion_strcat "; " _t4  ; Δ{_t0 _t4} · makes String
  let _t5 = rtcall axion_strcat "; cf=" _t4  ; Δ{_t1 _t4} · makes String
  let _t5 = rtcall axion_strcat "; defs=\"$km.defs\"; src=\"$km.src\"; T=$(printf '\\t'); mkdir -p \"${km%/*}\"; : > \"$km\"; : > \"$defs\"; [ -r \"$cfg\" ] || { rm -f \"$defs\"; exit 0; }; sed '/^[[:space:]]*--/d' \"$cfg\" > \"$src\"; " _t4  ; Δ{_t1 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat "; f=" _t4  ; Δ{_t0 _t1 _t4} · makes String
  let _t5 = rtcall axion_strcat "; icf=" _t4  ; Δ{_t1 _t4} · makes String
  let _t5 = rtcall axion_strcat "; mkdir -p \"${f%/*}\"; [ -s \"$f\" ] || printf '%s\\n' \"$P\" > \"$f\"; " "printf '%s\\n' \"$P\" >> \"$f\"; n=$(grep -c '' \"$f\"); printf '%s' \"$((n-1))\" > \"$i\""  ; Δ{_t0 _t2 _t4} · makes String
  let _t5 = rtcall axion_strcat "; { " _t4  ; Δ{_t0 _t2 _t4} · makes String
  let _t5 = rtcall axion_strcat "ai=0; [ -r \"$i\" ] && read ai < \"$i\"; [ -z \"$ai\" ] && ai=0; " _t4  ; Δ{_t1 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat "count: " acc  ; Δ{_t2 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat "d=" _t4  ; Δ{_t4} · makes String
  let _t5 = rtcall axion_strcat "ni=$(( (ai + " _t4  ; Δ{_t1 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat "tmp=\"$f.$$\"; n=0; while IFS= read -r d; do if [ \"$n\" = \"$ai\" ]; then printf '%s\\n' \"$P\"; else printf '%s\\n' \"$d\"; fi; n=$((n+1)); done < \"$f\" > \"$tmp\"; " "mv \"$tmp\" \"$f\"; fi"  ; Δ{_t0 _t2 _t4} · makes String
  let _t5 = rtcall axion_strcat "x" _t4  ; Δ{_t0 _t1 _t2 _t4} · makes String
  let _t5 = rtcall axion_strcat _t1 _t4  ; Δ{_t0 _t1 _t4} · makes String
  let _t5 = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
  let _t5 = rtcall axion_strcat _t2 _t4  ; Δ{_t0 _t1 _t2 _t4} · makes String
  let _t5 = rtcall axion_strcat _t2 _t4  ; Δ{_t0 _t2 _t4} · makes String
  let _t5 = rtcall axion_strcat _t3 _t4  ; Δ{_t1 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat _t4 " ;; esac"  ; Δ{_t0 _t1 _t2 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat _t4 ") | while IFS= read -r n; do p=\"$d/${n%/}\"; if [ -L \"$p\" ]; then { [ -e \"$p\" ] && printf 'l\\n' || printf 'b\\n'; }; elif [ -d \"$p\" ]; then printf 'd\\n'; elif [ -x \"$p\" ]; then printf 'x\\n'; else printf 'f\\n'; fi; done; } > \"$tmp\" 2>/dev/null; mv \"$tmp\" \"$t\""  ; Δ{_t0 _t2 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat _t4 prompt  ; Δ{_t2 _t3 _t4} · makes String
  let _t5 = rtcall axion_strcat prompt acc  ; Δ{_t2 _t3 _t4} · makes String
  let _t5 = rtcall axion_write_file _t0 _t4  ; Δ{_t0 _t4}
  let _t5 = rtcall axion_write_file _t0 _t4  ; Δ{_t0 _t4}
  let _t5 = showInt n  ; Δ{_t2 _t3 _t4} · makes String
  let _t50 = con Cons "cc" _t49  ; Δ{_t49} · moves{_t49} · makes List$String
  let _t51 = con Cons "hpp" _t50  ; Δ{_t50} · moves{_t50} · makes List$String
  let _t52 = con Cons "cpp" _t51  ; Δ{_t51} · moves{_t51} · makes List$String
  let _t53 = con Cons "h" _t52  ; Δ{_t52} · moves{_t52} · makes List$String
  let _t6 = call colorCell _t4 i sel _t5  ; Δ{_t4 _t5} · makes String
  let _t6 = call configFile 0  ; Δ{_t1 _t3 _t5} · makes String
  let _t6 = call drawRows _t3 _t4 _t5 tys start sel marked cwd lw prev  ; Δ{_t1 _t2 _t3 _t4 _t5 tys} · makes String
  let _t6 = call drawRows _t3 _t4 _t5 tys start sel marked cwd lw prev  ; Δ{_t1 _t2 _t3 _t4 _t5 tys} · makes String
  let _t6 = call markSeg marked prog  ; Δ{_t3 _t4 _t5} · makes String
  let _t6 = con Cons "avi" _t5  ; Δ{_t5} · moves{_t5} · makes List$String
  let _t6 = con Cons "bmp" _t5  ; Δ{_t5} · moves{_t5} · makes List$String
  let _t6 = con Cons "cfg" _t5  ; Δ{_t5} · moves{_t5} · makes List$String
  let _t6 = con Cons "epub" _t5  ; Δ{_t5} · moves{_t5} · makes List$String
  let _t6 = con Cons "flac" _t5  ; Δ{_t5} · moves{_t5} · makes List$String
  let _t6 = con Cons "xz" _t5  ; Δ{_t5} · moves{_t5} · makes List$String
  let _t6 = rtcall axion_strcat "  b  set bookmark      B  jump to bookmark        1-9  favourites\n" _t5  ; Δ{_t5} · makes String
  let _t6 = rtcall axion_strcat " " cwd  ; Δ{_t3 _t4 _t5} · makes String
  let _t6 = rtcall axion_strcat " && f=" _t5  ; Δ{_t0 _t5} · makes String
  let _t6 = rtcall axion_strcat " ;; *) " _t5  ; Δ{_t0 _t1 _t2 _t3 _t5} · makes String
  let _t6 = rtcall axion_strcat " || tar -tf " _t5  ; Δ{_t0 _t5} · makes String
  let _t6 = rtcall axion_strcat "; " _t5  ; Δ{_t0 _t1 _t5} · makes String
  let _t6 = rtcall axion_strcat "; (" _t5  ; Δ{_t0 _t2 _t3 _t5} · makes String
  let _t6 = rtcall axion_strcat "; [ -s \"$f\" ] || exit 0; n=$(grep -c '' \"$f\"); [ \"$n\" -le 1 ] && exit 0; " _t5  ; Δ{_t1 _t3 _t5} · makes String
  let _t6 = rtcall axion_strcat "; [ -s \"$f\" ] || exit 0; n=$(grep -c '' \"$f\"); ai=0; [ -r \"$i\" ] && read ai < \"$i\"; [ -z \"$ai\" ] && ai=0; " _t5  ; Δ{_t1 _t3 _t5} · makes String
  let _t6 = rtcall axion_strcat "; ti=" _t5  ; Δ{_t1 _t5} · makes String
  let _t6 = rtcall axion_strcat "if [ ! -s \"$f\" ]; then printf '%s\\n' \"$P\" > \"$f\"; printf 0 > \"$i\"; else " _t5  ; Δ{_t0 _t2 _t4 _t5} · makes String
  let _t6 = rtcall axion_strcat _t0 _t5  ; Δ{_t0 _t5} · makes String
  let _t6 = rtcall axion_strcat _t0 _t5  ; Δ{_t0 _t5} · makes String
  let _t6 = rtcall axion_strcat _t1 _t5  ; Δ{_t0 _t1 _t5} · makes String
  let _t6 = rtcall axion_strcat _t1 _t5  ; Δ{_t1 _t5} · makes String
  let _t6 = rtcall axion_strcat _t1 _t5  ; Δ{_t1 _t5} · makes String
  let _t6 = rtcall axion_strcat _t2 _t5  ; Δ{_t0 _t1 _t2 _t5} · makes String
  let _t6 = rtcall axion_strcat _t2 _t5  ; Δ{_t0 _t2 _t5} · makes String
  let _t6 = rtcall axion_strcat _t3 _t5  ; Δ{_t1 _t3 _t5} · makes String
  let _t6 = rtcall axion_strcat _t3 _t5  ; Δ{_t2 _t3 _t5} · makes String
  let _t6 = rtcall axion_strcat _t4 _t5  ; Δ{_t0 _t2 _t4 _t5} · makes String
  let _t6 = rtcall axion_strcat _t4 _t5  ; Δ{_t2 _t3 _t4 _t5} · makes String
  let _t6 = rtcall axion_strcat _t4 _t5  ; Δ{_t2 _t3 _t4 _t5} · makes String
  let _t6 = rtcall axion_strcat _t4 _t5  ; Δ{_t2 _t3 _t4 _t5} · makes String
  let _t6 = rtcall axion_strcat _t4 _t5  ; Δ{_t4 _t5} · makes String
  let _t6 = rtcall axion_strcat _t5 "  —  any key"  ; Δ{_t2 _t3 _t4 _t5} · makes String
  let _t6 = rtcall axion_strcat _t5 "  —  any key"  ; Δ{_t2 _t3 _t4 _t5} · makes String
  let _t6 = rtcall axion_strcat _t5 " item(s)…"  ; Δ{_t2 _t3 _t4 _t5} · makes String
  let _t6 = rtcall axion_system _t5  ; Δ{_t5}
  let _t6 = rtcall axion_write_file _t1 _t5  ; Δ{_t0 _t1 _t5}
  let _t6 = rtcall axion_write_file _t1 _t5  ; Δ{_t0 _t1 _t5}
  let _t6 = showInt _t5  ; Δ{rng} · makes String
  let _t7 = + poff ph  ; Δ{_t6 rng}
  let _t7 = call metaSeg info  ; Δ{_t3 _t4 _t5 _t6} · makes String
  let _t7 = call sepSeg lw mx prev  ; Δ{_t1 _t2 _t6} · makes String
  let _t7 = call sepSeg lw mx prev  ; Δ{_t1 _t2 _t6} · makes String
  let _t7 = call shQuote _t6  ; Δ{_t1 _t3 _t5 _t6} · makes String
  let _t7 = con Cons "gif" _t6  ; Δ{_t6} · moves{_t6} · makes List$String
  let _t7 = con Cons "gz" _t6  ; Δ{_t6} · moves{_t6} · makes List$String
  let _t7 = con Cons "ini" _t6  ; Δ{_t6} · moves{_t6} · makes List$String
  let _t7 = con Cons "mov" _t6  ; Δ{_t6} · moves{_t6} · makes List$String
  let _t7 = rtcall axion_strcat "  x  attributes      X  toggle +x       i  size (du)\n" _t6  ; Δ{_t6} · makes String
  let _t7 = rtcall axion_strcat " " _t6  ; Δ{_t2 _t3 _t4 _t6} · makes String
  let _t7 = rtcall axion_strcat " && f=" _t6  ; Δ{_t0 _t6} · makes String
  let _t7 = rtcall axion_strcat "; P=" _t6  ; Δ{_t0 _t6} · makes String
  let _t7 = rtcall axion_strcat "; i=" _t6  ; Δ{_t0 _t2 _t6} · makes String
  let _t7 = rtcall axion_strcat "; km=" _t6  ; Δ{_t1 _t6} · makes String
  let _t7 = rtcall axion_strcat "; mkdir -p \"${f%/*}\"; ai=0; [ -r \"$i\" ] && read ai < \"$i\" 2>/dev/null; [ -z \"$ai\" ] && ai=0; " _t6  ; Δ{_t0 _t2 _t4 _t6} · makes String
  let _t7 = rtcall axion_strcat "@" _t6  ; Δ{_t0 _t1 _t6} · makes String
  let _t7 = rtcall axion_strcat _t0 _t6  ; Δ{_t0 _t6} · makes String
  let _t7 = rtcall axion_strcat _t0 _t6  ; Δ{_t0 _t6} · makes String
  let _t7 = rtcall axion_strcat _t1 _t6  ; Δ{_t0 _t1 _t6} · makes String
  let _t7 = rtcall axion_strcat _t1 _t6  ; Δ{_t1 _t6} · makes String
  let _t7 = rtcall axion_strcat _t2 _t6  ; Δ{_t2 _t6} · makes String
  let _t7 = rtcall axion_strcat _t2 _t6  ; Δ{_t6} · makes String
  let _t7 = rtcall axion_strcat _t3 _t6  ; Δ{_t0 _t1 _t2 _t3 _t6} · makes String
  let _t7 = rtcall axion_strcat _t3 _t6  ; Δ{_t0 _t2 _t3 _t6} · makes String
  let _t7 = rtcall axion_strcat _t3 _t6  ; Δ{_t1 _t3 _t6} · makes String
  let _t7 = rtcall axion_strcat _t3 _t6  ; Δ{_t1 _t3 _t6} · makes String
  let _t7 = rtcall axion_strcat _t3 _t6  ; Δ{_t2 _t3 _t6} · makes String
  let _t7 = rtcall axion_strcat _t3 _t6  ; Δ{_t2 _t3 _t6} · makes String
  let _t7 = rtcall axion_strcat _t3 _t6  ; Δ{_t2 _t3 _t6} · makes String
  let _t7 = rtcall axion_strcat _t4 _t6  ; Δ{_t2 _t3 _t4 _t6} · makes String
  let _t7 = rtcall axion_strcat _t4 _t6  ; Δ{_t2 _t3 _t4 _t6} · makes String
  let _t7 = rtcall axion_strcat _t5 _t6  ; Δ{_t3 _t4 _t5 _t6} · makes String
  let _t8 = call infoMime info  ; Δ{_t1 _t2 _t6 _t7} · makes String
  let _t8 = call linkSeg info  ; Δ{_t3 _t4 _t5 _t6 _t7} · makes String
  let _t8 = call listStatus cwd total sel marked prog rows  ; Δ{_t1 _t2 _t6 _t7} · makes String
  let _t8 = con Cons "hcl" _t7  ; Δ{_t7} · moves{_t7} · makes List$String
  let _t8 = con Cons "png" _t7  ; Δ{_t7} · moves{_t7} · makes List$String
  let _t8 = con Cons "tar" _t7  ; Δ{_t7} · moves{_t7} · makes List$String
  let _t8 = con Cons "webm" _t7  ; Δ{_t7} · moves{_t7} · makes List$String
  let _t8 = if _t2 then
  let _t8 = putStr _t7  ; Δ{_t7}
  let _t8 = rtcall axion_strcat "  n  mkdir           f  mkfile          r  rename   e  refresh\n" _t7  ; Δ{_t7} · makes String
  let _t8 = rtcall axion_strcat "; i=" _t7  ; Δ{_t1 _t7} · makes String
  let _t8 = rtcall axion_strcat "; i=" _t7  ; Δ{_t1 _t7} · makes String
  let _t8 = rtcall axion_strcat "; tmp=\"$t.$$\"; { printf '%s\\n' " _t7  ; Δ{_t0 _t2 _t7} · makes String
  let _t8 = rtcall axion_strcat "src=\"$th\"; " _t7  ; Δ{_t0 _t1 _t2 _t7} · makes String
  let _t8 = rtcall axion_strcat _t0 _t7  ; Δ{_t0 _t7} · makes String
  let _t8 = rtcall axion_strcat _t0 _t7  ; Δ{_t0 _t7} · makes String
  let _t8 = rtcall axion_strcat _t0 _t7  ; Δ{_t0 _t7} · makes String
  let _t8 = rtcall axion_strcat _t1 _t7  ; Δ{_t0 _t1 _t7} · makes String
  let _t8 = rtcall axion_strcat _t1 _t7  ; Δ{_t1 _t7} · makes String
  let _t8 = rtcall axion_strcat _t2 _t7  ; Δ{_t0 _t2 _t7} · makes String
  let _t8 = rtcall axion_strcat _t2 _t7  ; Δ{_t2 _t7} · makes String
  let _t8 = rtcall axion_strcat _t3 _t7  ; Δ{_t2 _t3 _t7} · makes String
  let _t8 = rtcall axion_strcat _t3 _t7  ; Δ{_t2 _t3 _t7} · makes String
  let _t8 = rtcall axion_strcat _t4 _t7  ; Δ{_t0 _t2 _t4 _t7} · makes String
  let _t8 = rtcall axion_strcat _t4 _t7  ; Δ{_t2 _t3 _t4 _t7} · makes String
  let _t8 = rtcall axion_strcat _t4 _t7  ; Δ{_t3 _t4 _t7} · makes String
  let _t8 = rtcall axion_strcat _t7 "; [ -f \"$km\" ] && [ -f \"$cf\" ] && [ -f \"$ic\" ] && { [ ! -f \"$cg\" ] || { [ \"$km\" -nt \"$cg\" ] && [ \"$cf\" -nt \"$cg\" ] && [ \"$ic\" -nt \"$cg\" ]; }; } && exit 0; "  ; Δ{_t1 _t3 _t5 _t7} · makes String
  let _t8 = rtcall axion_system _t7  ; Δ{_t7}
  let _t8 = showInt _t7  ; Δ{_t6 rng} · makes String
  let _t9 = call okOrErr _t8 "chmod failed" rows  ; Δ{}
  let _t9 = call paint "1;33" _t8  ; Δ{_t2 _t3 _t8} · makes String
  let _t9 = call paint "7" _t8  ; Δ{_t3 _t8} · makes String
  let _t9 = call previewSeg cwd sel raw cols mx prev _t8 poff  ; Δ{_t1 _t2 _t6 _t7 _t8} · makes String
  let _t9 = con Cons "jpeg" _t8  ; Δ{_t8} · moves{_t8} · makes List$String
  let _t9 = con Cons "mkv" _t8  ; Δ{_t8} · moves{_t8} · makes List$String
  let _t9 = con Cons "tf" _t8  ; Δ{_t8} · moves{_t8} · makes List$String
  let _t9 = putStr _t8  ; Δ{_t8}
  let _t9 = rtcall axion_strcat "  F  filter          :  go to dir       ~ home    -  previous dir\n" _t8  ; Δ{_t8} · makes String
  let _t9 = rtcall axion_strcat " " cwd  ; Δ{_t3 _t4 _t5 _t6 _t7 _t8} · makes String
  let _t9 = rtcall axion_strcat "; cg=" _t8  ; Δ{_t1 _t3 _t5 _t8} · makes String
  let _t9 = rtcall axion_strcat "; f=" _t8  ; Δ{_t0 _t8} · makes String
  let _t9 = rtcall axion_strcat "; i=" _t8  ; Δ{_t0 _t2 _t8} · makes String
  let _t9 = rtcall axion_strcat "x" _t8  ; Δ{_t0 _t8} · makes String
  let _t9 = rtcall axion_strcat _t1 _t8  ; Δ{_t1 _t8} · makes String
  let _t9 = rtcall axion_strcat _t1 _t8  ; Δ{_t1 _t8} · makes String
  let _t9 = rtcall axion_strcat _t2 _t8  ; Δ{_t0 _t1 _t2 _t8} · makes String
  let _t9 = rtcall axion_strcat _t2 _t8  ; Δ{_t0 _t2 _t8} · makes String
  let _t9 = rtcall axion_strcat _t2 _t8  ; Δ{_t2 _t8} · makes String
  let _t9 = rtcall axion_strcat _t2 _t8  ; Δ{_t2 _t8} · makes String
  let _t9 = rtcall axion_strcat _t7 _t8  ; Δ{_t1 _t2 _t6 _t7 _t8} · makes String
  let _t9 = rtcall axion_strcat _t8 "p"  ; Δ{_t6 _t8 rng} · makes String
  let a = call lookupAction km s  ; Δ{} · makes String
  let c = call clip s w  ; Δ{} · makes String
  let c = call lscVal icfg "di"  ; Δ{} · makes String
  let c = call lscVal icfg "ex"  ; Δ{} · makes String
  let c = call lscVal icfg "ln"  ; Δ{} · makes String
  let c = call lscVal icfg "or"  ; Δ{} · makes String
  let c = call lscVal icfg _t0  ; Δ{_t0} · makes String
  let c = call lscVal lsc "di"  ; Δ{} · makes String
  let c = call lscVal lsc "ex"  ; Δ{} · makes String
  let c = call lscVal lsc "ln"  ; Δ{} · makes String
  let c = call lscVal lsc "or"  ; Δ{} · makes String
  let c = call lscVal lsc _t0  ; Δ{_t0} · makes String
  let c = rtcall axion_read_file _t0  ; Δ{_t0} · makes String
  let cc = call catColor lsc ext  ; Δ{} · makes String
  let cc = call lscVal icfg _t1  ; Δ{_t1} · makes String
  let e = call extOf _t0  ; Δ{_t0} · makes String
  let fav = rtcall axion_getenv _t0  ; Δ{_t0} · makes String
  let h = call maxItems rows  ; Δ{}
  let i = call lineOffset s idx  ; Δ{}
  let i = call nlIdx s  ; Δ{}
  let i = call nlIdx s  ; Δ{}
  let i = call tabIdx line  ; Δ{}
  let i = call tabIdx line  ; Δ{}
  let k = call lastIndex 46 s 0 _t0  ; Δ{}
  let k = rtcall axion_read_key 0  ; Δ{} · makes String
  let k = rtcall axion_read_key_timeout ms  ; Δ{} · makes String
  let km = rtcall axion_read_file _t0  ; Δ{_t0} · makes String
  let l = call infoLink info  ; Δ{} · makes String
  let lw = call listWidth cols  ; Δ{tys}
  let lw = call listWidth cols  ; Δ{tys}
  let msel = call searchSel _t0 acc osel  ; Δ{_t0}
  let mx = call maxItems rows  ; Δ{}
  let mx = call maxItems rows  ; Δ{}
  let n = call countLines raw  ; Δ{}
  let nm = call rdtName ln  ; Δ{} · makes String
  let p = - poff _t0  ; Δ{}
  let pat = rtcall axion_strcat key "="  ; Δ{} · makes String
  let prev = if _t0 then
  let prev = if _t0 then
  let q = rtcall axion_read_file _t0  ; Δ{_t0} · makes String
  let rng = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
  let sed = rtcall axion_strcat _t6 _t10  ; Δ{_t10 _t6 rng} · makes String
  let start = call viewStart sel total mx  ; Δ{}
  let start = call viewStart sel total mx  ; Δ{}
  let tb = call infoTabs info  ; Δ{} · makes String
  let total = call countLines raw  ; Δ{}
  let total = call countLines raw  ; Δ{}
  let total = call countLines raw  ; Δ{}
  let tys = call frameTys cwd start mx  ; Δ{} · makes List$String
  let tys = call frameTys cwd start mx  ; Δ{} · makes List$String
  let v = rtcall axion_getenv "VISUAL"  ; Δ{} · makes String
  let v = rtcall axion_getenv name  ; Δ{} · makes String
  ret " 2>\"$HOME/.cache/axfm/err\""  ; Δ{}
  ret "\u{1b}"  ; Δ{}
  ret "th=\"$HOME/.cache/axfm/thumb/$(printf %s \"$src\"|md5sum|cut -c1-32).png\"; mkdir -p \"${th%/*}\"; { [ -f \"$th\" ] && [ \"$th\" -nt \"$src\" ]; } || { ffmpegthumbnailer -i \"$src\" -o \"$th.$$.png\" -s 512 2>/dev/null || ffmpeg -y -ss 1 -i \"$src\" -frames:v 1 -vf scale=512:-1 \"$th.$$.png\" 2>/dev/null; mv \"$th.$$.png\" \"$th\" 2>/dev/null; }; "  ; Δ{}
  ret "th=\"$HOME/.cache/axfm/thumb/$(printf %s \"$src\"|md5sum|cut -c1-32).png\"; mkdir -p \"${th%/*}\"; { [ -f \"$th\" ] && [ \"$th\" -nt \"$src\" ]; } || { pdftoppm -png -f 1 -l 1 -r 96 -singlefile \"$src\" \"${th%.png}.$$\" 2>/dev/null; mv \"${th%.png}.$$.png\" \"$th\" 2>/dev/null; }; "  ; Δ{}
  ret + _t0 2  ; Δ{}
  ret + _t1 1  ; Δ{}
  ret + poff _t0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 40  ; Δ{}
  ret 60  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret == _t0 100  ; Δ{}
  ret == _t1 0  ; Δ{}
  ret == _t2 0  ; Δ{}
  ret == _t2 0  ; Δ{}
  ret == _t3 0  ; Δ{}
  ret == _t6 0  ; Δ{}
  ret > _t0 0  ; Δ{}
  ret > _t0 4  ; Δ{}
  ret > _t1 0  ; Δ{}
  ret > _t2 0  ; Δ{}
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
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call baseAfter s _t1  ; Δ{} · makes String
  ret call capLine 1  ; Δ{} · makes String
  ret call clGo s 0 _t0  ; Δ{}
  ret call clampNeg _t1 from  ; Δ{}
  ret call clampNeg _t3 from  ; Δ{}
  ret call clipGo s 0 _t0 0 w  ; Δ{} · makes String
  ret call cmdGo prompt rows cwd ""  ; Δ{} · makes String
  ret call dirBefore s _t1  ; Δ{} · makes String
  ret call dispatchWait cwd sel marked prog hidden rows cols raw poff _t0  ; Δ{_t0} · moves{_t0}
  ret call forceWrite _t3 _t4  ; Δ{_t4} · moves{_t4} · makes String
  ret call fromMaybe 24 _t2  ; Δ{_t2} · moves{_t2}
  ret call fromMaybe 80 _t2  ; Δ{_t2} · moves{_t2}
  ret call infixGo q s 0 _t2  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call linesFrom s 0 _t0  ; Δ{} · makes List$String
  ret call loGo s idx 0 _t0  ; Δ{}
  ret call loop cwd _t1 marked prog hidden rows _t2 raw  ; Δ{}
  ret call loopAt cwd sel marked prog hidden rows cols raw 0  ; Δ{}
  ret call nlScan s 0  ; Δ{}
  ret call not _t1  ; Δ{}
  ret call rdtPartGo _t1 _t2 _t3  ; Δ{_t1 _t2 _t3} · moves{_t1 _t2 _t3} · makes List$String
  ret call searchLoop cwd sel marked prog hidden rows cols raw sel ""  ; Δ{}
  ret call sepGo col 1 mx  ; Δ{} · makes String
  ret call spGo cmd rep 0  ; Δ{} · makes String
  ret call t2n s 0  ; Δ{} · makes String
  ret call tabScan s 0  ; Δ{}
  ret call tabSwitch cwd sel marked prog hidden rows "-1"  ; Δ{}
  ret call tabSwitch cwd sel marked prog hidden rows "1"  ; Δ{}
  ret call toLowerGo s 0 _t0  ; Δ{} · makes String
  ret call windowGo cwd raw lo hi ""  ; Δ{} · makes String
  ret call windowPaths cwd raw _t1 _t3  ; Δ{} · makes String
  ret call wlGo s _t0 _t1 count  ; Δ{} · makes List$String
  ret call wordsFrom s 0 _t0  ; Δ{} · makes List$String
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t10 of
  ret case _t10 of
  ret case _t2 of
  ret case _t2 of
  ret case _t2 of
  ret case _t2 of
  ret case _t2 of
  ret case _t2 of
  ret case _t2 of
  ret case _t2 of
  ret case _t3 of
  ret case _t3 of
  ret case _t3 of
  ret case _t4 of
  ret case _t4 of
  ret case _t4 of
  ret case _t5 of
  ret case _t5 of
  ret case _t5 of
  ret case _t5 of
  ret case _t5 of
  ret case _t5 of
  ret case _t6 of
  ret case _t6 of
  ret case _t8 of
  ret case _t9 of
  ret case _t9 of
  ret case m of
  ret case olds of
  ret case win of
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
  ret if _t4 then
  ret if _t4 then
  ret if _t4 then
  ret if _t8 then
  ret if b then
  ret if prev then
  ret if prev then
  ret if prev then
  ret if yes then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_substr 0 1 ln  ; Δ{} · makes String
  ret rtcall axion_substr 0 _t0 s  ; Δ{} · makes String
  ret rtcall axion_substr 1 _t1 ln  ; Δ{} · makes String
  ret rtcall axion_substr _t0 _t4 s  ; Δ{} · makes String
  ret rtcall axion_substr j _t1 s  ; Δ{} · makes String
  ret s  ; Δ{}
  ret x  ; Δ{}
</> a b  =
<=$Int x y  =
>=$Int x y  =
absPath d  =
actionKey a  =
actionPick s kc  =
allPaths cwd hidden  =
allPathsOf cwd raw  =
anyCollide cwd marked  =
applyCount cwd sel marked prog hidden rows cols raw k n  =
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
bookmarkFile d  =
bottomMatch raw q from  =
buildColorsCmd  =
buildConfig d  =
buildConfigGuard  =
buildIconsCmd  =
buildKeymapCmd  =
bulkApply olds news cwd  =
bulkRun cwd marked tmp  =
bulkTmp d  =
capLine n  =
capsFile d  =
catColor lsc ext  =
catOf e  =
catOrBuiltin lsc ext  =
catOrBuiltinIcon icfg ext  =
cdFile d  =
clGo s i n  =
clampNeg a from  =
clampSel i n  =
classifyBody cwd hidden  =
classifyNow cwd hidden  =
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
colorsFile d  =
colsOf sz  =
configFile d  =
confirm prompt rows  =
confirmKey prompt rows  =
confirmYes k  =
consLine s i n j  =
consWord s i n j  =
copyToClip path  =
count p xs  =
countKey cwd sel marked prog hidden rows cols raw acc k  =
countLines s  =
countLoop cwd sel marked prog hidden rows cols raw acc  =
countPrompt rows acc  =
csi s  =
digitStart k  =
dirBefore s k  =
dirColor lsc  =
dirIcon icfg  =
dirName s  =
dispatchWait cwd sel marked prog hidden rows cols raw poff key  =
doAttr cwd sel marked prog hidden rows  =
doBulk cwd sel marked prog hidden rows  =
doChmod cwd sel marked prog hidden rows  =
doCopyPath cwd sel marked prog hidden rows cols raw  =
doDiskUsage cwd sel marked prog hidden rows cols raw  =
doFilter cwd sel marked prog hidden rows  =
doGoDir cwd sel marked prog hidden rows  =
doHelp cwd sel marked prog hidden rows  =
doJumpMark cwd sel marked prog hidden rows  =
doMkdir cwd sel marked prog hidden rows  =
doMkfile cwd sel marked prog hidden rows  =
doPaste cwd sel marked prog hidden rows  =
doPasteRun cwd sel marked prog hidden rows  =
doRename cwd sel marked prog hidden rows  =
doRestore cwd sel marked prog hidden rows  =
doRunList cwd sel marked prog hidden rows cols raw items  =
doSearch cwd sel marked prog hidden rows cols raw  =
doSetMark cwd sel marked prog hidden rows  =
doShell cwd sel marked prog hidden rows  =
doSort cwd sel marked prog hidden rows  =
doTabClose cwd sel marked prog hidden rows  =
doTabNew cwd sel marked prog hidden rows  =
doTabNext cwd sel marked prog hidden rows  =
doTabPrev cwd sel marked prog hidden rows  =
doUserCmd cwd sel marked prog hidden rows cols raw cmd  =
doUserCmdTty cwd sel marked prog hidden rows raw cmd  =
docExts  =
drawLines xs r px pw maxRow  =
drawLinesAnsi xs r px pw maxRow  =
drawPreview path px pw ph mime poff  =
drawRows lsc icfg win tys row sel marked cwd listW prev  =
drawSep col mx  =
dropFirstLine s  =
dropLast s  =
duOf path  =
dup s  =
dupOrAcc comp acc  =
editorCmd d  =
elemBy$String x xs  =
endSearch cwd marked prog hidden rows cols raw acc msel  =
enqueueItems new old  =
entriesRaw cwd hidden  =
entryColor lsc ty raw  =
entryIcon icfg ty raw  =
envOr name dflt  =
eq$String x y  =
errDetail d  =
errFile d  =
errRedir  =
esc  =
escEnd s i n  =
escFinal s i n  =
exColor lsc  =
exIcon icfg  =
expandDir cwd nm  =
extOf s  =
fallbackTy y  =
favOrIgnore cwd sel marked prog hidden rows key  =
fileColor lsc ext  =
fileIcon icfg ext  =
filter$$neStr _cap0 xs  =
filter$$nonEmpty xs  =
filterFile d  =
findChar c s i n  =
firstLine s  =
firstPrefix xs q  =
firstWord s  =
fit s w  =
flashFail msg rows  =
flashInfo msg rows  =
forceWrite d s  =
frameTys cwd start mx  =
frameWait cwd sel marked prog hidden rows cols raw poff  =
fromMaybe d m  =
fullWait cwd sel marked prog hidden rows cols raw poff  =
goHome marked prog hidden rows  =
goPrev marked prog hidden rows  =
gotoDir cwd nm sel marked prog hidden rows  =
gotoTo cwd sel marked prog hidden rows dest  =
grow s need  =
hasImgTool d  =
hasInfix q s  =
hasPrefix p s  =
hasSuffix q s  =
helpText  =
homeClear  =
icatCmd path cols rows  =
iconForExt e  =
iconsFile d  =
iconsOf d  =
imageDelayMs  =
imageExts  =
imgClearSeq  =
indexOfName xs target i dflt  =
infixGo q s i lim  =
infoLink info  =
infoMime info  =
infoMtime info  =
infoSize info  =
infoTabs info  =
ippGo xs acc  =
isArchiveMime m  =
isDigit c  =
isDigitK k  =
isDirPath p  =
isExecPath p  =
isPctS cmd i  =
isProperPrefix km acc  =
isSpace c  =
isTextPath p  =
joinPaths cwd xs  =
keymapFile d  =
kittenRenderSrc pw ph px py  =
kmKey line  =
kmVal line  =
laGo xs k  =
lam$0 [env ]x  =
lastIndex c s i best  =
lastqFile d  =
le$Int x y  =
length xs  =
lineAt s idx  =
lineOffset s idx  =
lines s  =
linesFrom s i n  =
linkSeg info  =
listFrame cwd sel marked prog rows raw cols poff  =
listStatus cwd total sel marked prog rows  =
listWidth cols  =
lnColor lsc  =
lnIcon icfg  =
loGo s idx i n  =
lookupAction content k  =
loop cwd sel marked prog hidden rows cols raw  =
loopAt cwd sel marked prog hidden rows cols raw poff  =
loopSel cwd child marked prog hidden rows raw  =
lowerChar c  =
lsCmd cwd hidden  =
lsColors d  =
lscEnd s j n  =
lscScan s pat i n plen  =
lscTake s j n  =
lscVal lsc key  =
main  =
map$$rdtCode xs  =
map$$rdtRawName xs  =
markChar marked full  =
markCount m  =
markInfo marked prog  =
markPath letter  =
markSeg marked prog  =
markSet letter cwd  =
markSetCmd letter cwd  =
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
nlIdx s  =
nlScan s i  =
nonEmpty s  =
not b  =
okOr code label rows  =
okOrErr code label rows  =
okToClobber dest src rows  =
onTty d  =
open cwd sel marked prog hidden rows raw  =
openFile cwd sel marked prog hidden rows  =
openOther cwd sel marked prog hidden rows  =
openText cwd sel marked prog hidden rows  =
orColor lsc  =
orIcon icfg  =
paint c s  =
paneW cols  =
paneX cols  =
parentDir s  =
pasteConfirmed cwd marked prog rows  =
pasteIfYes cwd sel marked prog hidden rows yes  =
pathMissing p  =
pdfCmd path cols rows  =
pdfThumbVar  =
pendingFile d  =
pick i xs  =
pickRenderer d  =
pixHeader label path mime px pw ph  =
pollKey cwd sel marked prog hidden rows cols raw poff  =
popItem d  =
posStr sel total  =
prefetch cwd sel rows raw cols  =
prefetchBodyKitten  =
prefetchBodySixel pwc phc  =
prefetchCmd cwd sel rows raw cols  =
prevOrBottom raw q from a  =
previewImage cwd sel rows raw cols mime  =
previewOn cols  =
previewPix path cols rows mime  =
previewSeg cwd sel raw cols mx prev mime poff  =
progVerb prog  =
qlGo xs  =
queryCell d  =
quit cwd  =
quoteLines m  =
rdtApp xs ys  =
rdtCode ln  =
rdtEntries rdt hidden fq  =
rdtIsDir ln  =
rdtKeep hidden fq xs  =
rdtName ln  =
rdtPartGo xs ds fs  =
rdtRaw rdt hidden fq  =
rdtRawName ln  =
rdtRev xs acc  =
rdtTypes cwd rdt hidden fq  =
rdtVisible hidden fq ln  =
readFileTrim path  =
readInt s  =
readIntGo s i acc  =
readLastQ d  =
readMainKey dummy  =
readMainKeyTO ms  =
reloop cwd sel marked prog hidden rows  =
reloopDispatch cwd sel marked prog hidden rows sortf  =
reloopInto cwd child marked prog hidden rows  =
reloopIntoDispatch cwd child marked prog hidden rows sortf  =
reloopIntoNative cwd child marked prog hidden rows  =
reloopIntoShell cwd child marked prog hidden rows  =
reloopNative cwd sel marked prog hidden rows  =
reloopShell cwd sel marked prog hidden rows  =
renameMaybe cwd hidden sel nm rows  =
render cwd sel marked prog rows raw cols info poff  =
renderSrc cols rows  =
resetSeq  =
resizeCheck cwd sel marked prog hidden rows cols raw poff  =
resolveSeq km acc  =
restoreCmd d  =
rootIfEmpty d  =
rowCell icfg ty raw mark name listW prev  =
rowFor lsc icfg raw ty i sel marked cwd listW prev  =
runBuiltin cwd sel marked prog hidden rows cols raw k  =
runItem cwd sel marked prog hidden rows cols raw item  =
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
seqKey key  =
seqNext km acc k  =
seqResolve km s  =
seqStarts b acc  =
settleKey cwd sel marked prog hidden rows cols raw poff key  =
settleStart cwd sel marked prog hidden rows cols raw poff  =
settledFull cwd sel marked prog hidden rows cols raw poff  =
setupSeq  =
shEsc s i n  =
shQuote s  =
sixelDecode pwc phc  =
sixelRenderSrc px pwc phc  =
sizedCell plain listW prev  =
sortFile d  =
spGo cmd rep i  =
spaces n  =
splitMin  =
startDir a  =
startDirRaw a  =
statusLine cwd total sel marked prog rows info  =
step cwd sel marked prog hidden rows cols raw key  =
stepAt cwd sel marked prog hidden rows cols raw poff key  =
stepCanon cwd sel marked prog hidden rows cols raw poff key  =
stripSlash s  =
substPct cmd rep  =
syncTab cwd  =
syncTabCmd cwd  =
t2n s i  =
tabBarCmd  =
tabCloseCmd d  =
tabGoCmd delta  =
tabIdx s  =
tabNewCmd cwd  =
tabScan s i  =
tabSeg info  =
tabSwitch cwd sel marked prog hidden rows delta  =
tabToNl s  =
tabiFile d  =
tabsFile d  =
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
typesFile d  =
unlines xs  =
userCmd cwd raw sel cmd  =
userCmdTty cwd raw sel cmd  =
videoCmd path cols rows  =
videoExts  =
videoThumbVar  =
viewStart sel total mx  =
warmLoop paths body  =
winPaths cwd sel raw  =
windowGo cwd raw i hi acc  =
windowLines s start count  =
windowPaths cwd raw lo hi  =
wlGo s i n left  =
wordEnd s i n  =
words s  =
wordsFrom s i n  =
wordsStep s i n  =
workMsg prog n rows  =
workShow prog n rows  =
wrapSel i n  =
writeCaps d  =
writeCapsCmd  =
