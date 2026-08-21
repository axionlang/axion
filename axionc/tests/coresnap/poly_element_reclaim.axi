







axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Lst$Box _p  =
axion_drop_Lst _p  =
    Box n ->
      drop dflt : Box
  drop _t6 : Box
  drop _t8 : String
      drop xs
      drop xs
      drop ys : Lst$Box
    else
    else
    else
  else
  else
  else
headOr dflt xs  =
    LCons y ys ->
  let _d1000000 = putStrLn _t8  ; Δ{_t8}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_Lst$Box _dd0  ; Δ{}
      let _dd1 = call axion_drop_Lst _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
      let _dd3 = rtcall axion_free _dd2  ; Δ{}
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
  let _t0 = con Box 9  ; Δ{} · makes Box
  let _t1 = con Box 1  ; Δ{_t0} · makes Box
  let _t2 = con Box 2  ; Δ{_t0 _t1} · makes Box
  let _t3 = con LNil  ; Δ{_t0 _t1 _t2} · makes Lst$Box
  let _t4 = con LCons _t2 _t3  ; Δ{_t0 _t1 _t2 _t3} · moves{_t2 _t3} · makes Lst$Box
  let _t5 = con LCons _t1 _t4  ; Δ{_t0 _t1 _t4} · moves{_t1 _t4} · makes Lst$Box
  let _t6 = call headOr _t0 _t5  ; Δ{_t0 _t5} · moves{_t0 _t5} · makes Box
  let _t7 = call val _t6  ; Δ{_t6}
  let _t8 = call show$Int _t7  ; Δ{} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    LNil ->
main  =
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
  ret case b of
  ret case xs of
  ret _d1000000  ; Δ{}
      ret dflt  ; Δ{}
      ret n  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
      ret y  ; Δ{y} · moves{y}
show$Int x  =
val b  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
