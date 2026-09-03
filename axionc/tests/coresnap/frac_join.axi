




      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t1 = callclo join a b  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret field level _t1  ; Δ{}
    (a, b) ->
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
  drop _t2 : String
  else
  let _d1000000 = putStrLn _t2  ; Δ{_t2}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = callclo split cfg  ; Δ{}
  let _t0 = record Config { level = 7}  ; Δ{} · makes Config
  let _t1 = call splitJoin _t0  ; Δ{_t0} · moves{_t0}
  let _t2 = call show$Int _t1  ; Δ{} · makes String
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case _t0 of
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
show$Int x  =
splitJoin cfg  =
