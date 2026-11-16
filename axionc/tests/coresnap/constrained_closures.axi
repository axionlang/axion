




































































                                              drop _t105 : List$String
                                              drop _t107 : String
                                              let _d1000000 = putStrLn _t107  ; Δ{_t107}
                                              let _t102 = con Nil  ; Δ{} · makes List$String
                                              let _t103 = con Cons "x" _t102  ; Δ{_t102} · moves{_t102} · makes List$String
                                              let _t104 = con Cons "y" _t103  ; Δ{_t103} · moves{_t103} · makes List$String
                                              let _t105 = con Cons "x" _t104  ; Δ{_t104} · moves{_t104} · makes List$String
                                              let _t106 = call countEq$String "x" _t105  ; Δ{_t105}
                                              let _t107 = call show$Int _t106  ; Δ{} · makes String
                                              ret _d1000000  ; Δ{}
                                            _ ->
                                          drop _t100 : String
                                          drop _t97 : List$Integer
                                          drop _t98 : List$Integer
                                          drop _t99 : Integer
                                          let _t100 = rtcall axion_bignum_to_string _t99  ; Δ{_t99} · makes String
                                          let _t101 = putStrLn _t100  ; Δ{_t100}
                                          let _t95 = rtcall axion_bignum_from_i64 5  ; Δ{} · makes Integer
                                          let _t96 = con Nil  ; Δ{_t95} · makes List$Integer
                                          let _t97 = con Cons _t95 _t96  ; Δ{_t95 _t96} · moves{_t95 _t96} · makes List$Integer
                                          let _t98 = call dbls$Integer _t97  ; Δ{_t97} · makes List$Integer
                                          let _t99 = call sumBig _t98  ; Δ{_t98} · makes Integer
                                          ret case _t101 of
                                        _ ->
                                      drop _t90 : List$Int
                                      drop _t91 : List$Int
                                      drop _t93 : String
                                      let _t87 = con Nil  ; Δ{} · makes List$Int
                                      let _t88 = con Cons 3 _t87  ; Δ{_t87} · moves{_t87} · makes List$Int
                                      let _t89 = con Cons 2 _t88  ; Δ{_t88} · moves{_t88} · makes List$Int
                                      let _t90 = con Cons 1 _t89  ; Δ{_t89} · moves{_t89} · makes List$Int
                                      let _t91 = call dbls$Int _t90  ; Δ{_t90} · makes List$Int
                                      let _t92 = call sumI _t91  ; Δ{_t91}
                                      let _t93 = call show$Int _t92  ; Δ{} · makes String
                                      let _t94 = putStrLn _t93  ; Δ{_t93}
                                      ret case _t94 of
                                    _ ->
                                  drop _t79 : List$Int
                                  drop _t83 : List$Int
                                  drop _t85 : String
                                  let _t76 = con Nil  ; Δ{} · makes List$Int
                                  let _t77 = con Cons 3 _t76  ; Δ{_t76} · moves{_t76} · makes List$Int
                                  let _t78 = con Cons 5 _t77  ; Δ{_t77} · moves{_t77} · makes List$Int
                                  let _t79 = con Cons 1 _t78  ; Δ{_t78} · moves{_t78} · makes List$Int
                                  let _t80 = con Nil  ; Δ{_t79} · makes List$Int
                                  let _t81 = con Cons 4 _t80  ; Δ{_t79 _t80} · moves{_t80} · makes List$Int
                                  let _t82 = con Cons 4 _t81  ; Δ{_t79 _t81} · moves{_t81} · makes List$Int
                                  let _t83 = con Cons 2 _t82  ; Δ{_t79 _t82} · moves{_t82} · makes List$Int
                                  let _t84 = call smaller$Int _t79 _t83  ; Δ{_t79 _t83}
                                  let _t85 = call show$Int _t84  ; Δ{} · makes String
                                  let _t86 = putStrLn _t85  ; Δ{_t85}
                                  ret case _t86 of
                                _ ->
                              drop _t67 : P
                              drop _t72 : List$P
                              drop _t74 : String
                              let _t67 = con P 2 9  ; Δ{} · makes P
                              let _t68 = con P 1 5  ; Δ{_t67} · makes P
                              let _t69 = con P 2 5  ; Δ{_t67 _t68} · makes P
                              let _t70 = con Nil  ; Δ{_t67 _t68 _t69} · makes List$P
                              let _t71 = con Cons _t69 _t70  ; Δ{_t67 _t68 _t69 _t70} · moves{_t69 _t70} · makes List$P
                              let _t72 = con Cons _t68 _t71  ; Δ{_t67 _t68 _t71} · moves{_t68 _t71} · makes List$P
                              let _t73 = call countAll$P _t67 _t72  ; Δ{_t67 _t72}
                              let _t74 = call show$Int _t73  ; Δ{} · makes String
                              let _t75 = putStrLn _t74  ; Δ{_t74}
                              ret case _t75 of
                            _ ->
                          drop _t58 : Integer
                          drop _t63 : List$Integer
                          drop _t65 : String
                          let _t58 = rtcall axion_bignum_from_i64 4  ; Δ{} · makes Integer
                          let _t59 = rtcall axion_bignum_from_i64 4  ; Δ{_t58} · makes Integer
                          let _t60 = rtcall axion_bignum_from_i64 5  ; Δ{_t58 _t59} · makes Integer
                          let _t61 = con Nil  ; Δ{_t58 _t59 _t60} · makes List$Integer
                          let _t62 = con Cons _t60 _t61  ; Δ{_t58 _t59 _t60 _t61} · moves{_t60 _t61} · makes List$Integer
                          let _t63 = con Cons _t59 _t62  ; Δ{_t58 _t59 _t62} · moves{_t59 _t62} · makes List$Integer
                          let _t64 = call countEq$Integer _t58 _t63  ; Δ{_t58 _t63}
                          let _t65 = call show$Int _t64  ; Δ{} · makes String
                          let _t66 = putStrLn _t65  ; Δ{_t65}
                          ret case _t66 of
                        _ ->
                      drop _t47 : P
                      drop _t54 : List$P
                      drop _t56 : String
                      let _t47 = con P 2 9  ; Δ{} · makes P
                      let _t48 = con P 1 5  ; Δ{_t47} · makes P
                      let _t49 = con P 2 5  ; Δ{_t47 _t48} · makes P
                      let _t50 = con P 2 1  ; Δ{_t47 _t48 _t49} · makes P
                      let _t51 = con Nil  ; Δ{_t47 _t48 _t49 _t50} · makes List$P
                      let _t52 = con Cons _t50 _t51  ; Δ{_t47 _t48 _t49 _t50 _t51} · moves{_t50 _t51} · makes List$P
                      let _t53 = con Cons _t49 _t52  ; Δ{_t47 _t48 _t49 _t52} · moves{_t49 _t52} · makes List$P
                      let _t54 = con Cons _t48 _t53  ; Δ{_t47 _t48 _t53} · moves{_t48 _t53} · makes List$P
                      let _t55 = call countEq$P _t47 _t54  ; Δ{_t47 _t54}
                      let _t56 = call show$Int _t55  ; Δ{} · makes String
                      let _t57 = putStrLn _t56  ; Δ{_t56}
                      ret case _t57 of
                    _ ->
                  drop _t43 : List$Float
                  drop _t45 : String
                  let _t40 = con Nil  ; Δ{} · makes List$Float
                  let _t41 = con Cons 1f _t40  ; Δ{_t40} · moves{_t40} · makes List$Float
                  let _t42 = con Cons 2.5f _t41  ; Δ{_t41} · moves{_t41} · makes List$Float
                  let _t43 = call delE$Float 2.5f _t42  ; Δ{_t42} · moves{_t42} · makes List$Float
                  let _t44 = call lenL _t43  ; Δ{_t43}
                  let _t45 = call show$Int _t44  ; Δ{} · makes String
                  let _t46 = putStrLn _t45  ; Δ{_t45}
                  ret case _t46 of
                _ ->
              drop _t36 : List$String
              drop _t38 : String
              let _t32 = con Nil  ; Δ{} · makes List$String
              let _t33 = con Cons "c" _t32  ; Δ{_t32} · moves{_t32} · makes List$String
              let _t34 = con Cons "b" _t33  ; Δ{_t33} · moves{_t33} · makes List$String
              let _t35 = con Cons "a" _t34  ; Δ{_t34} · moves{_t34} · makes List$String
              let _t36 = call delN$String "b" _t35  ; Δ{_t35} · moves{_t35} · makes List$String
              let _t37 = call lenL _t36  ; Δ{_t36}
              let _t38 = call show$Int _t37  ; Δ{} · makes String
              let _t39 = putStrLn _t38  ; Δ{_t38}
              ret case _t39 of
            _ ->
          drop _t20 : Integer
          drop _t28 : List$Integer
          drop _t30 : String
          let _t0 = < a b  ; Δ{}
          let _t0 = < a b  ; Δ{}
          let _t1 = call zipLt r s  ; Δ{} · makes List$Bool
          let _t1 = call zipLt$Int r s  ; Δ{} · makes List$Bool
          let _t20 = rtcall axion_bignum_from_i64 7  ; Δ{} · makes Integer
          let _t21 = rtcall axion_bignum_from_i64 3  ; Δ{_t20} · makes Integer
          let _t22 = rtcall axion_bignum_from_i64 7  ; Δ{_t20 _t21} · makes Integer
          let _t23 = rtcall axion_bignum_from_i64 7  ; Δ{_t20 _t21 _t22} · makes Integer
          let _t24 = con Nil  ; Δ{_t20 _t21 _t22 _t23} · makes List$Integer
          let _t25 = con Cons _t23 _t24  ; Δ{_t20 _t21 _t22 _t23 _t24} · moves{_t23 _t24} · makes List$Integer
          let _t26 = con Cons _t22 _t25  ; Δ{_t20 _t21 _t22 _t25} · moves{_t22 _t25} · makes List$Integer
          let _t27 = con Cons _t21 _t26  ; Δ{_t20 _t21 _t26} · moves{_t21 _t26} · makes List$Integer
          let _t28 = call delE$Integer _t20 _t27  ; Δ{_t20 _t27} · moves{_t27} · makes List$Integer
          let _t29 = call lenL _t28  ; Δ{_t28}
          let _t30 = call show$Int _t29  ; Δ{} · makes String
          let _t31 = putStrLn _t30  ; Δ{_t30}
          ret == x y  ; Δ{}
          ret case _t31 of
          ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List$Bool
          ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List$Bool
          ret con Nil  ; Δ{} · makes List$Bool
          ret con Nil  ; Δ{} · makes List$Bool
        Cons b s ->
        Cons b s ->
        Nil ->
        Nil ->
        P y _ ->
        _ ->
        drop y
        drop y
        drop y : Integer
        drop y : String
        let _t1 = call delBy$$hoflamc3 x rest  ; Δ{rest y} · moves{rest} · makes List
        let _t1 = call delBy$$hoflamc3$Float x rest  ; Δ{rest y} · moves{rest} · makes List$Float
        let _t1 = call delBy$$hoflamc3$Integer x rest  ; Δ{rest y} · moves{rest} · makes List$Integer
        let _t1 = call delBy$$hoflamc3$P x rest  ; Δ{rest y} · moves{rest} · makes List$P
        let _t1 = call delBy$$myEq x rest  ; Δ{rest y} · moves{rest} · makes List
        let _t1 = call delBy$$myEq$P x rest  ; Δ{rest y} · moves{rest} · makes List$P
        let _t1 = call delBy$$myEq$String x rest  ; Δ{rest y} · moves{rest} · makes List$String
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
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y}
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y}
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y}
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y}
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y}
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y}
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y}
        ret rest  ; Δ{rest y} · moves{rest}
        ret rest  ; Δ{rest y} · moves{rest}
        ret rest  ; Δ{rest y} · moves{rest}
        ret rest  ; Δ{rest} · moves{rest}
        ret rest  ; Δ{rest} · moves{rest}
        ret rest  ; Δ{rest} · moves{rest}
        ret rest  ; Δ{rest} · moves{rest}
      drop _t0 : Integer
      drop _t10 : P
      drop _t16 : List$P
      drop _t18 : String
      drop ys
      drop ys
      drop ys
      drop ys
      drop ys
      drop ys
      drop ys
      drop ys
      drop ys
      drop ys : List$Float
      drop ys : List$Integer
      drop ys : List$P
      drop ys : List$P
      drop ys : List$String
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      else
      let _d1000000 = rtcall axion_bignum_add y _t0  ; Δ{_t0} · makes Integer
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Bool _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Float _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Integer _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$P _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_bignum_free _dd2  ; Δ{}
      let _dd3 = rtcall axion_free _dd2  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call hoflamc3 x y  ; Δ{rest y}
      let _t0 = call hoflamc3$Float x y  ; Δ{rest y}
      let _t0 = call hoflamc3$Integer x y  ; Δ{rest y}
      let _t0 = call hoflamc3$P x y  ; Δ{rest y}
      let _t0 = call hoflamc4 _cap0 y  ; Δ{}
      let _t0 = call hoflamc4$Integer _cap0 y  ; Δ{}
      let _t0 = call hoflamc4$P _cap0 y  ; Δ{}
      let _t0 = call hoflamc4$String _cap0 y  ; Δ{}
      let _t0 = call hoflamc5 y  ; Δ{}
      let _t0 = call hoflamc5$P y  ; Δ{}
      let _t0 = call hoflamc6 y  ; Δ{}
      let _t0 = call hoflamc7 y  ; Δ{}
      let _t0 = call hoflamc7$Int y  ; Δ{}
      let _t0 = call hoflamc7$Integer y  ; Δ{} · makes Integer
      let _t0 = call lenL r  ; Δ{}
      let _t0 = call myEq x y  ; Δ{rest y}
      let _t0 = call myEq$P x y  ; Δ{rest y}
      let _t0 = call myEq$String x y  ; Δ{rest y}
      let _t0 = call sumBig r  ; Δ{} · makes Integer
      let _t0 = call sumI r  ; Δ{}
      let _t1 = call mapL$$hoflamc7 r  ; Δ{} · makes List
      let _t1 = call mapL$$hoflamc7$Int r  ; Δ{} · makes List$Int
      let _t1 = call mapL$$hoflamc7$Integer r  ; Δ{_t0} · makes List$Integer
      let _t1 = if _t0 then
      let _t1 = if _t0 then
      let _t1 = if _t0 then
      let _t1 = if _t0 then
      let _t1 = if _t0 then
      let _t1 = if _t0 then
      let _t1 = if _t0 then
      let _t10 = con P 1 0  ; Δ{} · makes P
      let _t11 = con P 1 5  ; Δ{_t10} · makes P
      let _t12 = con P 2 5  ; Δ{_t10 _t11} · makes P
      let _t13 = con Nil  ; Δ{_t10 _t11 _t12} · makes List$P
      let _t14 = con Cons _t12 _t13  ; Δ{_t10 _t11 _t12 _t13} · moves{_t12 _t13} · makes List$P
      let _t15 = con Cons _t11 _t14  ; Δ{_t10 _t11 _t14} · moves{_t11 _t14} · makes List$P
      let _t16 = call delN$P _t10 _t15  ; Δ{_t10 _t15} · moves{_t15} · makes List$P
      let _t17 = call lenL _t16  ; Δ{_t16}
      let _t18 = call show$Int _t17  ; Δ{} · makes String
      let _t19 = putStrLn _t18  ; Δ{_t18}
      let _t2 = call countBy$$hoflamc4 _cap0 r  ; Δ{}
      let _t2 = call countBy$$hoflamc4$Integer _cap0 r  ; Δ{}
      let _t2 = call countBy$$hoflamc4$P _cap0 r  ; Δ{}
      let _t2 = call countBy$$hoflamc4$String _cap0 r  ; Δ{}
      let _t2 = call countBy$$hoflamc5 r  ; Δ{}
      let _t2 = call countBy$$hoflamc5$P r  ; Δ{}
      let _t2 = call countBy$$hoflamc6 r  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret + _t1 _t2  ; Δ{}
      ret + _t1 _t2  ; Δ{}
      ret + _t1 _t2  ; Δ{}
      ret + _t1 _t2  ; Δ{}
      ret + _t1 _t2  ; Δ{}
      ret + _t1 _t2  ; Δ{}
      ret + _t1 _t2  ; Δ{}
      ret + y _t0  ; Δ{}
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
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret case _t19 of
      ret case b of
      ret case ys of
      ret case ys of
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1}
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{} · makes List$Bool
      ret con Nil  ; Δ{} · makes List$Bool
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret rtcall axion_bignum_from_i64 0  ; Δ{} · makes Integer
    Cons _ r ->
    Cons a r ->
    Cons a r ->
    Cons y r ->
    Cons y r ->
    Cons y r ->
    Cons y r ->
    Cons y r ->
    Cons y r ->
    Cons y r ->
    Cons y r ->
    Cons y r ->
    Cons y r ->
    Cons y r ->
    Cons y r ->
    Cons y rest ->
    Cons y rest ->
    Cons y rest ->
    Cons y rest ->
    Cons y rest ->
    Cons y rest ->
    Cons y rest ->
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
    P x _ ->
    _ ->
    else
    else
    else
    else
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
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
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
  ; Δ{rest y}
  ; Δ{rest y}
  ; Δ{rest y}
  ; Δ{rest y}
  ; Δ{rest y}
  ; Δ{rest y}
  ; Δ{rest y}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : List$Bool
  drop _t0 : List$Bool
  drop _t0 : P
  drop _t6 : List$P
  drop _t8 : String
  else
  else
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = call countBy$$hoflamc6 _t0  ; Δ{_t0}
  let _d1000000 = call countBy$$hoflamc6 _t0  ; Δ{_t0}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _t0 = call countBy$$hoflamc5 xs  ; Δ{}
  let _t0 = call countBy$$hoflamc5$P xs  ; Δ{}
  let _t0 = call zipLt xs ys  ; Δ{} · makes List$Bool
  let _t0 = call zipLt$Int xs ys  ; Δ{} · makes List$Bool
  let _t0 = con P 1 0  ; Δ{} · makes P
  let _t0 = rtcall axion_str_cmp x y  ; Δ{}
  let _t1 = == x x  ; Δ{}
  let _t1 = call eq$P x x  ; Δ{}
  let _t1 = con P 1 5  ; Δ{_t0} · makes P
  let _t2 = con P 2 5  ; Δ{_t0 _t1} · makes P
  let _t2 = if _t1 then
  let _t2 = if _t1 then
  let _t3 = con Nil  ; Δ{_t0 _t1 _t2} · makes List$P
  let _t4 = con Cons _t2 _t3  ; Δ{_t0 _t1 _t2 _t3} · moves{_t2 _t3} · makes List$P
  let _t5 = con Cons _t1 _t4  ; Δ{_t0 _t1 _t4} · moves{_t1 _t4} · makes List$P
  let _t6 = call delE$P _t0 _t5  ; Δ{_t0 _t5} · moves{_t5} · makes List$P
  let _t7 = call lenL _t6  ; Δ{_t6}
  let _t8 = call show$Int _t7  ; Δ{} · makes String
  let _t9 = putStrLn _t8  ; Δ{_t8}
  ret + _t0 _t2  ; Δ{}
  ret + _t0 _t2  ; Δ{}
  ret + v v  ; Δ{}
  ret + v v  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 1  ; Δ{}
  ret 1  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret == p q  ; Δ{}
  ret == p q  ; Δ{}
  ret == y x  ; Δ{}
  ret ==. p q  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret b  ; Δ{}
  ret call countBy$$hoflamc4 x xs  ; Δ{}
  ret call countBy$$hoflamc4$Integer x xs  ; Δ{}
  ret call countBy$$hoflamc4$P x xs  ; Δ{}
  ret call countBy$$hoflamc4$String x xs  ; Δ{}
  ret call delBy$$hoflamc3 x ys  ; Δ{} · makes List
  ret call delBy$$hoflamc3$Float x ys  ; Δ{} · makes List$Float
  ret call delBy$$hoflamc3$Integer x ys  ; Δ{} · makes List$Integer
  ret call delBy$$hoflamc3$P x ys  ; Δ{} · makes List$P
  ret call delBy$$myEq x ys  ; Δ{} · makes List
  ret call delBy$$myEq$P x ys  ; Δ{} · makes List$P
  ret call delBy$$myEq$String x ys  ; Δ{} · makes List$String
  ret call eq$P p q  ; Δ{}
  ret call eq$P p q  ; Δ{}
  ret call eq$P y x  ; Δ{}
  ret call eq$String p q  ; Δ{}
  ret call eq$String y x  ; Δ{}
  ret call mapL$$hoflamc7 xs  ; Δ{} · makes List
  ret call mapL$$hoflamc7$Int xs  ; Δ{} · makes List$Int
  ret call mapL$$hoflamc7$Integer xs  ; Δ{} · makes List$Integer
  ret case _t9 of
  ret case a of
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
  ret case ys of
  ret case ys of
  ret case ys of
  ret case ys of
  ret case ys of
  ret case ys of
  ret case ys of
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_add v v  ; Δ{} · makes Integer
  ret rtcall axion_bignum_eq p q  ; Δ{}
  ret rtcall axion_bignum_eq y x  ; Δ{}
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Bool _p  =
axion_drop_List$Float _p  =
axion_drop_List$Int _p  =
axion_drop_List$Integer _p  =
axion_drop_List$P _p  =
axion_drop_List$String _p  =
countAll x xs  =
countAll$P x xs  =
countBy$$hoflamc4 _cap0 xs  =
countBy$$hoflamc4$Integer _cap0 xs  =
countBy$$hoflamc4$P _cap0 xs  =
countBy$$hoflamc4$String _cap0 xs  =
countBy$$hoflamc5 xs  =
countBy$$hoflamc5$P xs  =
countBy$$hoflamc6 xs  =
countEq x xs  =
countEq$Integer x xs  =
countEq$P x xs  =
countEq$String x xs  =
dbls xs  =
dbls$Int xs  =
dbls$Integer xs  =
delBy$$hoflamc3 x ys  =
delBy$$hoflamc3$Float x ys  =
delBy$$hoflamc3$Integer x ys  =
delBy$$hoflamc3$P x ys  =
delBy$$myEq x ys  =
delBy$$myEq$P x ys  =
delBy$$myEq$String x ys  =
delE x ys  =
delE$Float x ys  =
delE$Integer x ys  =
delE$P x ys  =
delN x ys  =
delN$P x ys  =
delN$String x ys  =
eq$P a b  =
eq$String x y  =
hoflamc3 p q  =
hoflamc3$Float p q  =
hoflamc3$Integer p q  =
hoflamc3$P p q  =
hoflamc4 x y  =
hoflamc4$Integer x y  =
hoflamc4$P x y  =
hoflamc4$String x y  =
hoflamc5 y  =
hoflamc5$P y  =
hoflamc6 b  =
hoflamc7 v  =
hoflamc7$Int v  =
hoflamc7$Integer v  =
lenL xs  =
main  =
mapL$$hoflamc7 xs  =
mapL$$hoflamc7$Int xs  =
mapL$$hoflamc7$Integer xs  =
myEq p q  =
myEq$P p q  =
myEq$String p q  =
show$Int x  =
smaller xs ys  =
smaller$Int xs ys  =
sumBig xs  =
sumI xs  =
zipLt xs ys  =
zipLt$Int xs ys  =
