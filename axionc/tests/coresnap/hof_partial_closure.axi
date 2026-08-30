






axion_drop_Array _p  =
axion_drop_List$Integer _p  =
axion_drop_List _p  =
    Cons y ys ->
    Cons y ys ->
  drop _t0 : Integer
  drop _t8 : List$Integer
      drop xs
      drop xs
        drop y : Integer
      else
    else
    else
  else
  else
filter$$gt _cap0 xs  =
gt n x  =
length xs  =
  let _d1000000 = call length _t8  ; Δ{_t8}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$Integer _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
      let _dd3 = rtcall axion_bignum_free _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = call gt _cap0 y  ; Δ{y ys}
      let _t0 = call length ys  ; Δ{}
  let _t0 = rtcall axion_bignum_from_i64 2  ; Δ{} · makes Integer
        let _t1 = call filter$$gt _cap0 ys  ; Δ{y ys} · moves{ys} · makes List$Integer
  let _t1 = rtcall axion_bignum_from_i64 1  ; Δ{_t0} · makes Integer
  let _t2 = rtcall axion_bignum_from_i64 5  ; Δ{_t0 _t1} · makes Integer
  let _t3 = rtcall axion_bignum_from_i64 9  ; Δ{_t0 _t1 _t2} · makes Integer
  let _t4 = con Nil  ; Δ{_t0 _t1 _t2 _t3} · makes List$Integer
  let _t5 = con Cons _t3 _t4  ; Δ{_t0 _t1 _t2 _t3 _t4} · moves{_t3 _t4} · makes List$Integer
  let _t6 = con Cons _t2 _t5  ; Δ{_t0 _t1 _t2 _t5} · moves{_t2 _t5} · makes List$Integer
  let _t7 = con Cons _t1 _t6  ; Δ{_t0 _t1 _t6} · moves{_t1 _t6} · makes List$Integer
  let _t8 = call filter$$gt _t0 _t7  ; Δ{_t0 _t7} · moves{_t7} · makes List$Integer
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
    Nil ->
    Nil ->
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
      ret + 1 _t0  ; Δ{}
        ret call filter$$gt _cap0 ys  ; Δ{ys} · moves{ys} · makes List$Integer
  ret case xs of
  ret case xs of
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$Integer
      ret con Nil  ; Δ{} · makes List$Integer
  ret _d1000000  ; Δ{}
      ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_gt x n  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{y ys}
