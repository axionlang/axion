









        let _t1 = call filter$$evenN ys  ; Δ{y ys} · moves{ys} · makes List$Int
        ret call filter$$evenN ys  ; Δ{y ys} · moves{ys} · makes List$Int
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$Int
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call evenN y  ; Δ{y ys}
      let _t0 = call foldr$$hoflam11 z ys  ; Δ{y ys} · moves{ys}
      let _t0 = call sq y  ; Δ{y ys}
      let _t1 = call map$$sq ys  ; Δ{y ys} · moves{ys} · makes List$Int
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret call hoflam11 y _t0  ; Δ{y}
      ret con Cons _t0 _t1  ; Δ{_t1 y} · moves{_t1} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret if _t0 then
      ret z  ; Δ{}
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
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
  ; Δ{y ys}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = mod n 2  ; Δ{}
  let _t1 = con Cons 6 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t2 = con Cons 5 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t3 = con Cons 4 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  let _t4 = con Cons 3 _t3  ; Δ{_t3} · moves{_t3} · makes List$Int
  let _t5 = con Cons 2 _t4  ; Δ{_t4} · moves{_t4} · makes List$Int
  let _t6 = con Cons 1 _t5  ; Δ{_t5} · moves{_t5} · makes List$Int
  let _t7 = call filter$$evenN _t6  ; Δ{_t6} · moves{_t6} · makes List$Int
  let _t8 = call map$$sq _t7  ; Δ{_t7} · moves{_t7} · makes List$Int
  ret * n n  ; Δ{}
  ret + x a  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret call foldr$$hoflam11 0 _t8  ; Δ{_t8} · moves{_t8}
  ret case xs of
  ret case xs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
evenN n  =
filter$$evenN xs  =
foldr$$hoflam11 z xs  =
hoflam11 x a  =
main  =
map$$sq xs  =
sq n  =
