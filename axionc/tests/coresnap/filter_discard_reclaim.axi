






        drop y : Integer
        let _t2 = call keepBig ys  ; Δ{y ys} · moves{ys} · makes List$Integer
        ret call keepBig ys  ; Δ{ys} · moves{ys} · makes List$Integer
        ret con Cons y _t2  ; Δ{_t2 y} · moves{_t2 y} · makes List$Integer
      drop _t0 : Integer
      drop _t0 : Integer
      drop xs
      drop xs
      drop xs
      drop xs
      drop y : Integer
      else
      let _d1000000 = rtcall axion_bignum_add y _t0  ; Δ{_t0 y} · makes Integer
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Integer _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_bignum_free _dd2  ; Δ{}
      let _t0 = call big  ; Δ{y ys} · makes Integer
      let _t0 = call sumL ys  ; Δ{y ys} · moves{ys} · makes Integer
      let _t1 = rtcall axion_bignum_gt y _t0  ; Δ{_t0 y ys}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret con Nil  ; Δ{} · makes List$Integer
      ret if _t1 then
      ret rtcall axion_bignum_from_i64 0  ; Δ{} · makes Integer
    Cons y ys ->
    Cons y ys ->
    Nil ->
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
  ; Δ{y ys}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : Integer
  drop _t1 : Integer
  drop _t12 : Integer
  drop _t13 : String
  drop _t4 : Integer
  drop _t5 : Integer
  else
  else
  let _d1000000 = putStrLn _t13  ; Δ{_t13}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = rtcall axion_bignum_from_i64 2000000000000  ; Δ{} · makes Integer
  let _t1 = rtcall axion_bignum_from_i64 2  ; Δ{_t0} · makes Integer
  let _t10 = con Cons _t2 _t9  ; Δ{_t2 _t9} · moves{_t2 _t9} · makes List$Integer
  let _t11 = call keepBig _t10  ; Δ{_t10} · moves{_t10} · makes List$Integer
  let _t12 = call sumL _t11  ; Δ{_t11} · moves{_t11} · makes Integer
  let _t13 = rtcall axion_bignum_to_string _t12  ; Δ{_t12} · makes String
  let _t2 = rtcall axion_bignum_add _t0 _t1  ; Δ{_t0 _t1} · makes Integer
  let _t3 = rtcall axion_bignum_from_i64 5  ; Δ{_t2} · makes Integer
  let _t4 = rtcall axion_bignum_from_i64 3000000000000  ; Δ{_t2 _t3} · makes Integer
  let _t5 = rtcall axion_bignum_from_i64 3  ; Δ{_t2 _t3 _t4} · makes Integer
  let _t6 = rtcall axion_bignum_add _t4 _t5  ; Δ{_t2 _t3 _t4 _t5} · makes Integer
  let _t7 = con Nil  ; Δ{_t2 _t3 _t6} · makes List$Integer
  let _t8 = con Cons _t6 _t7  ; Δ{_t2 _t3 _t6 _t7} · moves{_t6 _t7} · makes List$Integer
  let _t9 = con Cons _t3 _t8  ; Δ{_t2 _t3 _t8} · moves{_t3 _t8} · makes List$Integer
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case xs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_from_i64 1000000000000  ; Δ{} · makes Integer
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Integer _p  =
big  =
keepBig xs  =
main  =
sumL xs  =
