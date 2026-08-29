









axion_drop_Array _p  =
axion_drop_List$Int _p  =
axion_drop_List _p  =
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
  drop _t0
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      else
    else
    else
  else
  else
evenN n  =
filter$$evenN xs  =
foldr$Int f z xs  =
lam$0 [env ]x a  =
  let _d1000000 = call foldr$Int _t0 0 _t9  ; Δ{_t0 _t9} · moves{_t9}
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
      let _t0 = call evenN y  ; Δ{y ys}
      let _t0 = call foldr$Int f z ys  ; Δ{y ys} · moves{ys}
      let _t0 = call sq y  ; Δ{y ys}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = mod n 2  ; Δ{}
        let _t1 = call filter$$evenN ys  ; Δ{y ys} · moves{ys} · makes List$Int
      let _t1 = call map$$sq ys  ; Δ{y ys} · moves{ys} · makes List$Int
  let _t1 = con Nil  ; Δ{_t0} · makes List$Int
  let _t2 = con Cons 6 _t1  ; Δ{_t0 _t1} · moves{_t1} · makes List$Int
  let _t3 = con Cons 5 _t2  ; Δ{_t0 _t2} · moves{_t2} · makes List$Int
  let _t4 = con Cons 4 _t3  ; Δ{_t0 _t3} · moves{_t3} · makes List$Int
  let _t5 = con Cons 3 _t4  ; Δ{_t0 _t4} · moves{_t4} · makes List$Int
  let _t6 = con Cons 2 _t5  ; Δ{_t0 _t5} · moves{_t5} · makes List$Int
  let _t7 = con Cons 1 _t6  ; Δ{_t0 _t6} · moves{_t6} · makes List$Int
  let _t8 = call filter$$evenN _t7  ; Δ{_t0 _t7} · moves{_t7} · makes List$Int
  let _t9 = call map$$sq _t8  ; Δ{_t0 _t8} · moves{_t8} · makes List$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
map$$sq xs  =
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
      ret callclo f y _t0  ; Δ{y} · moves{y}
        ret call filter$$evenN ys  ; Δ{y ys} · moves{ys} · makes List$Int
  ret case xs of
  ret case xs of
  ret case xs of
      ret con Cons _t0 _t1  ; Δ{_t1 y} · moves{_t1} · makes List$Int
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
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
  ; Δ{y ys}
