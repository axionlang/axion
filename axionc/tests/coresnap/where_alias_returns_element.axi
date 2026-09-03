





      drop _t5
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Box _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_free _dd2  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret b  ; Δ{}
      ret con Box 0  ; Δ{} · makes Box
      ret n  ; Δ{}
    Box n ->
    Cons b rest ->
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
  ; Δ{_t5}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = con Box 5  ; Δ{} · makes Box
  let _t1 = con Box 6  ; Δ{_t0} · makes Box
  let _t2 = con Nil  ; Δ{_t0 _t1} · makes List$Box
  let _t3 = con Cons _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t1 _t2} · makes List$Box
  let _t4 = con Cons _t0 _t3  ; Δ{_t0 _t3} · moves{_t0 _t3} · makes List$Box
  let _t5 = call headBox _t4  ; Δ{_t4} · moves{_t4} · makes Box
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call headBox$go xs  ; Δ{}
  ret case _t5 of
  ret case ys of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Box _p  =
headBox xs  =
headBox$go ys  =
main  =
