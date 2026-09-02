









    (a, b) ->
axion_drop_Array _p  =
axion_drop_List$Integer _p  =
axion_drop_List$tuple$Integer$Integer _p  =
axion_drop_List _p  =
axion_drop_tuple$Integer$Integer _p  =
big  =
    Cons y ys ->
    Cons y ys ->
      drop a : Integer
      drop b : Integer
      drop t
      drop _t0 : Integer
  drop _t0 : Integer
  drop _t10 : Integer
  drop _t11 : String
  drop _t1 : Integer
      drop xs
      drop xs
      drop xs
      drop xs
      drop y : Integer
    else
    else
    else
  else
  else
  else
  let _d1000000 = putStrLn _t11  ; Δ{_t11}
      let _d1000000 = rtcall axion_bignum_add a b  ; Δ{} · makes Integer
  let _d1000000 = rtcall axion_bignum_add _t0 _t1  ; Δ{_t0 _t1} · makes Integer
      let _d1000000 = rtcall axion_bignum_add y _t0  ; Δ{_t0 y} · makes Integer
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List$Integer _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple$Integer$Integer _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd1 = rtcall axion_bignum_free _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
      let _dd3 = rtcall axion_bignum_free _dd2  ; Δ{}
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
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call big  ; Δ{} · makes Integer
      let _t0 = call sndSum y  ; Δ{y ys} · moves{y} · makes Integer
      let _t0 = call sumL ys  ; Δ{y ys} · moves{ys} · makes Integer
  let _t0 = rtcall axion_bignum_from_i64 1000000000000  ; Δ{} · makes Integer
  let _t10 = call sumL _t9  ; Δ{_t9} · moves{_t9} · makes Integer
  let _t11 = rtcall axion_bignum_to_string _t10  ; Δ{_t10} · makes String
  let _t1 = call big  ; Δ{_t0} · makes Integer
      let _t1 = call map$$sndSum ys  ; Δ{_t0 ys} · moves{ys} · makes List$Integer
  let _t1 = rtcall axion_bignum_from_i64 1  ; Δ{_t0} · makes Integer
  let _t2 = tuple _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes heap
  let _t3 = call big  ; Δ{_t2} · makes Integer
  let _t4 = call big  ; Δ{_t2 _t3} · makes Integer
  let _t5 = tuple _t3 _t4  ; Δ{_t2 _t3 _t4} · moves{_t3 _t4} · makes heap
  let _t6 = con Nil  ; Δ{_t2 _t5} · makes List$tuple$Integer$Integer
  let _t7 = con Cons _t5 _t6  ; Δ{_t2 _t5 _t6} · moves{_t5 _t6} · makes List$tuple$Integer$Integer
  let _t8 = con Cons _t2 _t7  ; Δ{_t2 _t7} · moves{_t2 _t7} · makes List$tuple$Integer$Integer
  let _t9 = call map$$sndSum _t8  ; Δ{_t8} · moves{_t8} · makes List$Integer
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
map$$sndSum xs  =
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
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case t of
  ret case xs of
  ret case xs of
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$Integer
      ret con Nil  ; Δ{} · makes List$Integer
  ret _d1000000  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret rtcall axion_array_free _p  ; Δ{}
      ret rtcall axion_bignum_from_i64 0  ; Δ{} · makes Integer
sndSum t  =
sumL xs  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
