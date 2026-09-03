






        drop y : Integer
        let _t1 = call filter$$isBig ys  ; Δ{y ys} · moves{ys} · makes List$Integer
        ret call filter$$isBig ys  ; Δ{ys} · moves{ys} · makes List$Integer
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$Integer
      drop xs
      drop xs
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Integer _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_bignum_free _dd2  ; Δ{}
      let _t0 = call isBig y  ; Δ{y ys}
      let _t0 = call length ys  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret con Nil  ; Δ{} · makes List$Integer
      ret if _t0 then
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
  drop _t7 : List$Integer
  else
  else
  let _d1000000 = call length _t7  ; Δ{_t7}
  let _d1000000 = rtcall axion_bignum_gt x _t0  ; Δ{_t0}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = rtcall axion_bignum_from_i64 1  ; Δ{} · makes Integer
  let _t0 = rtcall axion_bignum_from_i64 2  ; Δ{} · makes Integer
  let _t1 = rtcall axion_bignum_from_i64 5  ; Δ{_t0} · makes Integer
  let _t2 = rtcall axion_bignum_from_i64 9  ; Δ{_t0 _t1} · makes Integer
  let _t3 = con Nil  ; Δ{_t0 _t1 _t2} · makes List$Integer
  let _t4 = con Cons _t2 _t3  ; Δ{_t0 _t1 _t2 _t3} · moves{_t2 _t3} · makes List$Integer
  let _t5 = con Cons _t1 _t4  ; Δ{_t0 _t1 _t4} · moves{_t1 _t4} · makes List$Integer
  let _t6 = con Cons _t0 _t5  ; Δ{_t0 _t5} · moves{_t0 _t5} · makes List$Integer
  let _t7 = call filter$$isBig _t6  ; Δ{_t6} · moves{_t6} · makes List$Integer
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case xs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Integer _p  =
filter$$isBig xs  =
isBig x  =
length xs  =
main  =
