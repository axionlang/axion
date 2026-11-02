









          drop _t11 : List$Int
          drop _t13 : String
          let _d1000000 = putStrLn _t13  ; Δ{_t13}
          let _t10 = con Cons -2 _t9  ; Δ{_t9} · moves{_t9} · makes List$Int
          let _t11 = con Cons -1 _t10  ; Δ{_t10} · moves{_t10} · makes List$Int
          let _t12 = call sumList _t11  ; Δ{_t11}
          let _t13 = showInt _t12  ; Δ{} · makes String
          let _t8 = con Nil  ; Δ{} · makes List$Int
          let _t9 = con Cons -3 _t8  ; Δ{_t8} · moves{_t8} · makes List$Int
          ret _d1000000  ; Δ{}
        _ ->
      drop _t3
      drop _t4
      drop _t6 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call sumList t  ; Δ{}
      let _t3 = closure lam$0  ; Δ{} · makes heap
      let _t4 = closure lam$1  ; Δ{_t3} · makes heap
      let _t5 = call compose _t3 _t4 5  ; Δ{_t3 _t4}
      let _t6 = showInt _t5  ; Δ{} · makes String
      let _t7 = putStrLn _t6  ; Δ{_t6}
      ret + h _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t7 of
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
  let _t0 = callclo g x  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  let a = 10  ; Δ{}
  ret * x 2  ; Δ{}
  ret + x 1  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call dbl eta$3  ; Δ{}
  ret call inc eta$1  ; Δ{}
  ret callclo f _t0  ; Δ{}
  ret case _t2 of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
compose f g x  =
dbl x  =
inc x  =
lam$0 [env ]eta$1  =
lam$1 [env ]eta$3  =
main  =
sumList xs  =
