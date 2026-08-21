
















    (a, b) ->
append$Int xs ys  =
append xs ys  =
axion_drop_Array _p  =
axion_drop_List$Int _p  =
axion_drop_List$List$Int _p  =
axion_drop_List$tuple$Int$Int _p  =
axion_drop_List _p  =
concat$Int xs  =
    Cons a as_ ->
        Cons b bs ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
    Cons z zs ->
  drop _t0
  drop _t19 : List$Int
  drop _t22
  drop _t26 : List$Int
  drop _t31 : List$Int
  drop _t32 : List$Int
  drop _t35
  drop _t38 : List$Int
  drop _t41 : List$Int
  drop _t42 : List$tuple$Int$Int
  drop _t43 : List$Int
  drop _t9 : List
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs : List$List$Int
    else
    else
    else
    else
  else
  else
  else
  else
lam$0 [env ]a b  =
lam$1 [env ]a b  =
lam$2 [env ]eta$1  =
  let _d1000000 = call zipWith _t0 xs ys  ; Δ{_t0} · makes List
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple$Int$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
      let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = call append$Int zs ys  ; Δ{z zs} · moves{zs} · makes List$Int
      let _t0 = call append zs ys  ; Δ{z zs} · moves{zs} · makes List
          let _t0 = callclo f a b  ; Δ{}
      let _t0 = callclo f y  ; Δ{}
      let _t0 = call concat$Int ys  ; Δ{y ys} · moves{ys} · makes List$Int
      let _t0 = call sum ys  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t10 = call sum _t9  ; Δ{_t9}
  let _t11 = con Nil  ; Δ{} · makes List$Int
  let _t12 = con Cons 1 _t11  ; Δ{_t11} · moves{_t11} · makes List$Int
  let _t13 = con Nil  ; Δ{_t12} · makes List$Int
  let _t14 = con Cons 3 _t13  ; Δ{_t12 _t13} · moves{_t13} · makes List$Int
  let _t15 = con Cons 2 _t14  ; Δ{_t12 _t14} · moves{_t14} · makes List$Int
  let _t16 = con Nil  ; Δ{_t12 _t15} · makes List$List$Int
  let _t17 = con Cons _t15 _t16  ; Δ{_t12 _t15 _t16} · moves{_t15 _t16} · makes List$List$Int
  let _t18 = con Cons _t12 _t17  ; Δ{_t12 _t17} · moves{_t12 _t17} · makes List$List$Int
  let _t19 = call concat$Int _t18  ; Δ{_t18} · moves{_t18} · makes List$Int
      let _t1 = call map f ys  ; Δ{} · makes List
          let _t1 = call zipWith f as_ bs  ; Δ{} · makes List
  let _t1 = con Cons 2 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t20 = call sum _t19  ; Δ{_t19}
  let _t21 = + _t10 _t20  ; Δ{}
  let _t22 = closure lam$1  ; Δ{} · makes heap
  let _t23 = con Nil  ; Δ{_t22} · makes List$Int
  let _t24 = con Cons 3 _t23  ; Δ{_t22 _t23} · moves{_t23} · makes List$Int
  let _t25 = con Cons 2 _t24  ; Δ{_t22 _t24} · moves{_t24} · makes List$Int
  let _t26 = con Cons 1 _t25  ; Δ{_t22 _t25} · moves{_t25} · makes List$Int
  let _t27 = con Nil  ; Δ{_t22 _t26} · makes List$Int
  let _t28 = con Cons 40 _t27  ; Δ{_t22 _t26 _t27} · moves{_t27} · makes List$Int
  let _t29 = con Cons 30 _t28  ; Δ{_t22 _t26 _t28} · moves{_t28} · makes List$Int
  let _t2 = con Cons 1 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t30 = con Cons 20 _t29  ; Δ{_t22 _t26 _t29} · moves{_t29} · makes List$Int
  let _t31 = con Cons 10 _t30  ; Δ{_t22 _t26 _t30} · moves{_t30} · makes List$Int
  let _t32 = call zipWith _t22 _t26 _t31  ; Δ{_t22 _t26 _t31} · makes List$Int
  let _t33 = call sum _t32  ; Δ{_t32}
  let _t34 = + _t21 _t33  ; Δ{}
  let _t35 = closure lam$2  ; Δ{} · makes heap
  let _t36 = con Nil  ; Δ{_t35} · makes List$Int
  let _t37 = con Cons 2 _t36  ; Δ{_t35 _t36} · moves{_t36} · makes List$Int
  let _t38 = con Cons 1 _t37  ; Δ{_t35 _t37} · moves{_t37} · makes List$Int
  let _t39 = con Nil  ; Δ{_t35 _t38} · makes List$Int
  let _t3 = con Nil  ; Δ{_t2} · makes List$Int
  let _t40 = con Cons 6 _t39  ; Δ{_t35 _t38 _t39} · moves{_t39} · makes List$Int
  let _t41 = con Cons 5 _t40  ; Δ{_t35 _t38 _t40} · moves{_t40} · makes List$Int
  let _t42 = call zip _t38 _t41  ; Δ{_t35 _t38 _t41} · makes List$tuple$Int$Int
  let _t43 = call map _t35 _t42  ; Δ{_t35 _t42} · makes List$Int
  let _t44 = call sum _t43  ; Δ{_t43}
  let _t4 = con Cons 4 _t3  ; Δ{_t2 _t3} · moves{_t3} · makes List$Int
  let _t5 = con Cons 3 _t4  ; Δ{_t2 _t4} · moves{_t4} · makes List$Int
  let _t6 = con Nil  ; Δ{_t2 _t5} · makes List$Int
  let _t7 = con Cons 10 _t6  ; Δ{_t2 _t5 _t6} · moves{_t6} · makes List$Int
  let _t8 = call append _t5 _t7  ; Δ{_t2 _t5 _t7} · moves{_t5 _t7} · makes List
  let _t9 = call append _t2 _t8  ; Δ{_t2 _t8} · moves{_t2 _t8} · makes List
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
map f xs  =
        Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
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
  ret * a b  ; Δ{}
      ret b  ; Δ{}
      ret call append$Int y _t0  ; Δ{_t0 y} · moves{_t0 y} · makes List$Int
  ret call snd eta$1  ; Δ{}
  ret case p of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
      ret case ys of
          ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
          ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret rtcall axion_array_free _p  ; Δ{}
  ret + _t34 _t44  ; Δ{}
  ret tuple a b  ; Δ{} · makes heap
      ret ys  ; Δ{}
      ret ys  ; Δ{}
      ret + y _t0  ; Δ{}
snd p  =
sum xs  =
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
