






      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret a  ; Δ{}
    R a b ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : R
  drop _t1 : String
  else
  let _d1000000 = putStrLn _t1  ; Δ{_t1}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call getName r  ; Δ{}
  let _t0 = call sample  ; Δ{} · makes R
  let _t0 = rtcall axion_strcat "foo" ""  ; Δ{} · makes String
  let _t1 = call getName r  ; Δ{}
  let _t1 = call useBoth _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "bar" ""  ; Δ{_t0} · makes String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case r of
  ret con R _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes R
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_strcat _t0 _t1  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_R _p  =
getName r  =
main  =
sample  =
useBoth r  =
