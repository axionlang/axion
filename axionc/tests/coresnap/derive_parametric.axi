





      drop _t0 : String
      drop _t1 : String
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t0 = rtcall axion_strcat "Some" " "  ; Δ{} · makes String
      let _t1 = call showArg$Color a0  ; Δ{_t0} · makes String
      ret "Blue"  ; Δ{}
      ret "Green"  ; Δ{}
      ret "None"  ; Δ{}
      ret "Red"  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    Blue ->
    Green ->
    None ->
    Red ->
    Some a0 ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
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
  drop _t1 : Option$Color
  drop _t2 : String
  else
  else
  let _d1000000 = putStrLn _t2  ; Δ{_t2}
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = con Green  ; Δ{}
  let _t1 = con Some _t0  ; Δ{} · makes Option$Color
  let _t2 = call show$Option$Color _t1  ; Δ{_t1} · makes String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case x of
  ret case x of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Option$Color _p  =
main  =
show$Option$Color x  =
showArg$Color x  =
