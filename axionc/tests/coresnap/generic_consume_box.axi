









      drop xs
      drop xs
      drop xs
      drop xs
      drop xs : List$Box
      drop xs : List$List$Box
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Box _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$List$Box _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_List$Box _dd2  ; Δ{}
      let _dd3 = rtcall axion_free _dd2  ; Δ{}
      let _t0 = call append$Box zs ys  ; Δ{z zs} · moves{zs} · makes List$Box
      let _t0 = call concat$Box ys  ; Δ{y ys} · moves{ys} · makes List$Box
      let _t0 = call reverse$Box ys  ; Δ{y ys} · moves{ys} · makes List$Box
      let _t0 = call val y  ; Δ{}
      let _t1 = call sumB ys  ; Δ{}
      let _t1 = con Nil  ; Δ{_t0 y}
      let _t2 = con Cons y _t1  ; Δ{_t0 y} · moves{y}
      ret + _t0 _t1  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret call append$Box _t0 _t2  ; Δ{_t0} · moves{_t0} · makes List$Box
      ret call append$Box y _t0  ; Δ{_t0 y} · moves{_t0 y} · makes List$Box
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret n  ; Δ{}
      ret ys  ; Δ{}
    Box n ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t12 : List$Box
  else
  else
  else
  let _d1000000 = call sumB _t12  ; Δ{_t12}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _t0 = con Box 1  ; Δ{} · makes Box
  let _t1 = con Box 2  ; Δ{_t0} · makes Box
  let _t10 = con Cons _t8 _t9  ; Δ{_t5 _t8 _t9} · moves{_t8 _t9} · makes List$List$Box
  let _t11 = call concat$Box _t10  ; Δ{_t10 _t5} · moves{_t10} · makes List$Box
  let _t12 = call append$Box _t5 _t11  ; Δ{_t11 _t5} · moves{_t11 _t5} · makes List$Box
  let _t2 = con Nil  ; Δ{_t0 _t1} · makes List$Box
  let _t3 = con Cons _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t1 _t2} · makes List$Box
  let _t4 = con Cons _t0 _t3  ; Δ{_t0 _t3} · moves{_t0 _t3} · makes List$Box
  let _t5 = call reverse$Box _t4  ; Δ{_t4} · moves{_t4} · makes List$Box
  let _t6 = con Box 3  ; Δ{_t5} · makes Box
  let _t7 = con Nil  ; Δ{_t5 _t6} · makes List$Box
  let _t8 = con Cons _t6 _t7  ; Δ{_t5 _t6 _t7} · moves{_t6 _t7} · makes List$Box
  let _t9 = con Nil  ; Δ{_t5 _t8} · makes List$List$Box
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case b of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
append$Box xs ys  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Box _p  =
axion_drop_List$List$Box _p  =
concat$Box xs  =
main  =
reverse$Box xs  =
sumB xs  =
val b  =
