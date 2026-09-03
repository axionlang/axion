









      drop xs
      drop xs
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call dbl y  ; Δ{y ys}
      let _t0 = call sumList ys  ; Δ{}
      let _t1 = call map$$dbl ys  ; Δ{y ys} · moves{ys} · makes List$Int
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret con Cons _t0 _t1  ; Δ{_t1 y} · moves{_t1} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
    Cons y ys ->
    Cons y ys ->
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
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t2 = + acc lo  ; Δ{}
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
    let _t2 = callclo c lo n  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret acc  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
    ret con Nil  ; Δ{} · makes List$Int
    ret n  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t3 : List$Int
  drop _t6 : List$Int
  else
  else
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t1 = con Cons 3 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t2 = con Cons 2 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t3 = con Cons 1 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  let _t4 = call sumList _t3  ; Δ{_t3}
  let _t5 = call range 1 4  ; Δ{} · makes List$Int
  let _t6 = call map$$dbl _t5  ; Δ{_t5} · moves{_t5} · makes List$Int
  let _t7 = call sumList _t6  ; Δ{_t6}
  ret + _t4 _t7  ; Δ{}
  ret + x x  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case xs of
  ret case xs of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
dbl x  =
main  =
map$$dbl xs  =
range lo hi  =
rangeFused lo hi c n  =
rangeFusedSum lo hi acc  =
sumList xs  =
