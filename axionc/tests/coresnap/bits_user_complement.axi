






      drop _t6 : List$Int
      drop _t8 : String
      let _d1000000 = putStrLn _t8  ; Δ{_t8}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t3 = con Nil  ; Δ{} · makes List$Int
      let _t4 = con Cons 3 _t3  ; Δ{_t3} · moves{_t3} · makes List$Int
      let _t5 = con Cons 2 _t4  ; Δ{_t4} · moves{_t4} · makes List$Int
      let _t6 = con Cons 1 _t5  ; Δ{_t5} · moves{_t5} · makes List$Int
      let _t7 = call popCount _t6  ; Δ{_t6}
      let _t8 = showInt _t7  ; Δ{} · makes String
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{}
    Cons y ys ->
    Nil ->
    _ ->
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1 : String
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = call complement 1  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret - 100 x  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call length xs  ; Δ{}
  ret case _t2 of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
complement x  =
length xs  =
main  =
popCount xs  =
