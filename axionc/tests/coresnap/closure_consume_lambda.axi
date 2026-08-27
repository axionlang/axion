


















addI a b  =
axion_drop_Array _p  =
axion_drop_List$Box _p  =
axion_drop_List$Integer _p  =
axion_drop_List$Int _p  =
axion_drop_List _p  =
    Box i ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
  drop eta$1 : Integer
  drop eta$2 : Integer
  drop eta$4 : Box
  drop _t0
  drop _t10 : String
  drop _t2
  drop _t3
  drop _t4
  drop _t9 : Integer
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs : List$Box
      drop xs : List$Int
      drop xs : List$Integer
    else
    else
    else
    else
  else
  else
  else
  else
  else
  else
  else
foldr$Integer f z xs  =
lam$0 [env ]eta$1 eta$2  =
lam$1 [env ]eta$4  =
lam$2 [env ]x  =
lam$3 [env ]eta$6  =
  let _d1000000 = call addI eta$1 eta$2  ; Δ{} · makes Integer
  let _d1000000 = call unbox eta$4  ; Δ{} · makes Integer
  let _d1000000 = putStrLn _t10  ; Δ{_t10}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$Box _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Integer _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
      let _dd3 = rtcall axion_bignum_free _dd2  ; Δ{}
      let _dd3 = rtcall axion_free _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = callclo f y  ; Δ{y ys} · moves{y}
      let _t0 = callclo f y  ; Δ{y ys} · moves{y}
      let _t0 = callclo f y  ; Δ{y ys} · moves{y}
      let _t0 = call foldr$Integer f z ys  ; Δ{y ys} · moves{ys}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t10 = rtcall axion_bignum_to_string _t9  ; Δ{_t9} · makes String
      let _t1 = call map$Box f ys  ; Δ{ys} · moves{ys} · makes List
      let _t1 = call map$Integer f ys  ; Δ{ys} · moves{ys} · makes List
      let _t1 = call map$Int f ys  ; Δ{ys} · moves{ys} · makes List
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
  let _t1 = rtcall axion_bignum_from_i64 0  ; Δ{_t0} · makes Integer
    let _t2 = + acc lo  ; Δ{}
    let _t2 = callclo c lo n  ; Δ{}
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
  let _t2 = closure lam$1  ; Δ{_t0 _t1} · makes heap
  let _t3 = closure lam$2  ; Δ{_t0 _t1 _t2} · makes heap
  let _t4 = closure lam$3  ; Δ{_t0 _t1 _t2 _t3} · makes heap
  let _t5 = call range 1 5  ; Δ{_t0 _t1 _t2 _t3 _t4} · makes List$Int
  let _t6 = call map$Int _t4 _t5  ; Δ{_t0 _t1 _t2 _t3 _t4 _t5} · moves{_t5} · makes List$Integer
  let _t7 = call map$Integer _t3 _t6  ; Δ{_t0 _t1 _t2 _t3 _t6} · moves{_t6} · makes List$Box
  let _t8 = call map$Box _t2 _t7  ; Δ{_t0 _t1 _t2 _t7} · moves{_t7} · makes List$Integer
  let _t9 = call foldr$Integer _t0 _t1 _t8  ; Δ{_t0 _t1 _t8} · moves{_t1 _t8} · makes Integer
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
map$Box f xs  =
map$Integer f xs  =
map$Int f xs  =
    Nil ->
    Nil ->
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
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
    ret acc  ; Δ{}
      ret callclo f y _t0  ; Δ{y} · moves{y}
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
  ret case b of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Box x  ; Δ{} · makes Box
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
    ret con Nil  ; Δ{} · makes List$Int
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
      ret i  ; Δ{}
    ret n  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_add a b  ; Δ{} · makes Integer
  ret rtcall axion_bignum_from_i64 eta$6  ; Δ{} · makes Integer
      ret z  ; Δ{}
unbox b  =
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
