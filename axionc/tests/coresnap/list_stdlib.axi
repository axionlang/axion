




































        _ ->
append xs ys  =
axion_drop_List$Int _p  =
axion_drop_List _p  =
b2i b  =
compose f g x  =
concat xs  =
    Cons a as ->
        Cons b bs ->
    Cons s ss ->
    Cons s ss ->
        Cons t ts ->
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
drop n xs  =
      drop _t0 : List
  drop _t12 : List
  drop _t18 : List$Int
  drop _t19 : List
  drop _t26 : List$Int
  drop _t33 : List$Int
  drop _t39 : List$Int
  drop _t40 : List
  drop _t46 : List$Int
  drop _t47 : List
  drop _t4 : List$Int
  drop _t57 : List$Int
  drop _t58 : List
  drop _t68 : List$Int
  drop _t8 : List$Int
elem x xs  =
      else
      else
      else
      else
    else
    else
    else
  else
  else
  else
  else
  else
  else
  else
  else
eq$Bool x y  =
eq$Float x y  =
eq$Int x y  =
evenN n  =
filter p xs  =
foldl f z xs  =
foldr f z xs  =
lam$0 [env ]a b  =
lam$1 [env ]x a  =
lam$2 [env ]a x  =
lam$3 [env ]eta$1  =
le$Float x y  =
le$Int x y  =
length xs  =
      let _d1000000 = call append _t0 _t2  ; Δ{_t0} · makes List
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = call append zs ys  ; Δ{} · makes List
          let _t0 = callclo f a b  ; Δ{}
      let _t0 = callclo f y  ; Δ{}
      let _t0 = callclo f y  ; Δ{}
      let _t0 = callclo f z y  ; Δ{}
  let _t0 = callclo g x  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = call concat ys  ; Δ{} · makes List
      let _t0 = call foldr f z ys  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call reverse ys  ; Δ{} · makes List
      let _t0 = call sum ys  ; Δ{}
      let _t0 = call unlines ss  ; Δ{}
          let _t0 = call unwords ss  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = > lo hi  ; Δ{}
  let _t0 = mod n 2  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = == x y  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = <. x y  ; Δ{}
  let _t10 = con Cons 4 _t9  ; Δ{_t8 _t9} · moves{_t9} · makes List$Int
  let _t11 = con Cons 3 _t10  ; Δ{_t10 _t8} · moves{_t10} · makes List$Int
  let _t12 = call append _t8 _t11  ; Δ{_t11 _t8} · moves{_t11} · makes List
  let _t13 = call sum _t12  ; Δ{_t12}
  let _t14 = + _t5 _t13  ; Δ{}
  let _t15 = con Nil  ; Δ{} · makes List$Int
  let _t16 = con Cons 30 _t15  ; Δ{_t15} · moves{_t15} · makes List$Int
  let _t17 = con Cons 20 _t16  ; Δ{_t16} · moves{_t16} · makes List$Int
  let _t18 = con Cons 10 _t17  ; Δ{_t17} · moves{_t17} · makes List$Int
  let _t19 = call reverse _t18  ; Δ{_t18} · makes List
        let _t1 = call filter p ys  ; Δ{} · makes List
      let _t1 = call map f ys  ; Δ{} · makes List
          let _t1 = call zipWith f as bs  ; Δ{} · makes List
  let _t1 = con Cons 4 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
      let _t1 = con Nil  ; Δ{_t0}
    let _t1 = + lo 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
      let _t1 = rtcall axion_strcat "\n" _t0  ; Δ{}
          let _t1 = rtcall axion_strcat " " _t0  ; Δ{}
  let _t20 = call sum _t19  ; Δ{_t19}
  let _t21 = + _t14 _t20  ; Δ{}
  let _t22 = closure lam$1  ; Δ{} · makes heap
  let _t23 = con Nil  ; Δ{_t22} · makes List$Int
  let _t24 = con Cons 3 _t23  ; Δ{_t22 _t23} · moves{_t23} · makes List$Int
  let _t25 = con Cons 2 _t24  ; Δ{_t22 _t24} · moves{_t24} · makes List$Int
  let _t26 = con Cons 1 _t25  ; Δ{_t22 _t25} · moves{_t25} · makes List$Int
  let _t27 = call foldr _t22 0 _t26  ; Δ{_t22 _t26} · moves{_t22}
  let _t28 = + _t21 _t27  ; Δ{}
  let _t29 = closure lam$2  ; Δ{} · makes heap
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
        let _t2 = call take _t1 ys  ; Δ{} · makes List
  let _t2 = con Cons 3 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
      let _t2 = con Cons y _t1  ; Δ{_t0}
  let _t30 = con Nil  ; Δ{_t29} · makes List$Int
  let _t31 = con Cons 6 _t30  ; Δ{_t29 _t30} · moves{_t30} · makes List$Int
  let _t32 = con Cons 5 _t31  ; Δ{_t29 _t31} · moves{_t31} · makes List$Int
  let _t33 = con Cons 4 _t32  ; Δ{_t29 _t32} · moves{_t32} · makes List$Int
  let _t34 = call foldl _t29 0 _t33  ; Δ{_t29 _t33} · moves{_t29}
  let _t35 = + _t28 _t34  ; Δ{}
  let _t36 = con Nil  ; Δ{} · makes List$Int
  let _t37 = con Cons 300 _t36  ; Δ{_t36} · moves{_t36} · makes List$Int
  let _t38 = con Cons 200 _t37  ; Δ{_t37} · moves{_t37} · makes List$Int
  let _t39 = con Cons 100 _t38  ; Δ{_t38} · moves{_t38} · makes List$Int
  let _t3 = con Cons 2 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  let _t40 = call take 2 _t39  ; Δ{_t39} · makes List
  let _t41 = call sum _t40  ; Δ{_t40}
  let _t42 = + _t35 _t41  ; Δ{}
  let _t43 = con Nil  ; Δ{} · makes List$Int
  let _t44 = con Cons 3 _t43  ; Δ{_t43} · moves{_t43} · makes List$Int
  let _t45 = con Cons 2 _t44  ; Δ{_t44} · moves{_t44} · makes List$Int
  let _t46 = con Cons 1 _t45  ; Δ{_t45} · moves{_t45} · makes List$Int
  let _t47 = call drop 1 _t46  ; Δ{_t46} · makes List
  let _t48 = call sum _t47  ; Δ{_t47}
  let _t49 = + _t42 _t48  ; Δ{}
  let _t4 = con Cons 1 _t3  ; Δ{_t3} · moves{_t3} · makes List$Int
  let _t50 = closure lam$3  ; Δ{} · makes heap
  let _t51 = con Nil  ; Δ{_t50} · makes List$Int
  let _t52 = con Cons 6 _t51  ; Δ{_t50 _t51} · moves{_t51} · makes List$Int
  let _t53 = con Cons 5 _t52  ; Δ{_t50 _t52} · moves{_t52} · makes List$Int
  let _t54 = con Cons 4 _t53  ; Δ{_t50 _t53} · moves{_t53} · makes List$Int
  let _t55 = con Cons 3 _t54  ; Δ{_t50 _t54} · moves{_t54} · makes List$Int
  let _t56 = con Cons 2 _t55  ; Δ{_t50 _t55} · moves{_t55} · makes List$Int
  let _t57 = con Cons 1 _t56  ; Δ{_t50 _t56} · moves{_t56} · makes List$Int
  let _t58 = call filter _t50 _t57  ; Δ{_t50 _t57} · moves{_t50} · makes List
  let _t59 = call sum _t58  ; Δ{_t58}
  let _t5 = call length _t4  ; Δ{_t4}
  let _t60 = + _t49 _t59  ; Δ{}
  let _t61 = con Nil  ; Δ{}
  let _t62 = call null _t61  ; Δ{}
  let _t63 = call b2i _t62  ; Δ{}
  let _t64 = + _t60 _t63  ; Δ{}
  let _t65 = con Nil  ; Δ{} · makes List$Int
  let _t66 = con Cons 3 _t65  ; Δ{_t65} · moves{_t65} · makes List$Int
  let _t67 = con Cons 2 _t66  ; Δ{_t66} · moves{_t66} · makes List$Int
  let _t68 = con Cons 1 _t67  ; Δ{_t67} · moves{_t67} · makes List$Int
  let _t69 = call elem 3 _t68  ; Δ{_t68}
  let _t6 = con Nil  ; Δ{} · makes List$Int
  let _t70 = call b2i _t69  ; Δ{}
  let _t7 = con Cons 2 _t6  ; Δ{_t6} · moves{_t6} · makes List$Int
  let _t8 = con Cons 1 _t7  ; Δ{_t7} · moves{_t7} · makes List$Int
  let _t9 = con Nil  ; Δ{_t8} · makes List$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
map f xs  =
mapM_ f xs  =
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
null xs  =
range lo hi  =
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
      ret + 1 _t0  ; Δ{}
        ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
  ret + a x  ; Δ{}
      ret call append y _t0  ; Δ{_t0} · moves{_t0} · makes List
  ret callclo f _t0  ; Δ{}
      ret callclo f y _t0  ; Δ{}
        ret call drop _t1 ys  ; Δ{} · makes List
        ret call elem x ys  ; Δ{}
  ret call evenN eta$1  ; Δ{}
        ret call filter p ys  ; Δ{} · makes List
      ret call foldl f _t0 ys  ; Δ{}
          ret call mapM_ f ys  ; Δ{}
  ret call zipWith _t0 xs ys  ; Δ{_t0} · moves{_t0} · makes List
      ret case ss of
      ret case _t0 of
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
      ret case ys of
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
          ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
        ret con Cons y _t1  ; Δ{_t1} · moves{_t1}
        ret con Cons y _t2  ; Δ{_t2} · moves{_t2}
        ret con Cons y ys  ; Δ{}
      ret con Cons z _t0  ; Δ{_t0} · moves{_t0}
          ret con Nil  ; Δ{}
        ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
    ret con Nil  ; Δ{} · makes List$Int
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret "false"  ; Δ{}
  ret if b then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if x then
  ret if x then
    ret if y then
      ret putStr ""  ; Δ{}
  ret rtcall axion_show_float x  ; Δ{}
          ret rtcall axion_strcat s _t1  ; Δ{}
      ret rtcall axion_strcat s _t1  ; Δ{}
  ret showInt x  ; Δ{}
          ret s  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret + _t64 _t70  ; Δ{}
    ret "true"  ; Δ{}
  ret tuple a b  ; Δ{} · makes heap
  ret + x a  ; Δ{}
    ret == x y  ; Δ{}
    ret ==. x y  ; Δ{}
  ret == x y  ; Δ{}
  ret ==. x y  ; Δ{}
      ret ys  ; Δ{}
      ret + y _t0  ; Δ{}
    ret y  ; Δ{}
      ret z  ; Δ{}
      ret z  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
reverse xs  =
show$Bool x  =
show$Float x  =
show$Int x  =
sum xs  =
take n xs  =
unlines xs  =
unwords xs  =
zipWith f xs ys  =
zip xs ys  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
