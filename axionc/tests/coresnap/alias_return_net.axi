




      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let $aliascopy0 = rtcall axion_strcat x ""  ; Δ{} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret $aliascopy0  ; Δ{$aliascopy0} · moves{$aliascopy0}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret rtcall axion_strcat x "!"  ; Δ{} · makes String
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  drop picked : String
  else
  else
  let _d1000000 = putStrLn _t0  ; Δ{_t0}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call useBoth "ok"  ; Δ{} · makes String
  let _t0 = rtcall axion_str_len flag  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let picked = call condRet "" name  ; Δ{} · makes String
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_strcat "x/" name  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
condRet flag x  =
main  =
useBoth name  =
