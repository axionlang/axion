


































        _ ->
append xs ys  =
axion_drop_List _p  =
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
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
drop n xs  =
      drop _t0 : List
  drop _t15 : List
      drop _t1 : List
  drop _t25 : List
  drop _t26 : List
  drop _t8 : List
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
filter p xs  =
foldl f z xs  =
foldr f z xs  =
lam$0 [env ]a b  =
lam$1 [env y]z  =
le$Float x y  =
le$Int x y  =
length xs  =
      let _d1000000 = call append _t0 _t2  ; Δ{_t0 _t2} · moves{_t2} · makes List
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = call append zs ys  ; Δ{} · makes List
          let _t0 = callclo f a b  ; Δ{}
      let _t0 = callclo f y  ; Δ{}
      let _t0 = callclo f y  ; Δ{}
      let _t0 = callclo f z y  ; Δ{}
  let _t0 = callclo g x  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = call concat ys  ; Δ{} · makes List
  let _t0 = call eq$Int y z  ; Δ{}
      let _t0 = call foldr f z ys  ; Δ{}
      let _t0 = call le$Int d y  ; Δ{}
      let _t0 = call le$Int y d  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call reverse ys  ; Δ{} · makes List
      let _t0 = call sum ys  ; Δ{}
      let _t0 = call unlines ss  ; Δ{}
          let _t0 = call unwords ss  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
      let _t0 = closure lam$1 y  ; Δ{} · makes heap
  let _t0 = con Nil  ; Δ{} · makes List
  let _t0 = > lo hi  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = == x y  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = <. x y  ; Δ{}
  let _t10 = con Nil  ; Δ{} · makes List
  let _t11 = con Cons 5 _t10  ; Δ{_t10} · moves{_t10} · makes List
  let _t12 = con Cons 1 _t11  ; Δ{_t11} · moves{_t11} · makes List
  let _t13 = con Cons 4 _t12  ; Δ{_t12} · moves{_t12} · makes List
  let _t14 = con Cons 1 _t13  ; Δ{_t13} · moves{_t13} · makes List
  let _t15 = con Cons 3 _t14  ; Δ{_t14} · moves{_t14} · makes List
  let _t16 = call minOr$Int 100 _t15  ; Δ{_t15}
  let _t17 = + _t9 _t16  ; Δ{}
  let _t18 = con Nil  ; Δ{} · makes List
  let _t19 = con Cons 4 _t18  ; Δ{_t18} · moves{_t18} · makes List
        let _t1 = call filter p ys  ; Δ{} · makes List
      let _t1 = call filter _t0 ys  ; Δ{_t0} · moves{_t0} · makes List
      let _t1 = call map f ys  ; Δ{} · makes List
          let _t1 = call zipWith f as bs  ; Δ{} · makes List
  let _t1 = con Cons 6 _t0  ; Δ{_t0} · moves{_t0} · makes List
      let _t1 = con Nil  ; Δ{_t0} · makes List
    let _t1 = + lo 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
      let _t1 = rtcall axion_strcat "\n" _t0  ; Δ{}
          let _t1 = rtcall axion_strcat " " _t0  ; Δ{}
  let _t20 = con Cons 3 _t19  ; Δ{_t19} · moves{_t19} · makes List
  let _t21 = con Cons 3 _t20  ; Δ{_t20} · moves{_t20} · makes List
  let _t22 = con Cons 3 _t21  ; Δ{_t21} · moves{_t21} · makes List
  let _t23 = con Cons 2 _t22  ; Δ{_t22} · moves{_t22} · makes List
  let _t24 = con Cons 1 _t23  ; Δ{_t23} · moves{_t23} · makes List
  let _t25 = con Cons 1 _t24  ; Δ{_t24} · moves{_t24} · makes List
  let _t26 = call nub$Int _t25  ; Δ{_t25} · makes List
  let _t27 = call length _t26  ; Δ{_t26}
      let _t2 = call nub$Int _t1  ; Δ{_t1} · makes List
    let _t2 = call range _t1 hi  ; Δ{} · makes List
        let _t2 = call take _t1 ys  ; Δ{} · makes List
  let _t2 = con Cons 2 _t1  ; Δ{_t1} · moves{_t1} · makes List
      let _t2 = con Cons y _t1  ; Δ{_t0 _t1} · moves{_t1} · makes List
  let _t3 = con Cons 9 _t2  ; Δ{_t2} · moves{_t2} · makes List
  let _t4 = con Cons 5 _t3  ; Δ{_t3} · moves{_t3} · makes List
  let _t5 = con Cons 1 _t4  ; Δ{_t4} · moves{_t4} · makes List
  let _t6 = con Cons 4 _t5  ; Δ{_t5} · moves{_t5} · makes List
  let _t7 = con Cons 1 _t6  ; Δ{_t6} · moves{_t6} · makes List
  let _t8 = con Cons 3 _t7  ; Δ{_t7} · moves{_t7} · makes List
  let _t9 = call maxOr$Int 0 _t8  ; Δ{_t8}
    let _tag = loadraw _p+0  ; Δ{}
main  =
map f xs  =
mapM_ f xs  =
maxOr$Int d xs  =
minOr$Int d xs  =
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
nub$Int xs  =
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
      ret + 1 _t0  ; Δ{}
        ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
      ret call append y _t0  ; Δ{_t0} · moves{_t0} · makes List
  ret callclo f _t0  ; Δ{}
      ret callclo f y _t0  ; Δ{}
        ret call drop _t1 ys  ; Δ{} · makes List
        ret call elem x ys  ; Δ{}
        ret call filter p ys  ; Δ{} · makes List
      ret call foldl f _t0 ys  ; Δ{}
          ret call mapM_ f ys  ; Δ{}
        ret call maxOr$Int d ys  ; Δ{}
        ret call maxOr$Int y ys  ; Δ{}
        ret call minOr$Int d ys  ; Δ{}
        ret call minOr$Int y ys  ; Δ{}
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
  ret case xs of
  ret case xs of
  ret case xs of
      ret case ys of
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List
          ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List
        ret con Cons y _t1  ; Δ{_t1} · moves{_t1} · makes List
        ret con Cons y _t2  ; Δ{_t2} · moves{_t2} · makes List
      ret con Cons y _t2  ; Δ{_t2} · moves{_t2} · makes List
        ret con Cons y ys  ; Δ{} · makes List
      ret con Cons z _t0  ; Δ{_t0} · moves{_t0} · makes List
          ret con Nil  ; Δ{} · makes List
        ret con Nil  ; Δ{} · makes List
      ret con Nil  ; Δ{} · makes List
      ret con Nil  ; Δ{} · makes List
      ret con Nil  ; Δ{} · makes List
      ret con Nil  ; Δ{} · makes List
      ret con Nil  ; Δ{} · makes List
      ret con Nil  ; Δ{} · makes List
      ret con Nil  ; Δ{} · makes List
      ret con Nil  ; Δ{} · makes List
    ret con Nil  ; Δ{} · makes List
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret d  ; Δ{}
      ret d  ; Δ{}
    ret "false"  ; Δ{}
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
  ret if x then
  ret if x then
    ret if y then
      ret putStr ""  ; Δ{}
  ret rtcall axion_show_float x  ; Δ{}
          ret rtcall axion_strcat s _t1  ; Δ{}
      ret rtcall axion_strcat s _t1  ; Δ{}
  ret showInt x  ; Δ{}
          ret s  ; Δ{}
  ret + _t17 _t27  ; Δ{}
    ret "true"  ; Δ{}
  ret tuple a b  ; Δ{} · makes heap
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
