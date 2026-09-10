




      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t0 = call val$s  ; Δ{} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    ret "default"  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret _t0  ; Δ{_t0} · moves{_t0}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  drop _t1 : String
  else
  else
  let _d1000000 = putStr _t0  ; Δ{_t0}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call val 0  ; Δ{} · makes String
  let _t1 = call val$s  ; Δ{} · makes String
  let _t2 = rtcall axion_str_len _t1  ; Δ{_t1}
  let _t3 = > _t2 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret if _t3 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_getenv "AXION_WHERE_TEST"  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
val d  =
val$s  =
