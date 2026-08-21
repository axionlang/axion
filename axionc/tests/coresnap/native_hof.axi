











axion_drop_Array _p  =
axion_drop_List$Int _p  =
axion_drop_List _p  =
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
  drop _t0
  drop _t1
  drop _t10 : List$Int
  drop _t11 : List$Int
  drop _t2
  drop _t9 : List$Int
      else
    else
    else
  else
  else
evenN n  =
filter p xs  =
foldr f z xs  =
lam$0 [env ]x a  =
lam$1 [env ]eta$1  =
lam$2 [env ]eta$3  =
  let _d1000000 = call foldr _t0 0 _t11  ; Δ{_t0 _t11}
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
      let _t0 = callclo f y  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = call foldr f z ys  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = mod n 2  ; Δ{}
  let _t10 = call filter _t2 _t9  ; Δ{_t0 _t1 _t2 _t9} · makes List$Int
  let _t11 = call map _t1 _t10  ; Δ{_t0 _t1 _t10} · makes List$Int
        let _t1 = call filter p ys  ; Δ{} · makes List
      let _t1 = call map f ys  ; Δ{} · makes List
  let _t1 = closure lam$1  ; Δ{_t0} · makes heap
  let _t2 = closure lam$2  ; Δ{_t0 _t1} · makes heap
  let _t3 = con Nil  ; Δ{_t0 _t1 _t2} · makes List$Int
  let _t4 = con Cons 6 _t3  ; Δ{_t0 _t1 _t2 _t3} · moves{_t3} · makes List$Int
  let _t5 = con Cons 5 _t4  ; Δ{_t0 _t1 _t2 _t4} · moves{_t4} · makes List$Int
  let _t6 = con Cons 4 _t5  ; Δ{_t0 _t1 _t2 _t5} · moves{_t5} · makes List$Int
  let _t7 = con Cons 3 _t6  ; Δ{_t0 _t1 _t2 _t6} · moves{_t6} · makes List$Int
  let _t8 = con Cons 2 _t7  ; Δ{_t0 _t1 _t2 _t7} · moves{_t7} · makes List$Int
  let _t9 = con Cons 1 _t8  ; Δ{_t0 _t1 _t2 _t8} · moves{_t8} · makes List$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
map f xs  =
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
      ret callclo f y _t0  ; Δ{}
  ret call evenN eta$3  ; Δ{}
        ret call filter p ys  ; Δ{} · makes List
  ret call sq eta$1  ; Δ{}
  ret case xs of
  ret case xs of
  ret case xs of
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
        ret con Cons y _t1  ; Δ{_t1} · moves{_t1}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
  ret _d1000000  ; Δ{}
      ret if _t0 then
  ret * n n  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret + x a  ; Δ{}
      ret z  ; Δ{}
sq n  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
