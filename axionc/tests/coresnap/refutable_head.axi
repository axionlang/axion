




        drop _p0
        ret x  ; Δ{x} · moves{x}
      Just x ->
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{_p0}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{_p0}
    Just _ ->
    _ ->
    drop _p0 : Maybe$Int
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
    ret case _p0 of
    ret rtcall axion_contract_fail "runtime error: no clause of 'fromJust' matched the arguments"  ; Δ{}
  ; Δ{_p0}
  ; Δ{_p0}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  else
  else
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = case _p0 of
  let _t0 = con Just 5  ; Δ{} · makes Maybe$Int
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call fromJust _t0  ; Δ{_t0} · moves{_t0}
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Maybe$Int _p  =
fromJust _p0  =
main  =
