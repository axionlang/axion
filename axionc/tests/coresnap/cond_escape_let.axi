



      drop _t2 : String
      let _d1000000 = putStrLn _t2  ; Δ{_t2}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = call pick 0  ; Δ{} · makes String
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{}
    _ ->
    drop s : String
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "short"  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret s  ; Δ{s} · moves{s}
  ; Δ{s}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call pick 1000000  ; Δ{} · makes String
  let _t0 = rtcall axion_str_len s  ; Δ{s}
  let _t1 = > _t0 n  ; Δ{s}
  let _t1 = putStrLn _t0  ; Δ{_t0}
  let s = rtcall axion_getenv "COND_VAR"  ; Δ{} · makes String
  ret 0  ; Δ{}
  ret case _t1 of
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
pick n  =
