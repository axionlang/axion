

















      drop _t0 : Integer
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs : List$Int
      drop xs : List$Integer
      drop y
      drop y : Integer
      let _d1000000 = call addI y _t0  ; Δ{_t0 y} · makes Integer
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Box _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Integer _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_bignum_free _dd2  ; Δ{}
      let _dd3 = rtcall axion_free _dd2  ; Δ{}
      let _t0 = call foldr$$addI z ys  ; Δ{y ys} · moves{ys} · makes Integer
      let _t0 = call unbox y  ; Δ{y ys} · makes Integer
      let _t0 = callclo f y  ; Δ{y ys} · moves{y}
      let _t0 = callclo f y  ; Δ{y ys} · moves{y}
      let _t1 = call map$$unbox ys  ; Δ{_t0 ys} · moves{ys} · makes List$Integer
      let _t1 = call map$Int f ys  ; Δ{ys} · moves{ys} · makes List
      let _t1 = call map$Integer f ys  ; Δ{ys} · moves{ys} · makes List
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$Integer
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{} · makes List$Integer
      ret i  ; Δ{}
      ret z  ; Δ{}
    Box i ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    else
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
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
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1
  drop _t2
  drop _t7 : Integer
  drop _t8 : String
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = putStrLn _t8  ; Δ{_t8}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = rtcall axion_bignum_from_i64 0  ; Δ{} · makes Integer
  let _t1 = closure lam$0  ; Δ{_t0} · makes heap
  let _t2 = closure lam$1  ; Δ{_t0 _t1} · makes heap
  let _t3 = call range 1 5  ; Δ{_t0 _t1 _t2} · makes List$Int
  let _t4 = call map$Int _t2 _t3  ; Δ{_t0 _t1 _t2 _t3} · moves{_t3} · makes List$Integer
  let _t5 = call map$Integer _t1 _t4  ; Δ{_t0 _t1 _t4} · moves{_t4} · makes List$Box
  let _t6 = call map$$unbox _t5  ; Δ{_t0 _t5} · moves{_t5} · makes List$Integer
  let _t7 = call foldr$$addI _t0 _t6  ; Δ{_t0 _t6} · moves{_t0 _t6} · makes Integer
  let _t8 = rtcall axion_bignum_to_string _t7  ; Δ{_t7} · makes String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call hoflam10 eta$1  ; Δ{} · makes Box
  ret case b of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Box x  ; Δ{} · makes Box
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_add a b  ; Δ{} · makes Integer
  ret rtcall axion_bignum_from_i64 eta$3  ; Δ{} · makes Integer
addI a b  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Box _p  =
axion_drop_List$Int _p  =
axion_drop_List$Integer _p  =
foldr$$addI z xs  =
hoflam10 x  =
lam$0 [env ]eta$1  =
lam$1 [env ]eta$3  =
main  =
map$$unbox xs  =
map$Int f xs  =
map$Integer f xs  =
range lo hi  =
rangeFused lo hi c n  =
rangeFusedSum lo hi acc  =
unbox b  =
