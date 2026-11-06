



                  drop _t5 : String
                  let _d1000000 = putStrLn _t5  ; Δ{_t5}
                  let _t5 = call greet "x"  ; Δ{} · makes String
                  ret _d1000000  ; Δ{}
                _ ->
              drop _t3 : String
              let _t3 = call greet "hi"  ; Δ{} · makes String
              let _t4 = putStrLn _t3  ; Δ{_t3}
              ret case _t4 of
            _ ->
          let _t2 = putStrLn "c"  ; Δ{}
          ret case _t2 of
        _ ->
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t1 = putStrLn "b"  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t1 of
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "?"  ; Δ{}
    ret "hello"  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = putStrLn "a"  ; Δ{}
  let _t0 = rtcall axion_str_cmp s "hi"  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  ret 0  ; Δ{}
  ret case _t0 of
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
greet s  =
main  =
