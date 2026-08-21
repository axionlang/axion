




axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Opt _p  =
  drop _t1 : Opt
  drop _t3 : Opt
    else
    else
  else
  else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = rtcall axion_free _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = field a q  ; Δ{}
  let _t0 = record P { a = 10 b = 5}  ; Δ{} · makes P
  let _t1 = con Some _t0  ; Δ{_t0} · moves{_t0} · makes Opt
      let _t1 = field b q  ; Δ{}
  let _t2 = call val _t1  ; Δ{_t1}
  let _t3 = con None  ; Δ{} · makes Opt
  let _t4 = call val _t3  ; Δ{_t3}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
    None ->
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
  ret case o of
  ret rtcall axion_array_free _p  ; Δ{}
      ret + _t0 _t1  ; Δ{}
  ret + _t2 _t4  ; Δ{}
    Some q ->
val o  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
