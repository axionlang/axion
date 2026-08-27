









addI a b  =
axion_drop_Array _p  =
axion_drop_List$Integer _p  =
axion_drop_List$Int _p  =
axion_drop_List _p  =
    Cons y ys ->
  drop _t0
  drop _t0 : Integer
    drop _t2 : Integer
    drop _t3 : Integer
    drop _t4 : Integer
  drop _t4 : List$Integer
  drop _t5 : Integer
  drop _t6 : String
    else
    else
    else
  else
  else
  else
  else
  else
factorial n  =
foldr f z xs  =
lam$0 [env ]eta$1 eta$2  =
  let _d1000000 = putStrLn _t6  ; Δ{_t6}
    let _d1000000 = rtcall axion_bignum_mul n _t4  ; Δ{_t4} · makes Integer
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
      let _t0 = call foldr f z ys  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = < n 1  ; Δ{}
  let _t0 = rtcall axion_bignum_from_i64 2  ; Δ{} · makes Integer
    let _t1 = - n 1  ; Δ{}
  let _t1 = rtcall axion_bignum_from_i64 0  ; Δ{_t0} · makes Integer
  let _t1 = rtcall axion_bignum_lt n _t0  ; Δ{_t0}
  let _t2 = call replicate 4 20  ; Δ{_t0 _t1} · makes List$Int
    let _t2 = call replicate _t1 x  ; Δ{} · makes List
    let _t2 = rtcall axion_bignum_from_i64 1  ; Δ{} · makes Integer
    let _t3 = rtcall axion_bignum_sub n _t2  ; Δ{_t2} · makes Integer
  let _t3 = &worker$step  ; Δ{_t0 _t1 _t2}
    let _t4 = call factorial _t3  ; Δ{_t3} · makes Integer
  let _t4 = rtcall axion_par_map _t3 48 16 _t2  ; Δ{_t0 _t1 _t2} · moves{_t2} · makes List
  let _t5 = call foldr _t0 _t1 _t4  ; Δ{_t0 _t1 _t4} · moves{_t1} · makes Integer
  let _t6 = rtcall axion_bignum_to_string _t5  ; Δ{_t5} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
    Nil ->
replicate n x  =
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
  ret call addI eta$1 eta$2  ; Δ{} · makes Integer
      ret callclo f y _t0  ; Δ{}
  ret case xs of
    ret con Cons x _t2  ; Δ{_t2} · moves{_t2}
    ret con Nil  ; Δ{}
  ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret if _t0 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_add a b  ; Δ{} · makes Integer
    ret rtcall axion_bignum_from_i64 1  ; Δ{} · makes Integer
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
