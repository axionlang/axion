

















































        _ ->
all p xs  =
any p xs  =
append xs ys  =
axion_drop_List$Int _p  =
axion_drop_List _p  =
catMaybes xs  =
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
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
drop n xs  =
  drop _t0
      drop _t0 : List
  drop _t0 : List
  drop _t0 : List$Int
  drop _t1 : List$Int
  drop _t3 : List$Int
  drop _t4 : List$Int
  drop _t6 : List$Int
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
lam$2 [env ]x acc  =
le$Float x y  =
le$Int x y  =
    Left _ ->
    Left _ ->
    Left x ->
length xs  =
  let a = call sum _t0  ; Δ{_t0}
  let c = call length _t1  ; Δ{_t1}
      let _d1000000 = call append _t0 _t2  ; Δ{_t0} · makes List
  let _d1000000 = call concat _t0  ; Δ{_t0} · makes List
  let _d1000000 = call maybe d _t0 m  ; Δ{_t0}
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
  let g = call foldr _t2 1 _t3  ; Δ{_t2 _t3} · moves{_t2}
  let h = if _t5 then
  let i = if _t7 then
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
  let _t0 = call range 1 11  ; Δ{} · makes List$Int
      let _t0 = call reverse ys  ; Δ{} · makes List
      let _t0 = call sum ys  ; Δ{}
      let _t0 = call unlines ss  ; Δ{}
          let _t0 = call unwords ss  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = closure lam$1  ; Δ{} · makes heap
      let _t0 = con Nil  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = == x y  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = <. x y  ; Δ{}
  let _t10 = + _t9 h  ; Δ{}
        let _t1 = call filter p ys  ; Δ{} · makes List
        let _t1 = call intersperse sep ys  ; Δ{} · makes List
      let _t1 = call map f ys  ; Δ{} · makes List
  let _t1 = call range 1 11  ; Δ{} · makes List$Int
          let _t1 = call zipWith f as bs  ; Δ{} · makes List
      let _t1 = con Nil  ; Δ{}
      let _t1 = con Nil  ; Δ{_t0}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
      let _t1 = rtcall axion_strcat "\n" _t0  ; Δ{}
          let _t1 = rtcall axion_strcat " " _t0  ; Δ{}
      let _t2 = call partition p ys  ; Δ{}
    let _t2 = call rangeFused _t1 hi c n  ; Δ{}
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
        let _t2 = call take _t1 ys  ; Δ{} · makes List
  let _t2 = closure lam$2  ; Δ{} · makes heap
      let _t2 = con Cons y _t1  ; Δ{_t0}
      let _t2 = if _t0 then
          let _t3 = callclo p y  ; Δ{}
  let _t3 = call range 1 6  ; Δ{_t2} · makes List$Int
  let _t4 = call range 1 0  ; Δ{} · makes List$Int
            let _t4 = con Cons y l  ; Δ{}
  let _t5 = call null _t4  ; Δ{_t4}
            let _t5 = con Cons y r  ; Δ{}
  let _t6 = call range 1 1  ; Δ{} · makes List$Int
  let _t7 = call null _t6  ; Δ{_t6}
  let _t8 = + a c  ; Δ{}
  let _t9 = + _t8 g  ; Δ{}
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
    ret 7  ; Δ{}
    ret 7  ; Δ{}
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
  ret call zipWith _t0 xs ys  ; Δ{_t0} · moves{_t0} · makes List
  ret case e of
  ret case e of
  ret case e of
  ret case m of
  ret case m of
  ret case m of
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
  ret + _t10 i  ; Δ{}
    ret "true"  ; Δ{}
  ret tuple a b  ; Δ{} · makes heap
            ret tuple l _t5  ; Δ{} · makes heap
      ret tuple _t0 _t1  ; Δ{} · makes heap
            ret tuple _t4 r  ; Δ{} · makes heap
  ret * x acc  ; Δ{}
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
