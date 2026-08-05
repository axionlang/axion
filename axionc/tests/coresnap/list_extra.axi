




















































        _ ->
    (a, b) ->
all p xs  =
any p xs  =
append xs ys  =
axion_drop_List$Int _p  =
axion_drop_List$List$Int _p  =
axion_drop_List _p  =
catMaybes xs  =
compose f g x  =
concat xs  =
    Cons a as_ ->
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
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
drop n xs  =
  drop _t0
      drop _t0 : List
  drop _t0 : List
  drop _t18 : List$List$Int
  drop _t19 : List
  drop _t26 : List$Int
  drop _t2 : List$Int
  drop _t31 : List$Int
  drop _t32 : List
  drop _t42 : List
  drop _t43 : List
  drop _t5 : List$Int
  drop _t9 : List
either f g e  =
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
find p xs  =
foldl f z xs  =
foldr f z xs  =
fromMaybe d m  =
intercalate sep xss  =
intersperse sep xs  =
isJust m  =
isLeft e  =
isNothing m  =
isRight e  =
    Just _ ->
    Just _ ->
    Just x ->
        Just z ->
lam$0 [env ]a b  =
lam$1 [env ]x  =
lam$2 [env ]a b  =
lam$3 [env ]eta$1  =
le$Float x y  =
le$Int x y  =
    Left _ ->
    Left _ ->
    Left x ->
length xs  =
      let _d1000000 = call append _t0 _t2  ; Δ{_t0} · makes List
  let _d1000000 = call concat _t0  ; Δ{_t0} · makes List
  let _d1000000 = call maybe d _t0 m  ; Δ{_t0}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
      let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = call append zs ys  ; Δ{} · makes List
          let _t0 = call catMaybes ys  ; Δ{} · makes List
          let _t0 = callclo f a b  ; Δ{}
      let _t0 = callclo f y  ; Δ{}
      let _t0 = callclo f y  ; Δ{}
      let _t0 = callclo f z y  ; Δ{}
  let _t0 = callclo g x  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = call concat ys  ; Δ{} · makes List
      let _t0 = call foldr f z ys  ; Δ{}
  let _t0 = call intersperse sep xss  ; Δ{} · makes List
      let _t0 = call length ys  ; Δ{}
      let _t0 = call null ys  ; Δ{}
      let _t0 = call reverse ys  ; Δ{} · makes List
      let _t0 = call sum ys  ; Δ{}
      let _t0 = call unlines ss  ; Δ{}
          let _t0 = call unwords ss  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = closure lam$1  ; Δ{} · makes heap
      let _t0 = con Nil  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = == x y  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = <. x y  ; Δ{}
  let _t10 = call sum _t9  ; Δ{_t9}
  let _t11 = con Nil  ; Δ{} · makes List$Int
  let _t12 = con Cons 1 _t11  ; Δ{_t11} · moves{_t11} · makes List$Int
  let _t13 = con Nil  ; Δ{_t12} · makes List$Int
  let _t14 = con Cons 3 _t13  ; Δ{_t12 _t13} · moves{_t13} · makes List$Int
  let _t15 = con Cons 2 _t14  ; Δ{_t12 _t14} · moves{_t14} · makes List$Int
  let _t16 = con Nil  ; Δ{_t12 _t15} · makes List$List$Int
  let _t17 = con Cons _t15 _t16  ; Δ{_t12 _t15 _t16} · moves{_t15 _t16} · makes List$List$Int
  let _t18 = con Cons _t12 _t17  ; Δ{_t12 _t17} · moves{_t12 _t17} · makes List$List$Int
  let _t19 = call concat _t18  ; Δ{_t18} · makes List
        let _t1 = call filter p ys  ; Δ{} · makes List
        let _t1 = call intersperse sep ys  ; Δ{} · makes List
      let _t1 = call map f ys  ; Δ{} · makes List
          let _t1 = call zipWith f as_ bs  ; Δ{} · makes List
  let _t1 = con Cons 2 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
      let _t1 = con Nil  ; Δ{}
      let _t1 = con Nil  ; Δ{_t0}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
      let _t1 = rtcall axion_strcat "\n" _t0  ; Δ{}
          let _t1 = rtcall axion_strcat " " _t0  ; Δ{}
  let _t20 = call sum _t19  ; Δ{_t19}
  let _t21 = + _t10 _t20  ; Δ{}
  let _t22 = closure lam$2  ; Δ{} · makes heap
  let _t23 = con Nil  ; Δ{_t22} · makes List$Int
  let _t24 = con Cons 3 _t23  ; Δ{_t22 _t23} · moves{_t23} · makes List$Int
  let _t25 = con Cons 2 _t24  ; Δ{_t22 _t24} · moves{_t24} · makes List$Int
  let _t26 = con Cons 1 _t25  ; Δ{_t22 _t25} · moves{_t25} · makes List$Int
  let _t27 = con Nil  ; Δ{_t22 _t26} · makes List$Int
  let _t28 = con Cons 40 _t27  ; Δ{_t22 _t26 _t27} · moves{_t27} · makes List$Int
  let _t29 = con Cons 30 _t28  ; Δ{_t22 _t26 _t28} · moves{_t28} · makes List$Int
      let _t2 = call partition p ys  ; Δ{}
    let _t2 = call rangeFused _t1 hi c n  ; Δ{}
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
        let _t2 = call take _t1 ys  ; Δ{} · makes List
  let _t2 = con Cons 1 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
      let _t2 = con Cons y _t1  ; Δ{_t0}
      let _t2 = if _t0 then
  let _t30 = con Cons 20 _t29  ; Δ{_t22 _t26 _t29} · moves{_t29} · makes List$Int
  let _t31 = con Cons 10 _t30  ; Δ{_t22 _t26 _t30} · moves{_t30} · makes List$Int
  let _t32 = call zipWith _t22 _t26 _t31  ; Δ{_t22 _t26 _t31} · moves{_t22} · makes List
  let _t33 = call sum _t32  ; Δ{_t32}
  let _t34 = + _t21 _t33  ; Δ{}
  let _t35 = closure lam$3  ; Δ{} · makes heap
  let _t36 = con Nil  ; Δ{_t35} · makes List$Int
  let _t37 = con Cons 2 _t36  ; Δ{_t35 _t36} · moves{_t36} · makes List$Int
  let _t38 = con Cons 1 _t37  ; Δ{_t35 _t37} · moves{_t37} · makes List$Int
  let _t39 = con Nil  ; Δ{_t35 _t38} · makes List$Int
          let _t3 = callclo p y  ; Δ{}
  let _t3 = con Nil  ; Δ{_t2} · makes List$Int
  let _t40 = con Cons 6 _t39  ; Δ{_t35 _t38 _t39} · moves{_t39} · makes List$Int
  let _t41 = con Cons 5 _t40  ; Δ{_t35 _t38 _t40} · moves{_t40} · makes List$Int
  let _t42 = call zip _t38 _t41  ; Δ{_t35 _t38 _t41} · moves{_t38 _t41} · makes List
  let _t43 = call map _t35 _t42  ; Δ{_t35 _t42} · moves{_t35} · makes List
  let _t44 = call sum _t43  ; Δ{_t43}
  let _t4 = con Cons 4 _t3  ; Δ{_t2 _t3} · moves{_t3} · makes List$Int
            let _t4 = con Cons y l  ; Δ{}
  let _t5 = con Cons 3 _t4  ; Δ{_t2 _t4} · moves{_t4} · makes List$Int
            let _t5 = con Cons y r  ; Δ{}
  let _t6 = con Nil  ; Δ{_t2 _t5} · makes List$Int
  let _t7 = con Cons 10 _t6  ; Δ{_t2 _t5 _t6} · moves{_t6} · makes List$Int
  let _t8 = call append _t5 _t7  ; Δ{_t2 _t5 _t7} · moves{_t7} · makes List
  let _t9 = call append _t2 _t8  ; Δ{_t2 _t8} · moves{_t8} · makes List
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
        (l, r) ->
main  =
map f xs  =
mapM_ f xs  =
maybe d f m  =
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
not b  =
        Nothing ->
    Nothing ->
    Nothing ->
    Nothing ->
null xs  =
partition p xs  =
rangeFused lo hi c n  =
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
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
  ret * a b  ; Δ{}
      ret b  ; Δ{}
        ret call all p ys  ; Δ{}
        ret call any p ys  ; Δ{}
      ret call append y _t0  ; Δ{_t0} · moves{_t0} · makes List
          ret call catMaybes ys  ; Δ{} · makes List
    ret callclo c lo _t2  ; Δ{}
  ret callclo f _t0  ; Δ{}
      ret callclo f x  ; Δ{}
      ret callclo f x  ; Δ{}
      ret callclo f y _t0  ; Δ{}
      ret callclo g y  ; Δ{}
        ret call drop _t1 ys  ; Δ{} · makes List
        ret call elem x ys  ; Δ{}
        ret call filter p ys  ; Δ{} · makes List
        ret call find p ys  ; Δ{} · makes Maybe
      ret call foldl f _t0 ys  ; Δ{}
          ret call mapM_ f ys  ; Δ{}
  ret call snd eta$1  ; Δ{}
  ret call zipWith _t0 xs ys  ; Δ{_t0} · moves{_t0} · makes List
  ret case e of
  ret case e of
  ret case e of
  ret case m of
  ret case m of
  ret case m of
  ret case p of
      ret case ss of
      ret case _t0 of
      ret case _t2 of
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
      ret case y of
      ret case ys of
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
        ret con Cons sep _t1  ; Δ{_t1} · moves{_t1}
          ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
        ret con Cons y _t1  ; Δ{_t1} · moves{_t1}
      ret con Cons y _t2  ; Δ{}
        ret con Cons y _t2  ; Δ{_t2} · moves{_t2}
        ret con Cons y ys  ; Δ{}
          ret con Cons z _t0  ; Δ{_t0} · moves{_t0}
      ret con Cons z _t0  ; Δ{_t0} · moves{_t0}
        ret con Just y  ; Δ{}
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
      ret con Nil  ; Δ{}
    ret con Nil  ; Δ{} · makes List$Int
      ret con Nothing  ; Δ{}
  ret _d1000000  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret d  ; Δ{}
    ret "false"  ; Δ{}
  ret if b then
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
          ret if _t3 then
  ret if x then
  ret if x then
    ret if y then
    ret n  ; Δ{}
      ret putStr ""  ; Δ{}
  ret rtcall axion_show_float x  ; Δ{}
          ret rtcall axion_strcat s _t1  ; Δ{}
      ret rtcall axion_strcat s _t1  ; Δ{}
  ret showInt x  ; Δ{}
          ret s  ; Δ{}
  ret + _t34 _t44  ; Δ{}
    ret "true"  ; Δ{}
  ret tuple a b  ; Δ{} · makes heap
            ret tuple l _t5  ; Δ{} · makes heap
      ret tuple _t0 _t1  ; Δ{} · makes heap
            ret tuple _t4 r  ; Δ{} · makes heap
    ret == x y  ; Δ{}
    ret ==. x y  ; Δ{}
  ret == x y  ; Δ{}
  ret ==. x y  ; Δ{}
  ret x  ; Δ{}
        ret ys  ; Δ{}
      ret ys  ; Δ{}
      ret + y _t0  ; Δ{}
    ret y  ; Δ{}
      ret z  ; Δ{}
      ret z  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
reverse xs  =
    Right _ ->
    Right _ ->
    Right y ->
show$Bool x  =
show$Float x  =
show$Int x  =
snd p  =
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
