



          drop _t7 : String
          let _d1000000 = putStrLn _t7  ; Δ{_t7}
          let _t6 = call f 9 9  ; Δ{}
          let _t7 = showInt _t6  ; Δ{} · makes String
          ret 1  ; Δ{}
          ret 2  ; Δ{}
          ret _d1000000  ; Δ{}
        0 ->
        _ ->
        _ ->
      drop _t4 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = call f 0 5  ; Δ{}
      let _t4 = showInt _t3  ; Δ{} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 3  ; Δ{}
      ret case _t5 of
      ret case b of
    0 ->
    _ ->
    _ ->
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call f 0 0  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret 0  ; Δ{}
  ret case _t2 of
  ret case a of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
f a b  =
main  =
