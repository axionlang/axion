






      drop d : Integer
      drop d : Integer
      drop e
      drop e
      drop e
      drop e
      drop x : Integer
      drop y : Integer
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret d  ; Δ{}
      ret d  ; Δ{}
      ret x  ; Δ{x} · moves{x}
      ret y  ; Δ{y} · moves{y}
    Left x ->
    Left x ->
    Right y ->
    Right y ->
    else
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = rtcall axion_bignum_free _dd0  ; Δ{}
    let _dd1 = rtcall axion_bignum_free _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd5 = rtcall axion_bignum_free _dd4  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t3 : Integer
  drop _t7 : Integer
  drop _t8 : Integer
  drop _t9 : String
  else
  else
  else
  else
  let _d1000000 = putStrLn _t9  ; Δ{_t9}
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = == _tag 0  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = rtcall axion_bignum_from_i64 0  ; Δ{} · makes Integer
  let _t1 = rtcall axion_bignum_from_i64 8  ; Δ{_t0} · makes Integer
  let _t2 = con Left _t1  ; Δ{_t0 _t1} · moves{_t1} · makes Either$Integer$Integer
  let _t3 = call fromLeftI _t0 _t2  ; Δ{_t0 _t2} · moves{_t0 _t2} · makes Integer
  let _t4 = rtcall axion_bignum_from_i64 0  ; Δ{_t3} · makes Integer
  let _t5 = rtcall axion_bignum_from_i64 5  ; Δ{_t3 _t4} · makes Integer
  let _t6 = con Left _t5  ; Δ{_t3 _t4 _t5} · moves{_t5} · makes Either$Integer$Integer
  let _t7 = call fromRightI _t4 _t6  ; Δ{_t3 _t4 _t6} · moves{_t4 _t6} · makes Integer
  let _t8 = rtcall axion_bignum_add _t3 _t7  ; Δ{_t3 _t7} · makes Integer
  let _t9 = rtcall axion_bignum_to_string _t8  ; Δ{_t8} · makes String
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case e of
  ret case e of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_Either$Integer _p  =
axion_drop_Either$Integer$Integer _p  =
axion_drop_List _p  =
fromLeftI d e  =
fromRightI d e  =
main  =
