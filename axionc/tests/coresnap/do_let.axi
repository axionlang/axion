



          drop _t2 : String
          drop b : String
          let _d1000000 = putStrLn _t2  ; Δ{_t2}
          let _t2 = showInt n  ; Δ{} · makes String
          let n = rtcall axion_str_at 0 b  ; Δ{b}
          ret _d1000000  ; Δ{}
        _ ->
      drop a : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t1 = putStrLn b  ; Δ{b}
      let b = rtcall axion_strcat a "!"  ; Δ{a} · makes String
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t1 of
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{a}
  ; Δ{b}
  ; Δ{}
  ; Δ{}
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = putStrLn a  ; Δ{a}
  let a = call twice "ab"  ; Δ{} · makes String
  ret 0  ; Δ{}
  ret case _t0 of
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_strcat s s  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
twice s  =
