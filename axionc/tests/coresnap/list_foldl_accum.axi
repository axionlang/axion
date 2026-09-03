





      drop xs
      drop xs
      drop y : Integer
      drop z : Integer
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Integer _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_bignum_free _dd2  ; Δ{}
      let _t0 = call addI z y  ; Δ{y ys} · makes Integer
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret call foldlI _t0 ys  ; Δ{_t0 ys} · moves{_t0 ys} · makes Integer
      ret z  ; Δ{}
    Cons y ys ->
    Nil ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
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
  drop _t1 : Integer
  drop _t14 : Integer
  drop _t15 : String
  drop _t2 : Integer
  drop _t4 : Integer
  drop _t5 : Integer
  drop _t7 : Integer
  drop _t8 : Integer
  else
  else
  let _d1000000 = putStrLn _t15  ; Δ{_t15}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = rtcall axion_bignum_from_i64 0  ; Δ{} · makes Integer
  let _t1 = rtcall axion_bignum_from_i64 1000000000000  ; Δ{_t0} · makes Integer
  let _t10 = con Nil  ; Δ{_t0 _t3 _t6 _t9} · makes List$Integer
  let _t11 = con Cons _t9 _t10  ; Δ{_t0 _t10 _t3 _t6 _t9} · moves{_t10 _t9} · makes List$Integer
  let _t12 = con Cons _t6 _t11  ; Δ{_t0 _t11 _t3 _t6} · moves{_t11 _t6} · makes List$Integer
  let _t13 = con Cons _t3 _t12  ; Δ{_t0 _t12 _t3} · moves{_t12 _t3} · makes List$Integer
  let _t14 = call foldlI _t0 _t13  ; Δ{_t0 _t13} · moves{_t0 _t13} · makes Integer
  let _t15 = rtcall axion_bignum_to_string _t14  ; Δ{_t14} · makes String
  let _t2 = rtcall axion_bignum_from_i64 1  ; Δ{_t0 _t1} · makes Integer
  let _t3 = rtcall axion_bignum_add _t1 _t2  ; Δ{_t0 _t1 _t2} · makes Integer
  let _t4 = rtcall axion_bignum_from_i64 2000000000000  ; Δ{_t0 _t3} · makes Integer
  let _t5 = rtcall axion_bignum_from_i64 2  ; Δ{_t0 _t3 _t4} · makes Integer
  let _t6 = rtcall axion_bignum_add _t4 _t5  ; Δ{_t0 _t3 _t4 _t5} · makes Integer
  let _t7 = rtcall axion_bignum_from_i64 3000000000000  ; Δ{_t0 _t3 _t6} · makes Integer
  let _t8 = rtcall axion_bignum_from_i64 3  ; Δ{_t0 _t3 _t6 _t7} · makes Integer
  let _t9 = rtcall axion_bignum_add _t7 _t8  ; Δ{_t0 _t3 _t6 _t7 _t8} · makes Integer
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_add a b  ; Δ{} · makes Integer
addI a b  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Integer _p  =
foldlI z xs  =
main  =
