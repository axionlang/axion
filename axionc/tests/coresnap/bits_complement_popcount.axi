




                                      drop _t32 : String
                                      let _d1000000 = putStrLn _t32  ; Δ{_t32}
                                      let _t29 = call complement 15  ; Δ{}
                                      let _t30 = .&. 255 _t29  ; Δ{}
                                      let _t31 = call popCount _t30  ; Δ{}
                                      let _t32 = showInt _t31  ; Δ{} · makes String
                                      ret _d1000000  ; Δ{}
                                    _ ->
                                  drop _t27 : String
                                  let _t25 = call complement 255  ; Δ{}
                                  let _t26 = call popCount _t25  ; Δ{}
                                  let _t27 = showInt _t26  ; Δ{} · makes String
                                  let _t28 = putStrLn _t27  ; Δ{_t27}
                                  ret case _t28 of
                                _ ->
                              drop _t23 : String
                              let _t21 = shiftL 1 63  ; Δ{}
                              let _t22 = call popCount _t21  ; Δ{}
                              let _t23 = showInt _t22  ; Δ{} · makes String
                              let _t24 = putStrLn _t23  ; Δ{_t23}
                              ret case _t24 of
                            _ ->
                          drop _t19 : String
                          let _t18 = call popCount -1  ; Δ{}
                          let _t19 = showInt _t18  ; Δ{} · makes String
                          let _t20 = putStrLn _t19  ; Δ{_t19}
                          ret case _t20 of
                        _ ->
                      drop _t16 : String
                      let _t15 = call popCount 1024  ; Δ{}
                      let _t16 = showInt _t15  ; Δ{} · makes String
                      let _t17 = putStrLn _t16  ; Δ{_t16}
                      ret case _t17 of
                    _ ->
                  drop _t13 : String
                  let _t12 = call popCount 7  ; Δ{}
                  let _t13 = showInt _t12  ; Δ{} · makes String
                  let _t14 = putStrLn _t13  ; Δ{_t13}
                  ret case _t14 of
                _ ->
              drop _t10 : String
              let _t10 = showInt _t9  ; Δ{} · makes String
              let _t11 = putStrLn _t10  ; Δ{_t10}
              let _t9 = call popCount 0  ; Δ{}
              ret case _t11 of
            _ ->
          drop _t7 : String
          let _t6 = call complement -6  ; Δ{}
          let _t7 = showInt _t6  ; Δ{} · makes String
          let _t8 = putStrLn _t7  ; Δ{_t7}
          ret case _t8 of
        _ ->
      drop _t4 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = call complement 5  ; Δ{}
      let _t4 = showInt _t3  ; Δ{} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t5 of
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = - x 1  ; Δ{}
    let _t2 = .&. x _t1  ; Δ{}
    let _t3 = call popCount _t2  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret + 1 _t3  ; Δ{}
    ret 0  ; Δ{}
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
  ; Δ{}
  ; Δ{}
  drop _t1 : String
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = == x 0  ; Δ{}
  let _t0 = call complement 0  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret - -1 x  ; Δ{}
  ret 0  ; Δ{}
  ret case _t2 of
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
complement x  =
main  =
popCount x  =
