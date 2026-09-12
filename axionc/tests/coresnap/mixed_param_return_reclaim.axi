




      drop _t2 : String
      let _d1000000 = putStrLn _t2  ; Δ{_t2}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = call use2 ""  ; Δ{} · makes String
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{}
    _ ->
    drop _t2 : String
    else
    let $aliascopy0 = rtcall axion_strcat s ""  ; Δ{} · makes String
    let _d1000000 = rtcall axion_strcat "<" _t2  ; Δ{_t2} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t2 = rtcall axion_strcat fallback ">"  ; Δ{} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    ret $aliascopy0  ; Δ{$aliascopy0} · moves{$aliascopy0}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  drop _t0 : String
  drop _t1 : String
  else
  else
  let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call tagOr "none" name  ; Δ{} · makes String
  let _t0 = call use2 "bob"  ; Δ{} · makes String
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = putStrLn _t0  ; Δ{_t0}
  let _t1 = rtcall axion_strcat "|" name  ; Δ{_t0} · makes String
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret case _t1 of
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
tagOr fallback s  =
use2 name  =
