



































































                                                              drop _t85 : Closure
                                                              drop _t88 : Closure
                                                              drop _t91 : String
                                                              let _d1000000 = putStrLn _t91  ; Δ{_t91}
                                                              let _t84 = 1  ; Δ{}
                                                              let _t85 = call pick$$hoflam18$$hoflam17 _t84  ; Δ{} · makes Closure
                                                              let _t86 = callclo _t85 5  ; Δ{_t85}
                                                              let _t87 = 0  ; Δ{}
                                                              let _t88 = call pick$$hoflam18$$hoflam17 _t87  ; Δ{} · makes Closure
                                                              let _t89 = callclo _t88 5  ; Δ{_t88}
                                                              let _t90 = + _t86 _t89  ; Δ{}
                                                              let _t91 = call show$Int _t90  ; Δ{} · makes String
                                                              ret _d1000000  ; Δ{}
                                                            _ ->
                                                          drop _t82 : String
                                                          drop h : Closure
                                                          let _t78 = closure lam$15 owning  ; Δ{} · makes Closure
                                                          let _t79 = callclo h 1  ; Δ{h}
                                                          let _t80 = callclo h 2  ; Δ{h}
                                                          let _t81 = + _t79 _t80  ; Δ{}
                                                          let _t82 = call show$Int _t81  ; Δ{} · makes String
                                                          let _t83 = putStrLn _t82  ; Δ{_t82}
                                                          let h = call getF jm  ; Δ{jm} · moves{jm} · makes Closure
                                                          let jm = con Just _t78  ; Δ{_t78} · moves{_t78} · makes Maybe$Closure
                                                          ret case _t83 of
                                                        _ ->
                                                      drop _t69 : tuple2$Closure$Int
                                                      drop _t71 : String
                                                      drop _t73
                                                      drop _t74 : Closure
                                                      drop _t76 : String
                                                      let _d1000001 = putStrLn _t71  ; Δ{_t69 _t71}
                                                      let _t70 = callclo g k$1  ; Δ{_t69}
                                                      let _t71 = call show$Int _t70  ; Δ{_t69} · makes String
                                                      let _t73 = closure lam$14  ; Δ{} · makes Closure
                                                      let _t74 = call idG$Closure _t73  ; Δ{_t73} · makes Closure
                                                      let _t75 = callclo _t74 2  ; Δ{_t74}
                                                      let _t76 = call show$Int _t75  ; Δ{} · makes String
                                                      let _t77 = putStrLn _t76  ; Δ{_t76}
                                                      ret _d1000001  ; Δ{}
                                                      ret case _t77 of
                                                    (g, k$1) ->
                                                    _ ->
                                                  let _t68 = closure lam$13  ; Δ{} · makes Closure
                                                  let _t69 = call pairWith _t68 9  ; Δ{_t68} · moves{_t68} · makes tuple2$Closure$Int
                                                  let _t72 = case _t69 of
                                                  ret case _t72 of
                                                _ ->
                                              drop _t63
                                              drop _t64 : List$Closure
                                              drop _t66 : String
                                              let _t63 = closure lam$12  ; Δ{} · makes Closure
                                              let _t64 = call dupL$Closure _t63  ; Δ{_t63} · makes List$Closure
                                              let _t65 = call callAll _t64 1  ; Δ{_t64}
                                              let _t66 = call show$Int _t65  ; Δ{} · makes String
                                              let _t67 = putStrLn _t66  ; Δ{_t66}
                                              ret case _t67 of
                                            _ ->
                                          drop _t61 : String
                                          drop gs : List$Closure
                                          let _t60 = call firstOf gs  ; Δ{gs}
                                          let _t61 = call show$Int _t60  ; Δ{} · makes String
                                          let _t62 = putStrLn _t61  ; Δ{_t61}
                                          ret case _t62 of
                                        _ ->
                                      drop _t58 : String
                                      let _t57 = call firstStored gs  ; Δ{gs}
                                      let _t58 = call show$Int _t57  ; Δ{gs} · makes String
                                      let _t59 = putStrLn _t58  ; Δ{_t58 gs}
                                      ret case _t59 of
                                    _ ->
                                  drop _t55 : String
                                  drop s : String
                                  let $clocopy2 = rtcall axion_strcat s ""  ; Δ{s} · makes String
                                  let _t50 = closure lam$10 $clocopy2 owning  ; Δ{$clocopy2} · moves{$clocopy2} · makes Closure
                                  let _t51 = closure lam$11 owning  ; Δ{_t50} · makes Closure
                                  let _t52 = con Nil  ; Δ{_t50 _t51} · makes List$Closure
                                  let _t53 = con Cons _t51 _t52  ; Δ{_t50 _t51 _t52} · moves{_t51 _t52} · makes List$Closure
                                  let _t54 = call firstTwice gs  ; Δ{gs}
                                  let _t55 = call show$Int _t54  ; Δ{gs} · makes String
                                  let _t56 = putStrLn _t55  ; Δ{_t55 gs}
                                  let gs = con Cons _t50 _t53  ; Δ{_t50 _t53} · moves{_t50 _t53} · makes List$Closure
                                  ret case _t56 of
                                _ ->
                              drop _t48 : String
                              drop j : Maybe$Closure
                              drop kk : Maybe$Closure
                              let $clocopy3 = rtcall axion_strcat s ""  ; Δ{s} · makes String
                              let _t43 = closure lam$9 $clocopy3 owning  ; Δ{$clocopy3 s} · moves{$clocopy3} · makes Closure
                              let _t44 = con Nothing  ; Δ{j s} · makes Maybe$Closure
                              let _t45 = call call1 kk 1  ; Δ{j kk s}
                              let _t46 = call call1 j 2  ; Δ{j s}
                              let _t47 = + _t45 _t46  ; Δ{s}
                              let _t48 = call show$Int _t47  ; Δ{s} · makes String
                              let _t49 = putStrLn _t48  ; Δ{_t48 s}
                              let j = con Just _t43  ; Δ{_t43 s} · moves{_t43} · makes Maybe$Closure
                              let kk = call keepOr j _t44  ; Δ{_t44 j s} · moves{_t44} · makes Maybe$Closure
                              let s = call show$Int 4321  ; Δ{} · makes String
                              ret case _t49 of
                            _ ->
                          drop _t39 : List$String
                          drop _t41 : String
                          drop ls : List$Closure
                          let _t37 = con Nil  ; Δ{} · makes List$String
                          let _t38 = con Cons "cde" _t37  ; Δ{_t37} · moves{_t37} · makes List$String
                          let _t39 = con Cons "ab" _t38  ; Δ{_t38} · moves{_t38} · makes List$String
                          let _t40 = call callAll ls 1  ; Δ{ls}
                          let _t41 = call show$Int _t40  ; Δ{} · makes String
                          let _t42 = putStrLn _t41  ; Δ{_t41}
                          let ls = call labels _t39  ; Δ{_t39} · makes List$Closure
                          ret case _t42 of
                        _ ->
                      drop _t24 : tuple2$Closure$Int
                      drop _t26 : String
                      drop _t31 : List$Int
                      drop _t35 : String
                      drop fs : List$Closure
                      let _d1000002 = putStrLn _t26  ; Δ{_t24 _t26}
                      let _t25 = callclo f k  ; Δ{_t24}
                      let _t26 = call show$Int _t25  ; Δ{_t24} · makes String
                      let _t28 = con Nil  ; Δ{} · makes List$Int
                      let _t29 = con Cons 3 _t28  ; Δ{_t28} · moves{_t28} · makes List$Int
                      let _t30 = con Cons 2 _t29  ; Δ{_t29} · moves{_t29} · makes List$Int
                      let _t31 = con Cons 1 _t30  ; Δ{_t30} · moves{_t30} · makes List$Int
                      let _t32 = call callAll fs 10  ; Δ{fs}
                      let _t33 = call callAll fs 0  ; Δ{fs}
                      let _t34 = + _t32 _t33  ; Δ{}
                      let _t35 = call show$Int _t34  ; Δ{} · makes String
                      let _t36 = putStrLn _t35  ; Δ{_t35}
                      let fs = call adders _t31  ; Δ{_t31} · makes List$Closure
                      ret _d1000002  ; Δ{}
                      ret case _t36 of
                    (f, k) ->
                    _ ->
                  let _t24 = call pairUp 3  ; Δ{} · makes tuple2$Closure$Int
                  let _t27 = case _t24 of
                  ret case _t27 of
                _ ->
              drop _t20 : Maybe$Closure
              drop _t22 : String
              let _t20 = call mkJ 123  ; Δ{} · makes Maybe$Closure
              let _t21 = call call1 _t20 1  ; Δ{_t20}
              let _t22 = call show$Int _t21  ; Δ{} · makes String
              let _t23 = putStrLn _t22  ; Δ{_t22}
              ret case _t23 of
            _ ->
          drop _t0 : tuple2$Closure$Closure
          drop _t16 : List$Closure
          drop _t18 : String
          let _d1000000 = + _t1 _t2  ; Δ{_t0}
          let _t1 = callclo g 1  ; Δ{_t0}
          let _t10 = closure lam$6 owning  ; Δ{} · makes Closure
          let _t11 = closure lam$7 owning  ; Δ{_t10} · makes Closure
          let _t12 = closure lam$8 owning  ; Δ{_t10 _t11} · makes Closure
          let _t13 = con Nil  ; Δ{_t10 _t11 _t12} · makes List$Closure
          let _t14 = con Cons _t12 _t13  ; Δ{_t10 _t11 _t12 _t13} · moves{_t12 _t13} · makes List$Closure
          let _t15 = con Cons _t11 _t14  ; Δ{_t10 _t11 _t14} · moves{_t11 _t14} · makes List$Closure
          let _t16 = con Cons _t10 _t15  ; Δ{_t10 _t15} · moves{_t10 _t15} · makes List$Closure
          let _t17 = call applyAll _t16 10  ; Δ{_t16}
          let _t18 = call show$Int _t17  ; Δ{} · makes String
          let _t19 = putStrLn _t18  ; Δ{_t18}
          let _t2 = callclo h 2  ; Δ{_t0}
          ret _d1000000  ; Δ{}
          ret case _t19 of
        (g, h) ->
        _ ->
      drop _t0 : List$Closure
      drop _t0 : Maybe$Closure
      drop _t8 : String
      drop b : Maybe$Closure
      drop m
      drop m
      drop m : Maybe$Closure
      drop t : String
      let $aliascopy0 = call axion_copy_Maybe$Closure a  ; Δ{} · makes Maybe$Closure
      let $clocopy1 = rtcall axion_strcat t ""  ; Δ{t} · makes String
      let _d1000000 = call call1 _t0 2  ; Δ{_t0}
      let _d1000000 = call callAll _t0 1  ; Δ{_t0}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Closure _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = rtcall axion_closure_drop _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_closure_drop _dd2  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call both f  ; Δ{} · makes tuple2$Closure$Closure
      let _t0 = call store f  ; Δ{} · makes Maybe$Closure
      let _t0 = call twice f  ; Δ{} · makes List$Closure
      let _t0 = callclo f x  ; Δ{}
      let _t0 = callclo f x  ; Δ{}
      let _t0 = closure lam$2 n  ; Δ{} · makes Closure
      let _t0 = closure lam$3 $clocopy1 owning  ; Δ{$clocopy1} · moves{$clocopy1} · makes Closure
      let _t1 = call adders r  ; Δ{_t0} · makes List$Closure
      let _t1 = call callAll r x  ; Δ{}
      let _t1 = call labels r  ; Δ{_t0} · makes List$Closure
      let _t5 = call call1 m 1  ; Δ{m}
      let _t6 = call call1 m 2  ; Δ{m}
      let _t7 = + _t5 _t6  ; Δ{}
      let _t8 = call show$Int _t7  ; Δ{} · makes String
      let _t9 = putStrLn _t8  ; Δ{_t8}
      let m = call store$$hoflamcap0 n  ; Δ{} · makes Maybe$Closure
      let n = 5  ; Δ{}
      let t = rtcall axion_strcat s "!"  ; Δ{} · makes String
      ret $aliascopy0  ; Δ{$aliascopy0} · moves{$aliascopy0}
      ret + _t0 _t1  ; Δ{}
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
      ret _d1000000  ; Δ{}
      ret _d1000000  ; Δ{}
      ret b  ; Δ{}
      ret call applyAll r _t0  ; Δ{}
      ret callclo f x  ; Δ{}
      ret case _t0 of
      ret case _t9 of
      ret closure lam$4  ; Δ{} · makes Closure
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$Closure
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$Closure
      ret con Nil  ; Δ{} · makes List$Closure
      ret con Nil  ; Δ{} · makes List$Closure
      ret f  ; Δ{f} · moves{f}
      ret x  ; Δ{}
    Cons f _ ->
    Cons f _ ->
    Cons f _ ->
    Cons f r ->
    Cons f r ->
    Cons n r ->
    Cons s r ->
    Just f ->
    Just f ->
    Just f ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nothing ->
    Nothing ->
    Nothing ->
    _ ->
    else
    else
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
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
    ret closure lam$17 owning  ; Δ{} · makes Closure
    ret closure lam$18 owning  ; Δ{} · makes Closure
  ; Δ{_t0}
  ; Δ{_t24}
  ; Δ{_t69}
  ; Δ{gs}
  ; Δ{gs}
  ; Δ{s}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _c0 : String
  drop _c0 : String
  drop _c0 : String
  drop _c0 : String
  drop _t0 : String
  drop _t1 : Maybe$Closure
  drop _t3 : String
  drop s : String
  else
  else
  else
  else
  else
  else
  let $aliascopy0 = rtcall axion_closure_copy x  ; Δ{} · makes Closure
  let $clocopy0 = rtcall axion_strcat s ""  ; Δ{s} · makes String
  let $clocp0 = rtcall axion_closure_copy f  ; Δ{_t1} · makes Closure
  let $clocp0 = rtcall axion_closure_copy f  ; Δ{} · makes Closure
  let $clocp0 = rtcall axion_closure_copy f  ; Δ{} · makes Closure
  let $clocp0 = rtcall axion_closure_copy x  ; Δ{} · makes Closure
  let $clocp1 = rtcall axion_closure_copy f  ; Δ{$clocp0} · makes Closure
  let $clocp1 = rtcall axion_closure_copy f  ; Δ{_t0} · makes Closure
  let $clocp1 = rtcall axion_closure_copy x  ; Δ{} · makes Closure
  let _c0 = loadraw _p+24  ; Δ{}
  let _c0 = loadraw _p+24  ; Δ{}
  let _c0 = loadraw _p+24  ; Δ{}
  let _c0 = loadraw _p+24  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = rtcall axion_closure_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_closure_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = rtcall axion_closure_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call show$Int 77  ; Δ{} · makes String
  let _t0 = closure lam$0 $clocopy0 owning  ; Δ{$clocopy0} · moves{$clocopy0} · makes Closure
  let _t0 = closure lam$1 n owning  ; Δ{} · makes Closure
  let _t0 = closure lam$16 _cap0 owning  ; Δ{} · makes Closure
  let _t0 = closure lam$5 owning  ; Δ{} · makes Closure
  let _t0 = con Nil  ; Δ{}
  let _t0 = con Nil  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Closure
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len t  ; Δ{}
  let _t1 = con Cons $clocp1 _t0  ; Δ{$clocp1 _t0} · moves{$clocp1 _t0} · makes List$Closure
  let _t1 = con Cons $clocp1 _t0  ; Δ{$clocp1} · moves{$clocp1}
  let _t1 = con Cons x _t0  ; Δ{}
  let _t1 = con Just _t0  ; Δ{_t0} · moves{_t0} · makes Maybe$Closure
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t2 = call call1 _t1 1  ; Δ{_t1}
  let _t3 = call show$Int _t2  ; Δ{} · makes String
  let _t4 = putStrLn _t3  ; Δ{_t3}
  let s = call show$Int n  ; Δ{} · makes String
  ret $aliascopy0  ; Δ{$aliascopy0} · moves{$aliascopy0}
  ret * z 2  ; Δ{}
  ret * z 2  ; Δ{}
  ret * z 2  ; Δ{}
  ret * z 3  ; Δ{}
  ret * z 5  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret + z 1  ; Δ{}
  ret + z 1  ; Δ{}
  ret + z 1  ; Δ{}
  ret + z _t0  ; Δ{}
  ret + z _t1  ; Δ{}
  ret + z n  ; Δ{}
  ret + z n  ; Δ{}
  ret + z n  ; Δ{}
  ret - z 1  ; Δ{}
  ret - z 3  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call hoflam17 eta$5  ; Δ{}
  ret call hoflam18 eta$3  ; Δ{}
  ret call hoflamcap0 _cap0 eta$1  ; Δ{}
  ret case _t4 of
  ret case a of
  ret case fs of
  ret case fs of
  ret case fs of
  ret case fs of
  ret case fs of
  ret case m of
  ret case m of
  ret case ns of
  ret case ss of
  ret con Cons $clocp0 _t1  ; Δ{$clocp0 _t1} · moves{$clocp0 _t1} · makes List$Closure
  ret con Cons $clocp0 _t1  ; Δ{$clocp0} · moves{$clocp0}
  ret con Cons x _t1  ; Δ{}
  ret con Just $clocp0  ; Δ{$clocp0} · moves{$clocp0} · makes Maybe$Closure
  ret con Just _t0  ; Δ{_t0} · moves{_t0} · makes Maybe$Closure
  ret con Just _t0  ; Δ{_t0} · moves{_t0} · makes Maybe$Closure
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret tuple $clocp0 $clocp1  ; Δ{$clocp0 $clocp1} · moves{$clocp0 $clocp1} · makes heap
  ret tuple _t0 n  ; Δ{_t0} · moves{_t0} · makes heap
  ret tuple x y  ; Δ{} · makes heap
  ret x  ; Δ{}
  ret z  ; Δ{}
adders ns  =
applyAll fs x  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Closure _p  =
axion_drop_List$Int _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$Closure _p  =
axion_drop_clo$lam$0 _p  =
axion_drop_clo$lam$1 _p  =
axion_drop_clo$lam$10 _p  =
axion_drop_clo$lam$11 _p  =
axion_drop_clo$lam$15 _p  =
axion_drop_clo$lam$16 _p  =
axion_drop_clo$lam$17 _p  =
axion_drop_clo$lam$18 _p  =
axion_drop_clo$lam$3 _p  =
axion_drop_clo$lam$5 _p  =
axion_drop_clo$lam$6 _p  =
axion_drop_clo$lam$7 _p  =
axion_drop_clo$lam$8 _p  =
axion_drop_clo$lam$9 _p  =
axion_drop_tuple2$Closure$Closure _p  =
axion_drop_tuple2$Closure$Int _p  =
both f  =
call1 m x  =
callAll fs x  =
dupL x  =
dupL$Closure x  =
firstOf fs  =
firstStored fs  =
firstTwice fs  =
getF m  =
hoflam17 z  =
hoflam18 z  =
hoflamcap0 n z  =
idG x  =
idG$Closure x  =
keepOr a b  =
labels ss  =
lam$0 [env s]z  =
lam$1 [env n]z  =
lam$10 [env s]z  =
lam$11 [env ]z  =
lam$12 [env ]z  =
lam$13 [env ]z  =
lam$14 [env ]z  =
lam$15 [env ]z  =
lam$16 [env _cap0]eta$1  =
lam$17 [env ]eta$3  =
lam$18 [env ]eta$5  =
lam$2 [env n]z  =
lam$3 [env t]z  =
lam$4 [env ]z  =
lam$5 [env ]z  =
lam$6 [env ]z  =
lam$7 [env ]z  =
lam$8 [env ]z  =
lam$9 [env s]z  =
main  =
mkJ n  =
pairUp n  =
pairWith x y  =
pick$$hoflam18$$hoflam17 b  =
show$Int x  =
store f  =
store$$hoflamcap0 _cap0  =
twice f  =
