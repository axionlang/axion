











addI a b  =
axion_drop_Array _p  =
axion_drop_List$Integer _p  =
axion_drop_List$Int _p  =
axion_drop_List _p  =
    Cons y ys ->
    Cons y ys ->
  drop _t1
  drop _t4 : Integer
  drop _t5 : String
      drop xs
      drop xs
      drop xs
      drop xs : List$Int
      drop y : Integer
      drop z : Integer
    else
    else
    else
  else
  else
  else
  else
  else
  else
foldl$$addI z xs  =
lam$0 [env ]eta$1  =
  let _d1000000 = putStrLn _t5  ; Δ{_t5}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Integer _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
      let _dd3 = rtcall axion_bignum_free _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = call addI z y  ; Δ{y ys} · makes Integer
      let _t0 = callclo f y  ; Δ{y ys} · moves{y}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = rtcall axion_bignum_from_i64 0  ; Δ{} · makes Integer
      let _t1 = call map$Int f ys  ; Δ{ys} · moves{ys} · makes List
  let _t1 = closure lam$0  ; Δ{_t0} · makes heap
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t2 = + acc lo  ; Δ{}
    let _t2 = callclo c lo n  ; Δ{}
  let _t2 = call range 1 5  ; Δ{_t0 _t1} · makes List$Int
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
  let _t3 = call map$Int _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t2} · makes List$Integer
  let _t4 = call foldl$$addI _t0 _t3  ; Δ{_t0 _t3} · moves{_t0 _t3} · makes Integer
  let _t5 = rtcall axion_bignum_to_string _t4  ; Δ{_t4} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
map$Int f xs  =
    Nil ->
    Nil ->
rangeFused lo hi c n  =
rangeFusedSum lo hi acc  =
range lo hi  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
    ret acc  ; Δ{}
      ret call foldl$$addI _t0 ys  ; Δ{_t0 ys} · moves{_t0 ys} · makes Integer
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
  ret case xs of
  ret case xs of
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Nil  ; Δ{}
    ret con Nil  ; Δ{} · makes List$Int
  ret _d1000000  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
    ret n  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_add a b  ; Δ{} · makes Integer
  ret rtcall axion_bignum_from_i64 eta$1  ; Δ{} · makes Integer
      ret z  ; Δ{}
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
