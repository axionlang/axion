
































        _ ->
append xs ys  =
axion_drop_List _p  =
checksum buf  =
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
encrypt buf  =
eq$Bool x y  =
eq$Float x y  =
eq$Int x y  =
filter p xs  =
foldl f z xs  =
foldr f z xs  =
lam$0 [env ]a b  =
lam$1 [env ]_op0 _op1  =
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
      let _t0 = call foldr f z ys  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call reverse ys  ; Δ{} · makes List
      let _t0 = call sum ys  ; Δ{}
      let _t0 = call unlines ss  ; Δ{}
          let _t0 = call unwords ss  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = closure lam$1  ; Δ{} · makes heap
  let _t0 = > lo hi  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = == x y  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = <. x y  ; Δ{}
        let _t1 = call filter p ys  ; Δ{} · makes List
      let _t1 = call map f ys  ; Δ{} · makes List
          let _t1 = call zipWith f as bs  ; Δ{} · makes List
      let _t1 = con Nil  ; Δ{_t0} · makes List
    let _t1 = + lo 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
      let _t1 = rtcall axion_strcat "\n" _t0  ; Δ{}
          let _t1 = rtcall axion_strcat " " _t0  ; Δ{}
    let _t2 = call range _t1 hi  ; Δ{} · makes List
        let _t2 = call take _t1 ys  ; Δ{} · makes List
      let _t2 = con Cons y _t1  ; Δ{_t0 _t1} · moves{_t1} · makes List
    let _tag = loadraw _p+0  ; Δ{}
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
      ret + 1 _t0  ; Δ{}
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
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List
          ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List
        ret con Cons y _t1  ; Δ{_t1} · moves{_t1} · makes List
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
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret "false"  ; Δ{}
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
  ret + _op0 _op1  ; Δ{}
      ret putStr ""  ; Δ{}
  ret rtcall axion_buf_xor buf 90  ; Δ{}
  ret rtcall axion_fold_bytes _t0 0 buf  ; Δ{_t0} · moves{_t0}
  ret rtcall axion_show_float x  ; Δ{}
          ret rtcall axion_strcat s _t1  ; Δ{}
      ret rtcall axion_strcat s _t1  ; Δ{}
  ret showInt x  ; Δ{}
          ret s  ; Δ{}
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
