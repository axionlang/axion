








              drop _t11 : List$Int
              drop _t13 : String
              let _d1000000 = putStrLn _t13  ; Δ{_t13}
              let _t10 = con Cons 2 _t9  ; Δ{_t8 _t9} · moves{_t9} · makes List$Int
              let _t11 = call app _t8 _t10  ; Δ{_t10 _t8} · moves{_t10 _t8} · makes List$Int
              let _t12 = call length _t11  ; Δ{_t11}
              let _t13 = showInt _t12  ; Δ{} · makes String
              let _t7 = con Nil  ; Δ{} · makes List$Int
              let _t8 = con Cons 1 _t7  ; Δ{_t7} · moves{_t7} · makes List$Int
              let _t9 = con Nil  ; Δ{_t8} · makes List$Int
              ret _d1000000  ; Δ{}
            _ ->
          drop _t5 : String
          let _t4 = call plusOne 1  ; Δ{}
          let _t5 = showInt _t4  ; Δ{} · makes String
          let _t6 = putStrLn _t5  ; Δ{_t5}
          ret case _t6 of
        _ ->
      drop _t2 : String
      drop xs
      drop xs
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call app zs ys  ; Δ{z zs} · moves{zs} · makes List$Int
      let _t0 = call length ys  ; Δ{}
      let _t2 = call orDefault "" "x"  ; Δ{} · makes String
      let _t3 = putStrLn _t2  ; Δ{_t2}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t3 of
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z} · makes List$Int
      ret ys  ; Δ{}
    Cons y ys ->
    Cons z zs ->
    Nil ->
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
    ret d  ; Δ{}
    ret s  ; Δ{}
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
  drop _t0 : String
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = call ident "ok"  ; Δ{} · makes String
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = putStrLn _t0  ; Δ{_t0}
  ret + x 1  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case _t1 of
  ret case xs of
  ret case xs of
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret x  ; Δ{}
app xs ys  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
ident x  =
length xs  =
main  =
orDefault d s  =
plusOne x  =
