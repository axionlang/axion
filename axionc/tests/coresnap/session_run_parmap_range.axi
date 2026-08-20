







































































        _ ->
        (a, b) ->
        (a, b) ->
    (a, b) ->
all p xs  =
and xs  =
any p xs  =
append xs ys  =
axion_drop_Array _p  =
axion_drop_List$Int _p  =
axion_drop_List$String _p  =
axion_drop_List _p  =
axion_drop_Maybe$Int _p  =
catMaybes xs  =
compose f g x  =
concatMap f xs  =
concat xs  =
    Cons a as_ ->
        Cons b bs ->
consFst y ab  =
    Cons p ps ->
    Cons p ps ->
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
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
      drop ab
drop n xs  =
  drop _t0
  drop _t0
          drop _t0 : String
      drop _t0 : String
        drop _t1 : Maybe$Int
          drop _t1 : String
      drop _t1 : String
  drop _t2 : List$Int
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
  else
  else
  else
  else
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
fib n  =
filter p xs  =
findIndex p xs  =
find p xs  =
foldl f z xs  =
foldr f z xs  =
fromMaybe d m  =
incMaybe m  =
intercalate sep xss  =
intersperse sep xs  =
isJust m  =
isLeft e  =
isNothing m  =
isRight e  =
    Just _ ->
    Just _ ->
    Just i ->
    Just x ->
        Just z ->
lam$0 [env ]a b  =
lam$1 [env ]x  =
le$Float x y  =
le$Int x y  =
    Left _ ->
    Left _ ->
    Left x ->
length xs  =
        let _d1000000 = call incMaybe _t1  ; Δ{_t1} · makes Maybe$Int
  let _d1000000 = call maybe d _t0 m  ; Δ{_t0}
  let _d1000000 = call sum _t2  ; Δ{_t2}
  let _d1000000 = call zipWith _t0 xs ys  ; Δ{_t0} · makes List
      let _d1000000 = rtcall axion_strcat s _t1  ; Δ{_t1} · makes String
          let _d1000000 = rtcall axion_strcat s _t1  ; Δ{_t1 s t ts} · makes String
  let _dd0 = band _p 1  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd1 = if _dd0 then
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
          let _t0 = == a k  ; Δ{}
          let _t0 = == a k  ; Δ{}
      let _t0 = call append zs ys  ; Δ{z zs} · moves{zs} · makes List
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
      let _t0 = callclo p y  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = call concat ys  ; Δ{y ys} · moves{ys} · makes List
      let _t0 = call foldr f z ys  ; Δ{}
  let _t0 = call intersperse sep xss  ; Δ{} · makes List
      let _t0 = call length ys  ; Δ{}
  let _t0 = call map f xs  ; Δ{} · makes List
      let _t0 = call null ys  ; Δ{y ys}
      let _t0 = call product ys  ; Δ{}
  let _t0 = call range 15 22  ; Δ{} · makes List$Int
      let _t0 = call reverse ys  ; Δ{y ys} · moves{ys} · makes List
      let _t0 = call sum ys  ; Δ{}
      let _t0 = call unlines ss  ; Δ{} · makes String
          let _t0 = call unwords ss  ; Δ{s ss t ts} · moves{ss} · makes String
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = closure lam$1  ; Δ{} · makes heap
      let _t0 = con Cons y a  ; Δ{}
      let _t0 = con Nil  ; Δ{}
      let _t0 = con Nil  ; Δ{}
      let _t0 = con Nil  ; Δ{}
      let _t0 = + i 1  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = < n 1  ; Δ{}
  let _t0 = < n 1  ; Δ{}
  let _t0 = < n 2  ; Δ{}
      let _t0 = == x y  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = <. x y  ; Δ{}
        let _t1 = call filter p ys  ; Δ{} · makes List
        let _t1 = call findIndex p ys  ; Δ{} · makes Maybe$Int
        let _t1 = call intersperse sep ys  ; Δ{y ys} · moves{ys} · makes List
      let _t1 = call map f ys  ; Δ{} · makes List
        let _t1 = call takeWhile p ys  ; Δ{} · makes List
          let _t1 = call zipWith f as_ bs  ; Δ{} · makes List
      let _t1 = con Nil  ; Δ{}
      let _t1 = con Nil  ; Δ{}
      let _t1 = con Nil  ; Δ{}
      let _t1 = con Nil  ; Δ{_t0 y}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
    let _t1 = - n 1  ; Δ{}
    let _t1 = - n 1  ; Δ{}
      let _t1 = rtcall axion_strcat "\n" _t0  ; Δ{_t0} · makes String
          let _t1 = rtcall axion_strcat " " _t0  ; Δ{_t0 s t ts} · makes String
  let _t1 = &worker$step  ; Δ{_t0}
    let _t2 = + acc lo  ; Δ{}
    let _t2 = callclo c lo n  ; Δ{}
      let _t2 = callclo p y  ; Δ{}
    let _t2 = call fib _t1  ; Δ{}
      let _t2 = call partition p ys  ; Δ{}
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
    let _t2 = call replicate _t1 x  ; Δ{} · makes List
        let _t2 = call take _t1 ys  ; Δ{} · makes List
      let _t2 = con Cons y _t1  ; Δ{_t0 y} · moves{y}
      let _t2 = if _t0 then
      let _t2 = < n 1  ; Δ{}
  let _t2 = rtcall axion_par_map _t1 48 16 _t0  ; Δ{_t0} · moves{_t0} · makes List
          let _t3 = callclo p y  ; Δ{}
        let _t3 = call span p ys  ; Δ{}
        let _t3 = con Nil  ; Δ{}
    let _t3 = - n 2  ; Δ{}
    let _t4 = call fib _t3  ; Δ{}
            let _t4 = con Cons y l  ; Δ{}
        let _t4 = con Cons y ys  ; Δ{}
        let _t4 = con Nil  ; Δ{}
            let _t5 = con Cons y r  ; Δ{}
        let _t5 = con Cons y ys  ; Δ{}
        let _t5 = - n 1  ; Δ{}
        let _t6 = call splitAt _t5 ys  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
lookup$Int k xs  =
lookup k xs  =
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
    Nothing ->
null xs  =
or xs  =
partition p xs  =
product xs  =
rangeFused lo hi c n  =
rangeFusedSum lo hi acc  =
range lo hi  =
replicate n x  =
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
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret acc  ; Δ{}
        ret call all p ys  ; Δ{}
        ret call and ys  ; Δ{}
        ret call any p ys  ; Δ{}
      ret call append _t0 _t2  ; Δ{_t0} · moves{_t0} · makes List
      ret call append y _t0  ; Δ{_t0 y} · moves{_t0 y} · makes List
          ret call catMaybes ys  ; Δ{} · makes List
  ret callclo f _t0  ; Δ{}
      ret callclo f x  ; Δ{}
      ret callclo f x  ; Δ{}
      ret callclo f y _t0  ; Δ{}
      ret callclo g y  ; Δ{}
  ret call concat _t0  ; Δ{_t0} · moves{_t0} · makes List
  ret call concat _t0  ; Δ{_t0} · moves{_t0} · makes List
        ret call consFst y _t3  ; Δ{}
        ret call consFst y _t6  ; Δ{}
        ret call drop _t1 ys  ; Δ{} · makes List
        ret call elem x ys  ; Δ{}
        ret call filter p ys  ; Δ{} · makes List
        ret call find p ys  ; Δ{} · makes Maybe
      ret call foldl f _t0 ys  ; Δ{}
            ret call lookup$Int k ps  ; Δ{} · makes Maybe
            ret call lookup$Int k ps  ; Δ{} · makes Maybe
          ret call mapM_ f ys  ; Δ{}
        ret call or ys  ; Δ{}
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
  ret case ab of
  ret case e of
  ret case e of
  ret case e of
  ret case m of
  ret case m of
  ret case m of
  ret case m of
      ret case p of
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
        ret con Cons sep _t1  ; Δ{_t1 y} · moves{_t1}
          ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
    ret con Cons x _t2  ; Δ{_t2} · moves{_t2}
        ret con Cons y _t1  ; Δ{_t1} · moves{_t1}
        ret con Cons y _t1  ; Δ{_t1} · moves{_t1}
        ret con Cons y _t2  ; Δ{_t2} · moves{_t2}
      ret con Cons y _t2  ; Δ{y} · moves{y}
        ret con Cons y ys  ; Δ{}
          ret con Cons z _t0  ; Δ{_t0} · moves{_t0}
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
        ret con Just 0  ; Δ{} · makes Maybe$Int
            ret con Just b  ; Δ{}
            ret con Just b  ; Δ{}
      ret con Just _t0  ; Δ{} · makes Maybe$Int
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
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
    ret con Nil  ; Δ{}
    ret con Nil  ; Δ{} · makes List$Int
      ret con Nothing  ; Δ{}
      ret con Nothing  ; Δ{}
      ret con Nothing  ; Δ{}
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret con Nothing  ; Δ{} · makes Maybe$Int
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
          ret _d1000000  ; Δ{_d1000000 s t ts} · moves{_d1000000}
      ret d  ; Δ{}
    ret "false"  ; Δ{}
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
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
      ret if _t2 then
      ret if _t2 then
          ret if _t3 then
  ret if x then
  ret if x then
  ret if x then
      ret if y then
      ret if y then
    ret if y then
    ret n  ; Δ{}
    ret n  ; Δ{}
      ret putStr ""  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_to_string x  ; Δ{} · makes String
  ret rtcall axion_bignum_to_string x  ; Δ{} · makes String
  ret rtcall axion_show_float x  ; Δ{} · makes String
  ret rtcall axion_show_float x  ; Δ{} · makes String
  ret showInt x  ; Δ{} · makes String
  ret showInt x  ; Δ{} · makes String
          ret s  ; Δ{s ss} · moves{s}
    ret + _t2 _t4  ; Δ{}
    ret "true"  ; Δ{}
    ret "true"  ; Δ{}
  ret tuple a b  ; Δ{} · makes heap
            ret tuple l _t5  ; Δ{} · makes heap
      ret tuple _t0 b  ; Δ{} · makes heap
      ret tuple _t0 _t1  ; Δ{} · makes heap
      ret tuple _t0 _t1  ; Δ{} · makes heap
      ret tuple _t0 _t1  ; Δ{} · makes heap
        ret tuple _t3 _t4  ; Δ{} · makes heap
            ret tuple _t4 r  ; Δ{} · makes heap
        ret tuple _t4 _t5  ; Δ{} · makes heap
    ret == x y  ; Δ{}
    ret ==. x y  ; Δ{}
  ret == x y  ; Δ{}
  ret ==. x y  ; Δ{}
  ret x  ; Δ{}
      ret ys  ; Δ{}
        ret ys  ; Δ{y ys} · moves{ys}
      ret * y _t0  ; Δ{}
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
show$Integer x  =
show$Int x  =
showArg$Bool x  =
showArg$Float x  =
showArg$Integer x  =
showArg$Int x  =
span p xs  =
splitAt n xs  =
sum xs  =
take n xs  =
takeWhile p xs  =
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{s ss}
  ; Δ{y ys}
