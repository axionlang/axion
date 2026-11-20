




                                  drop _t30 : String
                                  let _d1000000 = putStrLn _t30  ; Δ{_t30}
                                  let _t28 = - 0 1  ; Δ{}
                                  let _t29 = xor 5 _t28  ; Δ{}
                                  let _t30 = showInt _t29  ; Δ{} · makes String
                                  ret _d1000000  ; Δ{}
                                _ ->
                              drop _t26 : String
                              let _t24 = - 0 1  ; Δ{}
                              let _t25 = shiftL 1 _t24  ; Δ{}
                              let _t26 = showInt _t25  ; Δ{} · makes String
                              let _t27 = putStrLn _t26  ; Δ{_t26}
                              ret case _t27 of
                            _ ->
                          drop _t22 : String
                          let _t21 = shiftL 1 65  ; Δ{}
                          let _t22 = showInt _t21  ; Δ{} · makes String
                          let _t23 = putStrLn _t22  ; Δ{_t22}
                          ret case _t23 of
                        _ ->
                      drop _t19 : String
                      let _t17 = - 0 16  ; Δ{}
                      let _t18 = shiftR _t17 2  ; Δ{}
                      let _t19 = showInt _t18  ; Δ{} · makes String
                      let _t20 = putStrLn _t19  ; Δ{_t19}
                      ret case _t20 of
                    _ ->
                  drop _t15 : String
                  let _t13 = .&. 10 6  ; Δ{}
                  let _t14 = xor 12 _t13  ; Δ{}
                  let _t15 = showInt _t14  ; Δ{} · makes String
                  let _t16 = putStrLn _t15  ; Δ{_t15}
                  ret case _t16 of
                _ ->
              drop _t11 : String
              let _t10 = xor 12 10  ; Δ{}
              let _t11 = showInt _t10  ; Δ{} · makes String
              let _t12 = putStrLn _t11  ; Δ{_t11}
              ret case _t12 of
            _ ->
          drop _t8 : String
          let _t5 = .&. p 255  ; Δ{}
          let _t6 = shiftL 1 4  ; Δ{}
          let _t7 = .|. _t5 _t6  ; Δ{}
          let _t8 = showInt _t7  ; Δ{} · makes String
          let _t9 = putStrLn _t8  ; Δ{_t8}
          ret case _t9 of
        _ ->
      drop _t3 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = call red p  ; Δ{}
      let _t3 = showInt _t2  ; Δ{} · makes String
      let _t4 = putStrLn _t3  ; Δ{_t3}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t4 of
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
  let _t0 = shiftL r 16  ; Δ{}
  let _t0 = shiftR p 16  ; Δ{}
  let _t0 = showInt p  ; Δ{} · makes String
  let _t1 = putStrLn _t0  ; Δ{_t0}
  let _t1 = shiftL g 8  ; Δ{}
  let _t2 = .|. _t0 _t1  ; Δ{}
  let p = call pix 18 52 86  ; Δ{}
  ret .&. _t0 255  ; Δ{}
  ret .|. _t2 b  ; Δ{}
  ret 0  ; Δ{}
  ret case _t1 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
pix r g b  =
red p  =
