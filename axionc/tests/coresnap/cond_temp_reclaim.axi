





      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret call dn s  ; Δ{} · makes String
    ret call up s  ; Δ{} · makes String
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
  let _rcl2000000 = rtcall axion_strcat "x" _t1  ; Δ{} · makes String
  let _t0 = == c 0  ; Δ{}
  let _t0 = call pick 0 "HI"  ; Δ{} · makes String
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = if _t0 then
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _rcl2000000  ; Δ{_rcl2000000} · moves{_rcl2000000}
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_strcat s s  ; Δ{} · makes String
  ret rtcall axion_substr 0 _t0 s  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
dn s  =
main  =
pick c s  =
up s  =
