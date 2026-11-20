










      drop _t0
      drop _t0
      drop _t1
      drop _t1
      drop _t2
      drop _t2
      drop _t2
      drop _t2
      drop v : String
      drop v : String
      drop v : String
      drop v$1 : String
      let _d1000000 = rtcall axion_strcat v ""  ; Δ{v} · makes String
      let _d1000000 = rtcall axion_strcat v ""  ; Δ{v} · makes String
      let _d1000000 = rtcall axion_strcat v$1 ""  ; Δ{v$1} · makes String
      let _d1000001 = rtcall axion_strcat v ""  ; Δ{v} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
      let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret rtcall axion_strcat "" ""  ; Δ{} · makes String
      ret rtcall axion_strcat "" ""  ; Δ{} · makes String
      ret rtcall axion_strcat "" ""  ; Δ{} · makes String
      ret rtcall axion_strcat "-" ""  ; Δ{} · makes String
      ret rtcall axion_strcat "none" ""  ; Δ{} · makes String
      ret rtcall axion_strcat v ""  ; Δ{} · makes String
    Just v ->
    Just v ->
    Just v$1 ->
    Left v ->
    Nothing ->
    Nothing ->
    Nothing ->
    Right k ->
    Tagged v k ->
    Untagged ->
    else
    else
    else
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd2 = == _tag 0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = showInt n  ; Δ{} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
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
    ret con Left _t1  ; Δ{_t1} · moves{_t1} · makes Either$String$Int
    ret con Right n  ; Δ{} · makes Either$String$Int
  ; Δ{_t0}
  ; Δ{_t1}
  ; Δ{_t2}
  ; Δ{_t2}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  drop _t2 : Either$String$Int
  drop _t3 : String
  drop s : String
  drop s : String
  drop s : String
  else
  else
  else
  else
  else
  else
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 0  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _rcl2000000 = rtcall axion_str_len s  ; Δ{}
  let _rcl2000001 = rtcall axion_str_len _t3  ; Δ{}
  let _t0 = > n 3  ; Δ{}
  let _t0 = call fromMaybe 1234  ; Δ{}
  let _t0 = con Just "s1"  ; Δ{} · makes Maybe$String
  let _t0 = showInt n  ; Δ{} · makes String
  let _t0 = showInt n  ; Δ{} · makes String
  let _t1 = call fromEither 7  ; Δ{}
  let _t1 = case _t0 of
  let _t1 = con Just _t0  ; Δ{_t0} · moves{_t0} · makes Maybe$String
  let _t1 = rtcall axion_strcat "t" _t0  ; Δ{_t0} · makes String
  let _t2 = + _t0 _t1  ; Δ{}
  let _t2 = con Just _t1  ; Δ{} · makes Maybe$String
  let _t2 = con Tagged _t1 n  ; Δ{_t1} · moves{_t1} · makes Tagged
  let _t2 = if _t0 then
  let _t2 = rtcall axion_str_len s  ; Δ{}
  let _t3 = call fromEither 2  ; Δ{}
  let _t3 = case _t2 of
  let _t3 = rtcall axion_str_len s  ; Δ{}
  let _t3 = rtcall axion_str_len s  ; Δ{}
  let _t4 = + _t2 _t3  ; Δ{}
  let _t4 = rtcall axion_str_at 0 s  ; Δ{}
  let _t5 = call fromData 42  ; Δ{}
  let _t6 = + _t4 _t5  ; Δ{}
  let _t7 = call nested  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let s = case _t1 of
  let s = case _t2 of
  let s = case _t2 of
  ret + _t2 _t3  ; Δ{}
  ret + _t3 _t4  ; Δ{}
  ret + _t6 _t7  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _rcl2000000  ; Δ{}
  ret _rcl2000001  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_Either$String _p  =
axion_drop_Either$String$Int _p  =
axion_drop_List _p  =
axion_drop_Maybe$String _p  =
axion_drop_Tagged _p  =
fromData n  =
fromEither n  =
fromMaybe n  =
main  =
nested  =
