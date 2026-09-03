





















        let _t1 = call count$$big ys  ; Δ{}
        let _t1 = call filter p ys  ; Δ{} · makes List
        ret + 1 _t1  ; Δ{}
        ret call count$$big ys  ; Δ{}
        ret call filter p ys  ; Δ{} · makes List
        ret call maximumByOr$$gti d ys  ; Δ{}
        ret call maximumByOr$$gti y ys  ; Δ{}
        ret call minimumByOr$$lti d ys  ; Δ{}
        ret call minimumByOr$$lti y ys  ; Δ{}
        ret con Cons y _t1  ; Δ{_t1} · moves{_t1}
      drop _t0
      drop xs
      drop xs
      drop ys : List$Int
      else
      else
      else
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call add z y  ; Δ{}
      let _t0 = call big y  ; Δ{}
      let _t0 = call gti y d  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call lti y d  ; Δ{}
      let _t0 = call sum ys  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = closure lam$0 y  ; Δ{y ys} · makes heap
      let _t1 = call filter _t0 ys  ; Δ{_t0 y ys} · makes List$Int
      let _t2 = call nubBy$$eqi _t1  ; Δ{_t1 y} · moves{_t1} · makes List$Int
      ret + 1 _t0  ; Δ{}
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret call scanl$$add _t0 ys  ; Δ{} · makes List$Int
      ret call scanl$$add y ys  ; Δ{} · makes List$Int
      ret con Cons y _t2  ; Δ{_t2 y} · moves{_t2 y} · makes List$Int
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret d  ; Δ{}
      ret d  ; Δ{}
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t10 : List$Int
  drop _t16 : List$Int
  drop _t22 : List$Int
  drop _t23 : List$Int
  drop _t30 : List$Int
  drop _t33 : String
  drop _t5 : List$Int
  else
  else
  else
  let _d1000000 = putStrLn _t33  ; Δ{_t33}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = call eqi y z  ; Δ{}
  let _t0 = call scanlGo$$add z xs  ; Δ{} · makes List$Int
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t1 = con Cons 1 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t10 = con Cons 3 _t9  ; Δ{_t9} · moves{_t9} · makes List$Int
  let _t11 = call maximumByOr$$gti 0 _t10  ; Δ{_t10}
  let _t12 = + _t6 _t11  ; Δ{}
  let _t13 = con Nil  ; Δ{} · makes List$Int
  let _t14 = con Cons 5 _t13  ; Δ{_t13} · moves{_t13} · makes List$Int
  let _t15 = con Cons 9 _t14  ; Δ{_t14} · moves{_t14} · makes List$Int
  let _t16 = con Cons 3 _t15  ; Δ{_t15} · moves{_t15} · makes List$Int
  let _t17 = call minimumByOr$$lti 100 _t16  ; Δ{_t16}
  let _t18 = + _t12 _t17  ; Δ{}
  let _t19 = con Nil  ; Δ{} · makes List$Int
  let _t2 = con Cons 2 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t20 = con Cons 3 _t19  ; Δ{_t19} · moves{_t19} · makes List$Int
  let _t21 = con Cons 2 _t20  ; Δ{_t20} · moves{_t20} · makes List$Int
  let _t22 = con Cons 1 _t21  ; Δ{_t21} · moves{_t21} · makes List$Int
  let _t23 = call scanl1$$add _t22  ; Δ{_t22} · makes List$Int
  let _t24 = call sum _t23  ; Δ{_t23}
  let _t25 = + _t18 _t24  ; Δ{}
  let _t26 = con Nil  ; Δ{} · makes List$Int
  let _t27 = con Cons 2 _t26  ; Δ{_t26} · moves{_t26} · makes List$Int
  let _t28 = con Cons 9 _t27  ; Δ{_t27} · moves{_t27} · makes List$Int
  let _t29 = con Cons 5 _t28  ; Δ{_t28} · moves{_t28} · makes List$Int
  let _t3 = con Cons 1 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  let _t30 = con Cons 1 _t29  ; Δ{_t29} · moves{_t29} · makes List$Int
  let _t31 = call count$$big _t30  ; Δ{_t30}
  let _t32 = + _t25 _t31  ; Δ{}
  let _t33 = call show$Int _t32  ; Δ{} · makes String
  let _t4 = con Cons 1 _t3  ; Δ{_t3} · moves{_t3} · makes List$Int
  let _t5 = call nubBy$$eqi _t4  ; Δ{_t4} · moves{_t4} · makes List$Int
  let _t6 = call length _t5  ; Δ{_t5}
  let _t7 = con Nil  ; Δ{} · makes List$Int
  let _t8 = con Cons 5 _t7  ; Δ{_t7} · moves{_t7} · makes List$Int
  let _t9 = con Cons 9 _t8  ; Δ{_t8} · moves{_t8} · makes List$Int
  ret + a b  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret < a b  ; Δ{}
  ret == a b  ; Δ{}
  ret > a b  ; Δ{}
  ret > n 3  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call not _t0  ; Δ{}
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Cons z _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
add a b  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
big n  =
count$$big xs  =
eqi a b  =
filter p xs  =
gti a b  =
lam$0 [env y]z  =
length xs  =
lti a b  =
main  =
maximumByOr$$gti d xs  =
minimumByOr$$lti d xs  =
not b  =
nubBy$$eqi xs  =
scanl$$add z xs  =
scanl1$$add xs  =
scanlGo$$add z xs  =
show$Int x  =
sum xs  =
