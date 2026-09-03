





      drop xs
      drop xs
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call append zs ys  ; Δ{z zs} · moves{zs} · makes List
      let _t0 = call sum ys  ; Δ{}
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret ys  ; Δ{}
    Cons y ys ->
    Cons z zs ->
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
  drop _t9 : List
  else
  else
  let _d1000000 = call sum _t9  ; Δ{_t9}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t1 = con Cons 2 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t2 = con Cons 1 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t3 = con Nil  ; Δ{_t2} · makes List$Int
  let _t4 = con Cons 4 _t3  ; Δ{_t2 _t3} · moves{_t3} · makes List$Int
  let _t5 = con Cons 3 _t4  ; Δ{_t2 _t4} · moves{_t4} · makes List$Int
  let _t6 = con Nil  ; Δ{_t2 _t5} · makes List$Int
  let _t7 = con Cons 10 _t6  ; Δ{_t2 _t5 _t6} · moves{_t6} · makes List$Int
  let _t8 = call append _t5 _t7  ; Δ{_t2 _t5 _t7} · moves{_t5 _t7} · makes List
  let _t9 = call append _t2 _t8  ; Δ{_t2 _t8} · moves{_t2 _t8} · makes List
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case xs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
append xs ys  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
main  =
sum xs  =
