




      drop o
      drop o
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret d  ; Δ{}
      ret x  ; Δ{x} · moves{x}
    None ->
    Some x ->
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
  else
  else
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = con None  ; Δ{} · makes Opt$Int
  let _t1 = call unwrap 5 _t0  ; Δ{_t0} · moves{_t0}
  let _t2 = con None  ; Δ{} · makes Opt$Int
  let _t3 = call unwrap 0 _t2  ; Δ{_t2} · moves{_t2}
  ret + _t1 _t3  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case o of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Opt$Int _p  =
main  =
unwrap d o  =
