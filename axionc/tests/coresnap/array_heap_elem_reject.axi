








      drop xs
      drop xs
      drop xs
      drop xs : List$Int
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call append$Int zs ys  ; Δ{z zs} · moves{zs} · makes List$Int
      let _t0 = call length ys  ; Δ{}
      let _t0 = call reverse$Int ys  ; Δ{y ys} · moves{ys} · makes List$Int
      let _t1 = con Nil  ; Δ{_t0 y}
      let _t2 = con Cons y _t1  ; Δ{_t0 y} · moves{y}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret call append$Int _t0 _t2  ; Δ{_t0} · moves{_t0} · makes List$Int
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Nil  ; Δ{}
      ret ys  ; Δ{}
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : List$Int
  drop _t2 : List$Int
  drop _t5 : List$Int
  drop a : Array
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = + n 1  ; Δ{}
  let _t0 = call mk 1  ; Δ{} · makes List$Int
  let _t1 = con Nil  ; Δ{} · makes List$Int
  let _t1 = rtcall axion_array_get a 0  ; Δ{a}
  let _t2 = call reverse$Int _t1  ; Δ{a} · makes List$Int
  let _t2 = con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t3 = call length _t2  ; Δ{_t2 a}
  let _t4 = rtcall axion_array_get a 1  ; Δ{a}
  let _t5 = call reverse$Int _t4  ; Δ{} · makes List$Int
  let _t6 = call length _t5  ; Δ{_t5}
  let a = call fill 3 _t0  ; Δ{_t0} · makes Array
  ret + _t3 _t6  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Cons n _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  ret newArray n x  ; Δ{} · makes Array
  ret rtcall axion_array_free _p  ; Δ{}
append$Int xs ys  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
fill n x  =
length xs  =
main  =
mk n  =
reverse$Int xs  =
