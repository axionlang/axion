







          drop _t11 : String
          drop _t9 : List$Int
          let _d1000000 = putStrLn _t11  ; Δ{_t11}
          let _t10 = call sumList _t9  ; Δ{_t9}
          let _t11 = showInt _t10  ; Δ{} · makes String
          let _t6 = con Nil  ; Δ{} · makes List$Int
          let _t7 = con Cons -3 _t6  ; Δ{_t6} · moves{_t6} · makes List$Int
          let _t8 = con Cons -2 _t7  ; Δ{_t7} · moves{_t7} · makes List$Int
          let _t9 = con Cons -1 _t8  ; Δ{_t8} · moves{_t8} · makes List$Int
          ret _d1000000  ; Δ{}
        _ ->
      drop _t4 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call sumList t  ; Δ{}
      let _t3 = call compose$$inc$$dbl 5  ; Δ{}
      let _t4 = showInt _t3  ; Δ{} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
      ret + h _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t5 of
    Cons h t ->
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
  ; Δ{}
  drop _t1 : String
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = - a 3  ; Δ{}
  let _t0 = call dbl x  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  let a = 10  ; Δ{}
  ret * x 2  ; Δ{}
  ret + x 1  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call inc _t0  ; Δ{}
  ret case _t2 of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
compose$$inc$$dbl x  =
dbl x  =
inc x  =
main  =
sumList xs  =
