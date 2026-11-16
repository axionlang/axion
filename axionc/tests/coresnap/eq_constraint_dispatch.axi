



































                                                  drop _t78 : List$Int
                                                  drop _t79 : String
                                                  let _d1000000 = putStrLn _t79  ; Δ{_t79}
                                                  let _t74 = con Nil  ; Δ{} · makes List$Int
                                                  let _t75 = con Cons 3 _t74  ; Δ{_t74} · moves{_t74} · makes List$Int
                                                  let _t76 = con Cons 2 _t75  ; Δ{_t75} · moves{_t75} · makes List$Int
                                                  let _t77 = con Cons 1 _t76  ; Δ{_t76} · moves{_t76} · makes List$Int
                                                  let _t78 = call delL$Int 1 _t77  ; Δ{_t77} · moves{_t77} · makes List$Int
                                                  let _t79 = call show$List$Int _t78  ; Δ{_t78} · makes String
                                                  ret _d1000000  ; Δ{}
                                                _ ->
                                              drop _t71 : List$Int
                                              drop _t72 : String
                                              let _t67 = con Nil  ; Δ{} · makes List$Int
                                              let _t68 = con Cons 3 _t67  ; Δ{_t67} · moves{_t67} · makes List$Int
                                              let _t69 = con Cons 2 _t68  ; Δ{_t68} · moves{_t68} · makes List$Int
                                              let _t70 = con Cons 1 _t69  ; Δ{_t69} · moves{_t69} · makes List$Int
                                              let _t71 = call delE$Int 3 _t70  ; Δ{_t70} · moves{_t70} · makes List$Int
                                              let _t72 = call show$List$Int _t71  ; Δ{_t71} · makes String
                                              let _t73 = putStrLn _t72  ; Δ{_t72}
                                              ret case _t73 of
                                            _ ->
                                          drop _t59
                                          drop _t64 : List$Int
                                          drop _t65 : String
                                          let _t59 = closure lam$0  ; Δ{} · makes heap
                                          let _t60 = con Nil  ; Δ{_t59} · makes List$Int
                                          let _t61 = con Cons 3 _t60  ; Δ{_t59 _t60} · moves{_t60} · makes List$Int
                                          let _t62 = con Cons 2 _t61  ; Δ{_t59 _t61} · moves{_t61} · makes List$Int
                                          let _t63 = con Cons 1 _t62  ; Δ{_t59 _t62} · moves{_t62} · makes List$Int
                                          let _t64 = call delBy$Int _t59 2 _t63  ; Δ{_t59 _t63} · moves{_t63} · makes List$Int
                                          let _t65 = call show$List$Int _t64  ; Δ{_t64} · makes String
                                          let _t66 = putStrLn _t65  ; Δ{_t65}
                                          ret case _t66 of
                                        _ ->
                                      drop _t56 : List$Int
                                      drop _t57 : String
                                      let _t52 = con Nil  ; Δ{} · makes List$Int
                                      let _t53 = con Cons 3 _t52  ; Δ{_t52} · moves{_t52} · makes List$Int
                                      let _t54 = con Cons 2 _t53  ; Δ{_t53} · moves{_t53} · makes List$Int
                                      let _t55 = con Cons 1 _t54  ; Δ{_t54} · moves{_t54} · makes List$Int
                                      let _t56 = call firstOut$Int 3 _t55  ; Δ{_t55} · moves{_t55} · makes List$Int
                                      let _t57 = call show$List$Int _t56  ; Δ{_t56} · makes String
                                      let _t58 = putStrLn _t57  ; Δ{_t57}
                                      ret case _t58 of
                                    _ ->
                                  drop _t48 : Integer
                                  drop _t49 : Integer
                                  drop _t50 : String
                                  let _t48 = rtcall axion_bignum_from_i64 21  ; Δ{} · makes Integer
                                  let _t49 = call dbl$Integer _t48  ; Δ{_t48} · makes Integer
                                  let _t50 = call show$Integer _t49  ; Δ{_t49} · makes String
                                  let _t51 = putStrLn _t50  ; Δ{_t50}
                                  ret case _t51 of
                                _ ->
                              drop _t36 : P
                              drop _t43 : List$P
                              drop _t46 : String
                              let _t36 = con P 1 0  ; Δ{} · makes P
                              let _t37 = con P 1 5  ; Δ{_t36} · makes P
                              let _t38 = con P 2 5  ; Δ{_t36 _t37} · makes P
                              let _t39 = con P 1 9  ; Δ{_t36 _t37 _t38} · makes P
                              let _t40 = con Nil  ; Δ{_t36 _t37 _t38 _t39} · makes List$P
                              let _t41 = con Cons _t39 _t40  ; Δ{_t36 _t37 _t38 _t39 _t40} · moves{_t39 _t40} · makes List$P
                              let _t42 = con Cons _t38 _t41  ; Δ{_t36 _t37 _t38 _t41} · moves{_t38 _t41} · makes List$P
                              let _t43 = con Cons _t37 _t42  ; Δ{_t36 _t37 _t42} · moves{_t37 _t42} · makes List$P
                              let _t44 = call count$P _t36 _t43  ; Δ{_t36 _t43}
                              let _t45 = - _t44 1  ; Δ{}
                              let _t46 = call show$Int _t45  ; Δ{} · makes String
                              let _t47 = putStrLn _t46  ; Δ{_t46}
                              ret case _t47 of
                            _ ->
                          drop _t30 : Integer
                          drop _t31 : Integer
                          drop _t34 : String
                          let _t30 = rtcall axion_bignum_from_i64 7  ; Δ{} · makes Integer
                          let _t31 = rtcall axion_bignum_from_i64 7  ; Δ{_t30} · makes Integer
                          let _t32 = call same$Integer _t30 _t31  ; Δ{_t30 _t31}
                          let _t33 = call b2i _t32  ; Δ{}
                          let _t34 = call show$Int _t33  ; Δ{} · makes String
                          let _t35 = putStrLn _t34  ; Δ{_t34}
                          ret case _t35 of
                        _ ->
                      drop _t28 : String
                      let _t26 = call same$String "ab" "ac"  ; Δ{}
                      let _t27 = call b2i _t26  ; Δ{}
                      let _t28 = call show$Int _t27  ; Δ{} · makes String
                      let _t29 = putStrLn _t28  ; Δ{_t28}
                      ret case _t29 of
                    _ ->
                  drop _t24 : String
                  let _t22 = call same$Float 2.5f 2.5f  ; Δ{}
                  let _t23 = call b2i _t22  ; Δ{}
                  let _t24 = call show$Int _t23  ; Δ{} · makes String
                  let _t25 = putStrLn _t24  ; Δ{_t24}
                  ret case _t25 of
                _ ->
              drop _t20 : String
              let _t18 = call same$Int 4 4  ; Δ{}
              let _t19 = call b2i _t18  ; Δ{}
              let _t20 = call show$Int _t19  ; Δ{} · makes String
              let _t21 = putStrLn _t20  ; Δ{_t20}
              ret case _t21 of
            _ ->
          drop _t12 : P
          drop _t13 : P
          drop _t16 : String
          let _t12 = con P 1 2  ; Δ{} · makes P
          let _t13 = con P 2 2  ; Δ{_t12} · makes P
          let _t14 = call same$P _t12 _t13  ; Δ{_t12 _t13}
          let _t15 = call b2i _t14  ; Δ{}
          let _t16 = call show$Int _t15  ; Δ{} · makes String
          let _t17 = putStrLn _t16  ; Δ{_t16}
          ret == x y  ; Δ{}
          ret case _t17 of
        P y _ ->
        _ ->
        let _t1 = call delBy$$hoflamc3 x rest  ; Δ{rest y} · moves{rest} · makes List
        let _t1 = call delBy$$hoflamc3$Int x rest  ; Δ{rest y} · moves{rest} · makes List$Int
        let _t1 = call delBy$Int f x rest  ; Δ{rest} · moves{rest} · makes List$Int
        ret 0  ; Δ{}
        ret 0  ; Δ{}
        ret 1  ; Δ{}
        ret 1  ; Δ{}
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y}
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y}
        ret con Cons y _t1  ; Δ{_t1} · moves{_t1}
        ret rest  ; Δ{rest y} · moves{rest}
        ret rest  ; Δ{rest y} · moves{rest}
        ret rest  ; Δ{rest} · moves{rest}
      drop _t0 : String
      drop _t0 : String
      drop _t1 : String
      drop _t1 : String
      drop _t10 : String
      drop _t2 : String
      drop _t6 : P
      drop _t7 : P
      drop ys
      drop ys
      drop ys
      drop ys
      drop ys
      drop ys : List$Int
      drop ys : List$Int
      drop ys : List$Int
      else
      else
      else
      else
      else
      let _d1000000 = rtcall axion_strcat ", " _t2  ; Δ{_t2} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$P _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_free _dd2  ; Δ{}
      let _t0 = == x y  ; Δ{}
      let _t0 = call eq$P x y  ; Δ{}
      let _t0 = call hoflamc3 x y  ; Δ{rest y}
      let _t0 = call hoflamc3$Int x y  ; Δ{rest y}
      let _t0 = call show$Int y  ; Δ{} · makes String
      let _t0 = call show$Int z  ; Δ{} · makes String
      let _t0 = callclo f x y  ; Δ{rest y} · moves{y}
      let _t1 = call showListRest$Int ys  ; Δ{_t0} · makes String
      let _t1 = call showListRest$Int zs  ; Δ{_t0} · makes String
      let _t1 = if _t0 then
      let _t1 = if _t0 then
      let _t10 = call show$Int _t9  ; Δ{} · makes String
      let _t11 = putStrLn _t10  ; Δ{_t10}
      let _t2 = call count x rest  ; Δ{}
      let _t2 = call count$P x rest  ; Δ{}
      let _t2 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _t6 = con P 1 2  ; Δ{} · makes P
      let _t7 = con P 1 3  ; Δ{_t6} · makes P
      let _t8 = call same$P _t6 _t7  ; Δ{_t6 _t7}
      let _t9 = call b2i _t8  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret + _t1 _t2  ; Δ{}
      ret + _t1 _t2  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret case _t11 of
      ret case b of
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret rest  ; Δ{rest y} · moves{rest}
    Cons y rest ->
    Cons y rest ->
    Cons y rest ->
    Cons y rest ->
    Cons y rest ->
    Cons y rest ->
    Cons y ys ->
    Cons z zs ->
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
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
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
    ret 1  ; Δ{}
    ret call dropOne$Int x ys  ; Δ{} · makes List$Int
    ret ys  ; Δ{}
  ; Δ{rest y}
  ; Δ{rest y}
  ; Δ{rest}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
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
  drop _t0 : P
  drop _t0 : String
  drop _t1 : P
  drop _t1 : String
  drop _t4 : String
  else
  else
  else
  else
  else
  let _d1000000 = call delBy$Int _t0 x ys  ; Δ{_t0} · makes List$Int
  let _d1000000 = rtcall axion_strcat "[" _t1  ; Δ{_t1} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = == x x  ; Δ{}
  let _t0 = call showListElems$Int xs  ; Δ{} · makes String
  let _t0 = closure lam$1  ; Δ{} · makes heap
  let _t0 = con P 1 2  ; Δ{} · makes P
  let _t0 = rtcall axion_str_cmp x y  ; Δ{}
  let _t1 = con P 1 3  ; Δ{_t0} · makes P
  let _t1 = rtcall axion_strcat _t0 "]"  ; Δ{_t0} · makes String
  let _t2 = call eq$P _t0 _t1  ; Δ{_t0 _t1}
  let _t3 = call b2i _t2  ; Δ{}
  let _t4 = call show$Int _t3  ; Δ{} · makes String
  let _t5 = putStrLn _t4  ; Δ{_t4}
  ret + x x  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret == p q  ; Δ{}
  ret == p q  ; Δ{}
  ret == x y  ; Δ{}
  ret == x y  ; Δ{}
  ret == x y  ; Δ{}
  ret ==. x y  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret call delBy$$hoflamc3 x ys  ; Δ{} · makes List
  ret call delBy$$hoflamc3$Int x ys  ; Δ{} · makes List$Int
  ret call eq$Int eta$1 eta$2  ; Δ{}
  ret call eq$Int eta$4 eta$5  ; Δ{}
  ret call eq$P x y  ; Δ{}
  ret call eq$String x y  ; Δ{}
  ret case _t5 of
  ret case a of
  ret case xs of
  ret case ys of
  ret case ys of
  ret case ys of
  ret case ys of
  ret case ys of
  ret case ys of
  ret case ys of
  ret if _t0 then
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_add x x  ; Δ{} · makes Integer
  ret rtcall axion_bignum_eq x y  ; Δ{}
  ret rtcall axion_bignum_to_string x  ; Δ{} · makes String
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_List$P _p  =
b2i b  =
count x ys  =
count$P x ys  =
dbl x  =
dbl$Integer x  =
delBy$$hoflamc3 x ys  =
delBy$$hoflamc3$Int x ys  =
delBy$Int f x ys  =
delE$Int x ys  =
delL x ys  =
delL$Int x ys  =
dropOne$Int x ys  =
eq$Int x y  =
eq$P a b  =
eq$String x y  =
firstOut$Int x ys  =
hoflamc3 p q  =
hoflamc3$Int p q  =
lam$0 [env ]eta$1 eta$2  =
lam$1 [env ]eta$4 eta$5  =
main  =
same x y  =
same$Float x y  =
same$Int x y  =
same$Integer x y  =
same$P x y  =
same$String x y  =
show$Int x  =
show$Integer x  =
show$List$Int xs  =
showListElems$Int xs  =
showListRest$Int ys  =
