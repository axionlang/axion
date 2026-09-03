





        ret call maxOr$Float d ys  ; Δ{}
        ret call maxOr$Float y ys  ; Δ{}
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Float _dd0  ; Δ{}
      let _t0 = call le$Float d y  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret d  ; Δ{}
      ret if _t0 then
    Cons y ys ->
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
    ret 1  ; Δ{}
    ret ==. x y  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t3 : List$Float
  else
  else
  else
  let _d1000000 = call maxOr$Float 0f _t3  ; Δ{_t3}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = <. x y  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Float
  let _t1 = con Cons 2f _t0  ; Δ{_t0} · moves{_t0} · makes List$Float
  let _t2 = con Cons 7f _t1  ; Δ{_t1} · moves{_t1} · makes List$Float
  let _t3 = con Cons 3f _t2  ; Δ{_t2} · moves{_t2} · makes List$Float
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case xs of
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Float _p  =
le$Float x y  =
main  =
maxOr$Float d xs  =
