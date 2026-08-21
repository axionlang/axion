











axion_drop_Array _p  =
axion_drop_List$Int _p  =
axion_drop_List _p  =
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
      drop _t0
  drop _t15 : List$Int
      drop _t1 : List
  drop _t25 : List$Int
  drop _t26 : List$Int
  drop _t8 : List$Int
      else
      else
      else
    else
    else
  else
  else
  else
  else
eq$Int x y  =
filter p xs  =
lam$0 [env y]z  =
le$Int x y  =
length xs  =
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
      let _t0 = callclo p y  ; Δ{}
  let _t0 = call eq$Int y z  ; Δ{}
      let _t0 = call le$Int d y  ; Δ{}
      let _t0 = call le$Int y d  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = closure lam$0 y  ; Δ{} · makes heap
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = < x y  ; Δ{}
  let _t10 = con Nil  ; Δ{} · makes List$Int
  let _t11 = con Cons 5 _t10  ; Δ{_t10} · moves{_t10} · makes List$Int
  let _t12 = con Cons 1 _t11  ; Δ{_t11} · moves{_t11} · makes List$Int
  let _t13 = con Cons 4 _t12  ; Δ{_t12} · moves{_t12} · makes List$Int
  let _t14 = con Cons 1 _t13  ; Δ{_t13} · moves{_t13} · makes List$Int
  let _t15 = con Cons 3 _t14  ; Δ{_t14} · moves{_t14} · makes List$Int
  let _t16 = call minOr$Int 100 _t15  ; Δ{_t15}
  let _t17 = + _t9 _t16  ; Δ{}
  let _t18 = con Nil  ; Δ{} · makes List$Int
  let _t19 = con Cons 4 _t18  ; Δ{_t18} · moves{_t18} · makes List$Int
        let _t1 = call filter p ys  ; Δ{} · makes List
      let _t1 = call filter _t0 ys  ; Δ{_t0} · makes List
  let _t1 = con Cons 6 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t20 = con Cons 3 _t19  ; Δ{_t19} · moves{_t19} · makes List$Int
  let _t21 = con Cons 3 _t20  ; Δ{_t20} · moves{_t20} · makes List$Int
  let _t22 = con Cons 3 _t21  ; Δ{_t21} · moves{_t21} · makes List$Int
  let _t23 = con Cons 2 _t22  ; Δ{_t22} · moves{_t22} · makes List$Int
  let _t24 = con Cons 1 _t23  ; Δ{_t23} · moves{_t23} · makes List$Int
  let _t25 = con Cons 1 _t24  ; Δ{_t24} · moves{_t24} · makes List$Int
  let _t26 = call nub$Int _t25  ; Δ{_t25} · makes List$Int
  let _t27 = call length _t26  ; Δ{_t26}
      let _t2 = call nub$Int _t1  ; Δ{_t1} · makes List$Int
  let _t2 = con Cons 2 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t3 = con Cons 9 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  let _t4 = con Cons 5 _t3  ; Δ{_t3} · moves{_t3} · makes List$Int
  let _t5 = con Cons 1 _t4  ; Δ{_t4} · moves{_t4} · makes List$Int
  let _t6 = con Cons 4 _t5  ; Δ{_t5} · moves{_t5} · makes List$Int
  let _t7 = con Cons 1 _t6  ; Δ{_t6} · moves{_t6} · makes List$Int
  let _t8 = con Cons 3 _t7  ; Δ{_t7} · moves{_t7} · makes List$Int
  let _t9 = call maxOr$Int 0 _t8  ; Δ{_t8}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
maxOr$Int d xs  =
minOr$Int d xs  =
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
nub$Int xs  =
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
        ret call filter p ys  ; Δ{} · makes List
        ret call maxOr$Int d ys  ; Δ{}
        ret call maxOr$Int y ys  ; Δ{}
        ret call minOr$Int d ys  ; Δ{}
        ret call minOr$Int y ys  ; Δ{}
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
        ret con Cons y _t1  ; Δ{_t1} · moves{_t1}
      ret con Cons y _t2  ; Δ{_t2} · moves{_t2}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret d  ; Δ{}
      ret d  ; Δ{}
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret + _t17 _t27  ; Δ{}
    ret == x y  ; Δ{}
  ret == x y  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
