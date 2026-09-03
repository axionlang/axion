







        let _t1 = call count$Int x ys  ; Δ{}
        ret + 1 _t1  ; Δ{}
        ret call count$Int x ys  ; Δ{}
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call eq$Int x y  ; Δ{}
      ret * w h  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret if _t0 then
      ret r  ; Δ{}
    Circle r ->
    Cons y ys ->
    Nil ->
    Rect w h ->
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
    ret 100  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t10 : Shape
  drop _t13 : Shape
  drop _t14 : Shape
  drop _t5 : List$Int
  drop _t7 : Shape
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = call size$Shape a  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t1 = call size$Shape b  ; Δ{}
  let _t1 = con Cons 2 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t10 = con Rect 3 4  ; Δ{} · makes Shape
  let _t11 = call size$Shape _t10  ; Δ{_t10}
  let _t12 = + _t9 _t11  ; Δ{}
  let _t13 = con Circle 12  ; Δ{} · makes Shape
  let _t14 = con Rect 3 4  ; Δ{_t13} · makes Shape
  let _t15 = call eq$Shape _t13 _t14  ; Δ{_t13 _t14}
  let _t16 = if _t15 then
  let _t2 = con Cons 3 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t3 = con Cons 2 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  let _t4 = con Cons 2 _t3  ; Δ{_t3} · moves{_t3} · makes List$Int
  let _t5 = con Cons 1 _t4  ; Δ{_t4} · moves{_t4} · makes List$Int
  let _t6 = call count$Int 2 _t5  ; Δ{_t5}
  let _t7 = con Circle 10  ; Δ{} · makes Shape
  let _t8 = call size$Shape _t7  ; Δ{_t7}
  let _t9 = + _t6 _t8  ; Δ{}
  ret + _t12 _t16  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret == x y  ; Δ{}
  ret call eq$Int _t0 _t1  ; Δ{}
  ret case s of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
count$Int x xs  =
eq$Int x y  =
eq$Shape a b  =
main  =
size$Shape s  =
