























add3 a b c  =
add a b  =
axion_drop_Array _p  =
axion_drop_List$Int _p  =
axion_drop_List _p  =
comparing$$dbl x y  =
    Cons a as_ ->
        Cons b bs ->
            Cons c cs ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
dbl n  =
  drop _t0
  drop _t11 : List$Int
  drop _t14 : List$Int
  drop _t15 : List$Int
  drop _t22 : List$Int
  drop _t23 : List$Int
  drop _t29 : List$Int
  drop _t30 : List$Int
  drop _t36
  drop _t37
  drop _t3 : List$Int
  drop _t40 : String
  drop _t4 : List$Int
  drop _t8 : List$Int
elemIndices$Int x xs  =
      else
      else
    else
    else
  else
  else
  else
  else
eq$Int x y  =
findIndices$$isBig xs  =
findIndicesFrom$$isBig i xs  =
findIndicesFrom p i xs  =
isBig n  =
lam$0 [env ]eta$1 eta$2  =
lam$1 [env ]eta$4  =
lam$2 [env x]y  =
le$Int x y  =
  let _d1000000 = call findIndicesFrom _t0 0 xs  ; Δ{_t0} · makes List$Int
  let _d1000000 = putStrLn _t40  ; Δ{_t40}
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
  let _t0 = + a b  ; Δ{}
              let _t0 = call add3 a b c  ; Δ{}
      let _t0 = call add z y  ; Δ{}
  let _t0 = callclo f x  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
  let _t0 = call dbl x  ; Δ{}
      let _t0 = call isBig y  ; Δ{}
  let _t0 = call scanlGo$$add z xs  ; Δ{} · makes List$Int
      let _t0 = call sum ys  ; Δ{}
  let _t0 = closure lam$2 x  ; Δ{} · makes heap
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = < x y  ; Δ{}
  let _t10 = con Cons 20 _t9  ; Δ{_t8 _t9} · moves{_t9} · makes List$Int
  let _t11 = con Cons 10 _t10  ; Δ{_t10 _t8} · moves{_t10} · makes List$Int
  let _t12 = con Nil  ; Δ{_t11 _t8} · makes List$Int
  let _t13 = con Cons 200 _t12  ; Δ{_t11 _t12 _t8} · moves{_t12} · makes List$Int
  let _t14 = con Cons 100 _t13  ; Δ{_t11 _t13 _t8} · moves{_t13} · makes List$Int
  let _t15 = call zipWith3$$add3 _t8 _t11 _t14  ; Δ{_t11 _t14 _t8} · makes List$Int
  let _t16 = call sum _t15  ; Δ{_t15}
  let _t17 = + _t5 _t16  ; Δ{}
  let _t18 = con Nil  ; Δ{} · makes List$Int
  let _t19 = con Cons 2 _t18  ; Δ{_t18} · moves{_t18} · makes List$Int
  let _t1 = callclo f y  ; Δ{}
  let _t1 = call dbl y  ; Δ{}
              let _t1 = call zipWith3$$add3 as_ bs cs  ; Δ{} · makes List$Int
  let _t1 = con Cons 3 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
        let _t1 = + i 1  ; Δ{}
        let _t1 = + i 1  ; Δ{}
  let _t20 = con Cons 9 _t19  ; Δ{_t19} · moves{_t19} · makes List$Int
  let _t21 = con Cons 1 _t20  ; Δ{_t20} · moves{_t20} · makes List$Int
  let _t22 = con Cons 5 _t21  ; Δ{_t21} · moves{_t21} · makes List$Int
  let _t23 = call findIndices$$isBig _t22  ; Δ{_t22} · makes List$Int
  let _t24 = call sum _t23  ; Δ{_t23}
  let _t25 = + _t17 _t24  ; Δ{}
  let _t26 = con Nil  ; Δ{} · makes List$Int
  let _t27 = con Cons 3 _t26  ; Δ{_t26} · moves{_t26} · makes List$Int
  let _t28 = con Cons 1 _t27  ; Δ{_t27} · moves{_t27} · makes List$Int
  let _t29 = con Cons 3 _t28  ; Δ{_t28} · moves{_t28} · makes List$Int
        let _t2 = call findIndicesFrom$$isBig _t1 ys  ; Δ{} · makes List$Int
        let _t2 = call findIndicesFrom p _t1 ys  ; Δ{} · makes List$Int
  let _t2 = con Cons 2 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t30 = call elemIndices$Int 3 _t29  ; Δ{_t29} · makes List$Int
  let _t31 = call sum _t30  ; Δ{_t30}
  let _t32 = + _t25 _t31  ; Δ{}
  let _t33 = call comparing$$dbl 5 2  ; Δ{}
  let _t34 = if _t33 then
  let _t35 = + _t32 _t34  ; Δ{}
  let _t36 = closure lam$0  ; Δ{} · makes heap
  let _t37 = closure lam$1  ; Δ{_t36} · makes heap
  let _t38 = call on _t36 _t37 3 4  ; Δ{_t36 _t37}
  let _t39 = + _t35 _t38  ; Δ{}
  let _t3 = con Cons 1 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
        let _t3 = + i 1  ; Δ{}
        let _t3 = + i 1  ; Δ{}
  let _t40 = call show$Int _t39  ; Δ{} · makes String
  let _t4 = call scanl$$add 0 _t3  ; Δ{_t3} · makes List$Int
  let _t5 = call sum _t4  ; Δ{_t4}
  let _t6 = con Nil  ; Δ{} · makes List$Int
  let _t7 = con Cons 2 _t6  ; Δ{_t6} · moves{_t6} · makes List$Int
  let _t8 = con Cons 1 _t7  ; Δ{_t7} · moves{_t7} · makes List$Int
  let _t9 = con Nil  ; Δ{_t8} · makes List$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
            Nil ->
        Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
on g f x y  =
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
    ret 7  ; Δ{}
  ret + a b  ; Δ{}
  ret call add eta$1 eta$2  ; Δ{}
  ret callclo g _t0 _t1  ; Δ{}
  ret call dbl eta$4  ; Δ{}
  ret call eq$Int x y  ; Δ{}
  ret call findIndicesFrom$$isBig 0 xs  ; Δ{} · makes List$Int
        ret call findIndicesFrom$$isBig _t3 ys  ; Δ{} · makes List$Int
        ret call findIndicesFrom p _t3 ys  ; Δ{} · makes List$Int
  ret call le$Int _t0 _t1  ; Δ{}
      ret call scanl$$add _t0 ys  ; Δ{} · makes List$Int
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
      ret case ys of
          ret case zs of
        ret con Cons i _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
        ret con Cons i _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
              ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  ret con Cons z _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
              ret con Nil  ; Δ{} · makes List$Int
          ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret if _t0 then
      ret if _t0 then
  ret if _t0 then
  ret > n 3  ; Δ{}
  ret + n n  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret + _t0 c  ; Δ{}
    ret == x y  ; Δ{}
  ret == x y  ; Δ{}
      ret + y _t0  ; Δ{}
scanl$$add z xs  =
scanlGo$$add z xs  =
show$Int x  =
sum xs  =
zipWith3$$add3 xs ys zs  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
