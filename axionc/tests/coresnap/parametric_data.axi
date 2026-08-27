






axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Maybe$Int _p  =
      drop m
      drop m
  drop _t0
    else
  else
  else
fromMaybe d m  =
    Just x ->
lam$0 [env ]x  =
  let _d1000000 = call maybe d _t0 m  ; Δ{_t0}
  let _dd0 = band _p 1  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd1 = if _dd0 then
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = con Just 42  ; Δ{} · makes Maybe$Int
  let _t1 = call fromMaybe 0 _t0  ; Δ{_t0} · moves{_t0}
  let _t2 = con Nothing  ; Δ{} · makes Maybe$Int
  let _t3 = call fromMaybe 7 _t2  ; Δ{_t2} · moves{_t2}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
maybe d f m  =
    Nothing ->
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
      ret callclo f x  ; Δ{x} · moves{x}
  ret case m of
  ret _d1000000  ; Δ{}
      ret d  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret + _t1 _t3  ; Δ{}
  ret x  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
