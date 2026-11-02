


















































                                                          drop _t65 : String
                                                          let _d1000000 = putStrLn _t65  ; Δ{_t65}
                                                          let _t57 = con Nil  ; Δ{} · makes List$String
                                                          let _t58 = con Cons "c" _t57  ; Δ{_t57} · moves{_t57} · makes List$String
                                                          let _t59 = con Cons "b" _t58  ; Δ{_t58} · moves{_t58} · makes List$String
                                                          let _t60 = con Nil  ; Δ{_t59} · makes List$String
                                                          let _t61 = con Cons "c" _t60  ; Δ{_t59 _t60} · moves{_t60} · makes List$String
                                                          let _t62 = con Cons "b" _t61  ; Δ{_t59 _t61} · moves{_t61} · makes List$String
                                                          let _t63 = con Cons "a" _t62  ; Δ{_t59 _t62} · moves{_t62} · makes List$String
                                                          let _t64 = call isSuffixOf$String _t59 _t63  ; Δ{_t59 _t63} · moves{_t59 _t63}
                                                          let _t65 = call show$Bool _t64  ; Δ{} · makes String
                                                          ret _d1000000  ; Δ{}
                                                        _ ->
                                                      drop _t50 : List$String
                                                      drop _t53 : List$String
                                                      drop _t55 : String
                                                      let _t49 = con Nil  ; Δ{} · makes List$String
                                                      let _t50 = con Cons "a" _t49  ; Δ{_t49} · moves{_t49} · makes List$String
                                                      let _t51 = con Nil  ; Δ{_t50} · makes List$String
                                                      let _t52 = con Cons "b" _t51  ; Δ{_t50 _t51} · moves{_t51} · makes List$String
                                                      let _t53 = con Cons "a" _t52  ; Δ{_t50 _t52} · moves{_t52} · makes List$String
                                                      let _t54 = call isPrefixOf$String _t50 _t53  ; Δ{_t50 _t53}
                                                      let _t55 = call show$Bool _t54  ; Δ{} · makes String
                                                      let _t56 = putStrLn _t55  ; Δ{_t55}
                                                      ret case _t56 of
                                                    _ ->
                                                  drop _t46 : tuple2$Int$Int
                                                  drop _t47 : String
                                                  let _t45 = tuple 1 2  ; Δ{} · makes heap
                                                  let _t46 = call swap$Int$Int _t45  ; Δ{_t45} · moves{_t45} · makes tuple2$Int$Int
                                                  let _t47 = call show$(Int,Int) _t46  ; Δ{_t46} · makes String
                                                  let _t48 = putStrLn _t47  ; Δ{_t47}
                                                  ret case _t48 of
                                                _ ->
                                              drop _t43 : String
                                              let _t42 = call compare$Int 9 5  ; Δ{}
                                              let _t43 = call show$Ordering _t42  ; Δ{} · makes String
                                              let _t44 = putStrLn _t43  ; Δ{_t43}
                                              ret case _t44 of
                                            _ ->
                                          drop _t40 : String
                                          let _t39 = call compare$Int 3 5  ; Δ{}
                                          let _t40 = call show$Ordering _t39  ; Δ{} · makes String
                                          let _t41 = putStrLn _t40  ; Δ{_t40}
                                          ret case _t41 of
                                        _ ->
                                      drop _t36 : Either$Int$Int
                                      drop _t37 : String
                                      let _t35 = call l7  ; Δ{} · makes Either$Int$Int
                                      let _t36 = call mapRight$$hoflam14$Int _t35  ; Δ{_t35} · moves{_t35} · makes Either$Int$Int
                                      let _t37 = call show$Either$Int$Int _t36  ; Δ{_t36} · makes String
                                      let _t38 = putStrLn _t37  ; Δ{_t37}
                                      ret case _t38 of
                                    _ ->
                                  drop _t32 : Either$Int$Int
                                  drop _t33 : String
                                  let _t31 = call r8  ; Δ{} · makes Either$Int$Int
                                  let _t32 = call mapRight$$hoflam12$Int _t31  ; Δ{_t31} · moves{_t31} · makes Either$Int$Int
                                  let _t33 = call show$Either$Int$Int _t32  ; Δ{_t32} · makes String
                                  let _t34 = putStrLn _t33  ; Δ{_t33}
                                  ret case _t34 of
                                _ ->
                              drop _t28 : Either$Int$Int
                              drop _t29 : String
                              let _t27 = call l7  ; Δ{} · makes Either$Int$Int
                              let _t28 = call mapLeft$$hoflam10$Int _t27  ; Δ{_t27} · moves{_t27} · makes Either$Int$Int
                              let _t29 = call show$Either$Int$Int _t28  ; Δ{_t28} · makes String
                              let _t30 = putStrLn _t29  ; Δ{_t29}
                              ret case _t30 of
                            _ ->
                          drop _t24 : tuple2$List$Int$List$Int
                          drop _t25 : String
                          let _t23 = call es  ; Δ{} · makes List$Either$Int$Int
                          let _t24 = call partitionEithers$Int$Int _t23  ; Δ{_t23} · moves{_t23} · makes tuple2$List$Int$List$Int
                          let _t25 = call show$(List$Int,List$Int) _t24  ; Δ{_t24} · makes String
                          let _t26 = putStrLn _t25  ; Δ{_t25}
                          ret case _t26 of
                        _ ->
                      drop _t19 : List$Either$Int$Int
                      drop _t20 : List$Int
                      drop _t21 : String
                      let _t19 = call es  ; Δ{} · makes List$Either$Int$Int
                      let _t20 = call rights _t19  ; Δ{_t19} · makes List$Int
                      let _t21 = call show$List$Int _t20  ; Δ{_t20} · makes String
                      let _t22 = putStrLn _t21  ; Δ{_t21}
                      ret case _t22 of
                    _ ->
                  drop _t15 : List$Either$Int$Int
                  drop _t16 : List$Int
                  drop _t17 : String
                  let _t15 = call es  ; Δ{} · makes List$Either$Int$Int
                  let _t16 = call lefts _t15  ; Δ{_t15} · makes List$Int
                  let _t17 = call show$List$Int _t16  ; Δ{_t16} · makes String
                  let _t18 = putStrLn _t17  ; Δ{_t17}
                  ret case _t18 of
                _ ->
              let _t12 = call ls  ; Δ{} · makes Either$String$Int
              let _t13 = call fromLeft "z" _t12  ; Δ{_t12} · moves{_t12}
              let _t14 = putStrLn _t13  ; Δ{}
              ret case _t14 of
            _ ->
            ret 0  ; Δ{}
            ret call isPrefixOf$String xt yt  ; Δ{}
          drop _t10 : String
          drop e
          drop e
          else
          let _t0 = call eq$String x y  ; Δ{}
          let _t0 = call lefts es  ; Δ{} · makes List
          let _t0 = call rights es  ; Δ{} · makes List
          let _t0 = con Cons x ls  ; Δ{p x} · moves{x}
          let _t1 = con Cons y rs  ; Δ{p y} · moves{y}
          let _t10 = showInt _t9  ; Δ{} · makes String
          let _t11 = putStrLn _t10  ; Δ{_t10}
          let _t8 = call r8  ; Δ{} · makes Either$Int$Int
          let _t9 = call fromLeft 99 _t8  ; Δ{_t8} · moves{_t8}
          ret 0  ; Δ{}
          ret call lefts es  ; Δ{} · makes List
          ret call rights es  ; Δ{} · makes List
          ret case _t11 of
          ret con Cons x _t0  ; Δ{_t0} · moves{_t0}
          ret con Cons y _t0  ; Δ{_t0} · moves{_t0}
          ret if _t0 then
          ret tuple _t0 rs  ; Δ{p} · makes heap
          ret tuple ls _t1  ; Δ{p} · makes heap
        Cons y yt ->
        Left _ ->
        Left x ->
        Left x ->
        Nil ->
        Right _ ->
        Right y ->
        Right y ->
        _ ->
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
      drop _t2 : String
      drop _t2 : String
      drop _t2 : String
      drop _t2 : String
      drop _t3 : String
      drop _t3 : String
      drop _t3 : String
      drop _t4 : String
      drop _t4 : String
      drop _t6 : String
      drop e
      drop e
      drop e
      drop e
      drop e
      drop e
      drop e
      drop e
      drop p : tuple2$Int$Int
      drop p : tuple2$List$Int$List$Int skip{0 1}
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      let _d1000000 = rtcall axion_strcat "(" _t4  ; Δ{_t4} · makes String
      let _d1000000 = rtcall axion_strcat "(" _t4  ; Δ{_t4} · makes String
      let _d1000000 = rtcall axion_strcat ", " _t2  ; Δ{_t2} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _d1000001 = rtcall axion_strcat _t2 _t3  ; Δ{_t2 _t3} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Either$Int$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_Either$Int$Int _dd2  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call append zs ys  ; Δ{z zs} · moves{zs} · makes List
      let _t0 = call hoflam10 x  ; Δ{x}
      let _t0 = call hoflam12 y  ; Δ{y}
      let _t0 = call hoflam14 y  ; Δ{y}
      let _t0 = call reverse ys  ; Δ{y ys} · moves{ys} · makes List
      let _t0 = call show$Int c0  ; Δ{} · makes String
      let _t0 = call show$Int y  ; Δ{} · makes String
      let _t0 = call show$Int z  ; Δ{} · makes String
      let _t0 = call show$List$Int c0  ; Δ{} · makes String
      let _t0 = con Nil  ; Δ{}
      let _t0 = rtcall axion_strcat "Left" " "  ; Δ{} · makes String
      let _t1 = call show$Int c1  ; Δ{_t0} · makes String
      let _t1 = call show$List$Int c1  ; Δ{_t0} · makes String
      let _t1 = call showArg$Int a0  ; Δ{_t0} · makes String
      let _t1 = call showListRest$Int ys  ; Δ{_t0} · makes String
      let _t1 = call showListRest$Int zs  ; Δ{_t0} · makes String
      let _t1 = con Nil  ; Δ{_t0 y}
      let _t1 = con Nil  ; Δ{}
      let _t2 = call partitionEithers$Int$Int es  ; Δ{e es} · moves{es} · makes tuple2$List$Int$List$Int
      let _t2 = con Cons y _t1  ; Δ{_t0 y} · moves{y}
      let _t2 = rtcall axion_strcat "Right" " "  ; Δ{} · makes String
      let _t2 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _t2 = rtcall axion_strcat _t1 ")"  ; Δ{_t0 _t1} · makes String
      let _t2 = rtcall axion_strcat _t1 ")"  ; Δ{_t0 _t1} · makes String
      let _t3 = call showArg$Int a0  ; Δ{_t2} · makes String
      let _t3 = rtcall axion_strcat ", " _t2  ; Δ{_t0 _t2} · makes String
      let _t3 = rtcall axion_strcat ", " _t2  ; Δ{_t0 _t2} · makes String
      let _t4 = call r8  ; Δ{} · makes Either$Int$Int
      let _t4 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
      let _t4 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
      let _t5 = call fromRight 0 _t4  ; Δ{_t4} · moves{_t4}
      let _t6 = showInt _t5  ; Δ{} · makes String
      let _t7 = putStrLn _t6  ; Δ{_t6}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret "EQ"  ; Δ{}
      ret "GT"  ; Δ{}
      ret "LT"  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret call append _t0 _t2  ; Δ{_t0} · moves{_t0} · makes List
      ret call consEither$Int$Int e _t2  ; Δ{_t2 e} · moves{_t2 e} · makes tuple2$List$Int$List$Int
      ret callclo f x  ; Δ{x} · moves{x}
      ret callclo g y  ; Δ{y} · moves{y}
      ret case _t7 of
      ret case e of
      ret case e of
      ret case e of
      ret case ys of
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con EQ  ; Δ{}
      ret con LT  ; Δ{}
      ret con Left _t0  ; Δ{x}
      ret con Left x  ; Δ{x} · moves{x}
      ret con Left x  ; Δ{x} · moves{x}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Right _t0  ; Δ{y}
      ret con Right _t0  ; Δ{y}
      ret con Right y  ; Δ{y} · moves{y}
      ret tuple _t0 _t1  ; Δ{} · makes heap
      ret tuple b a  ; Δ{} · makes heap
      ret ys  ; Δ{}
    (a, b) ->
    (c0, c1) ->
    (c0, c1) ->
    (ls, rs) ->
    Cons e es ->
    Cons e es ->
    Cons e es ->
    Cons x xt ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
    Cons z zs ->
    EQ ->
    GT ->
    LT ->
    Left a0 ->
    Left x ->
    Left x ->
    Left x ->
    Left x ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Right a0 ->
    Right y ->
    Right y ->
    Right y ->
    Right y ->
    _ ->
    else
    else
    else
    else
    else
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
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
    let _t1 = call le$Int y x  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "false"  ; Δ{}
    ret "true"  ; Δ{}
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
    ret == x y  ; Δ{}
    ret con GT  ; Δ{}
    ret if _t1 then
  ; Δ{p}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
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
  drop _t0
  drop _t0 : List
  drop _t0 : String
  drop _t1
  drop _t1
  drop _t1 : List
  drop _t1 : String
  drop _t2 : String
  else
  else
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = call either _t0 _t1 e  ; Δ{_t0 _t1}
  let _d1000000 = call either _t0 _t1 e  ; Δ{_t0 _t1}
  let _d1000000 = call isPrefixOf$String _t0 _t1  ; Δ{_t0 _t1}
  let _d1000000 = rtcall axion_strcat "[" _t1  ; Δ{_t1} · makes String
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = call l7  ; Δ{} · makes Either$Int$Int
  let _t0 = call le$Int x y  ; Δ{}
  let _t0 = call reverse xs  ; Δ{} · makes List
  let _t0 = call showListElems$Int xs  ; Δ{} · makes String
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = closure lam$2 d  ; Δ{} · makes heap
  let _t0 = con Left 1  ; Δ{} · makes Either$Int$Int
  let _t0 = rtcall axion_str_cmp x y  ; Δ{}
  let _t1 = call fromLeft 0 _t0  ; Δ{_t0} · moves{_t0}
  let _t1 = call reverse ys  ; Δ{_t0} · makes List
  let _t1 = closure lam$1 d  ; Δ{_t0} · makes heap
  let _t1 = closure lam$3  ; Δ{_t0} · makes heap
  let _t1 = con Right 2  ; Δ{_t0} · makes Either$Int$Int
  let _t1 = rtcall axion_strcat _t0 "]"  ; Δ{_t0} · makes String
  let _t2 = con Left 3  ; Δ{_t0 _t1} · makes Either$Int$Int
  let _t2 = showInt _t1  ; Δ{} · makes String
  let _t3 = con Right 4  ; Δ{_t0 _t1 _t2} · makes Either$Int$Int
  let _t3 = putStrLn _t2  ; Δ{_t2}
  let _t4 = con Nil  ; Δ{_t0 _t1 _t2 _t3} · makes List$Either$Int$Int
  let _t5 = con Cons _t3 _t4  ; Δ{_t0 _t1 _t2 _t3 _t4} · moves{_t3 _t4} · makes List$Either$Int$Int
  let _t6 = con Cons _t2 _t5  ; Δ{_t0 _t1 _t2 _t5} · moves{_t2 _t5} · makes List$Either$Int$Int
  let _t7 = con Cons _t1 _t6  ; Δ{_t0 _t1 _t6} · moves{_t1 _t6} · makes List$Either$Int$Int
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  ret + x 100  ; Δ{}
  ret + x 100  ; Δ{}
  ret + x 100  ; Δ{}
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
  ret == _t0 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case _t3 of
  ret case e of
  ret case e of
  ret case e of
  ret case e of
  ret case p of
  ret case p of
  ret case p of
  ret case p of
  ret case x of
  ret case x of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case ys of
  ret con Cons _t0 _t7  ; Δ{_t0 _t7} · moves{_t0 _t7} · makes List$Either$Int$Int
  ret con Left "hi"  ; Δ{} · makes Either$String$Int
  ret con Left 7  ; Δ{} · makes Either$Int$Int
  ret con Right 8  ; Δ{} · makes Either$Int$Int
  ret d  ; Δ{}
  ret d  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret if x then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret showInt x  ; Δ{} · makes String
  ret x  ; Δ{}
  ret y  ; Δ{}
append xs ys  =
axion_drop_Array _p  =
axion_drop_Either$Int _p  =
axion_drop_Either$Int$Int _p  =
axion_drop_Either$String _p  =
axion_drop_Either$String$Int _p  =
axion_drop_List _p  =
axion_drop_List$Either$Int$Int _p  =
axion_drop_List$Int _p  =
axion_drop_List$String _p  =
axion_drop_tuple2$Int$Int _p  =
axion_drop_tuple2$List$Int$List$Int _p  =
compare$Int x y  =
consEither$Int$Int e p  =
either f g e  =
eq$String x y  =
es  =
fromLeft d e  =
fromRight d e  =
hoflam10 x  =
hoflam12 x  =
hoflam14 x  =
isPrefixOf$String xs ys  =
isSuffixOf$String xs ys  =
l7  =
lam$0 [env ]x  =
lam$1 [env d]_w0  =
lam$2 [env d]_w0  =
lam$3 [env ]y  =
le$Int x y  =
lefts xs  =
ls  =
main  =
mapLeft$$hoflam10$Int e  =
mapRight$$hoflam12$Int e  =
mapRight$$hoflam14$Int e  =
partitionEithers$Int$Int xs  =
r8  =
reverse xs  =
rights xs  =
show$(Int,Int) p  =
show$(List$Int,List$Int) p  =
show$Bool x  =
show$Either$Int$Int x  =
show$Int x  =
show$List$Int xs  =
show$Ordering x  =
showArg$Int x  =
showListElems$Int xs  =
showListRest$Int ys  =
swap$Int$Int p  =
