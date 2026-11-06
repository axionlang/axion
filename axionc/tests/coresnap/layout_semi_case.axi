




                      drop _t13 : String
                      let _d1000000 = putStrLn _t13  ; Δ{_t13}
                      let _t12 = call g 7 7  ; Δ{}
                      let _t13 = showInt _t12  ; Δ{} · makes String
                      ret _d1000000  ; Δ{}
                    _ ->
                  drop _t10 : String
                  let _t10 = showInt _t9  ; Δ{} · makes String
                  let _t11 = putStrLn _t10  ; Δ{_t10}
                  let _t9 = call g 0 5  ; Δ{}
                  ret case _t11 of
                _ ->
              drop _t7 : String
              let _t6 = call g 0 0  ; Δ{}
              let _t7 = showInt _t6  ; Δ{} · makes String
              let _t8 = putStrLn _t7  ; Δ{_t7}
              ret case _t8 of
            _ ->
          drop _t4 : String
          let _t4 = call cls 9  ; Δ{} · makes String
          let _t5 = putStrLn _t4  ; Δ{_t4}
          ret 1  ; Δ{}
          ret 2  ; Δ{}
          ret case _t5 of
        0 ->
        _ ->
        _ ->
      drop _t2 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = call cls 1  ; Δ{} · makes String
      let _t3 = putStrLn _t2  ; Δ{_t2}
      ret "m"  ; Δ{}
      ret "o"  ; Δ{}
      ret "z"  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 3  ; Δ{}
      ret case _t3 of
      ret case b of
    0 ->
    0 ->
    1 ->
    _ ->
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call cls 0  ; Δ{} · makes String
  let _t1 = putStrLn _t0  ; Δ{_t0}
  ret 0  ; Δ{}
  ret case _t1 of
  ret case a of
  ret case n of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
cls n  =
g a b  =
main  =
