



                          drop _t23 : Integer
                          drop _t24 : Integer
                          drop _t25 : Integer
                          drop _t26 : String
                          let _d1000000 = putStrLn _t26  ; Δ{_t26}
                          let _t23 = rtcall axion_bignum_from_i64 1000000000000  ; Δ{} · makes Integer
                          let _t24 = rtcall axion_bignum_from_i64 7  ; Δ{_t23} · makes Integer
                          let _t25 = rtcall axion_bignum_div _t23 _t24  ; Δ{_t23 _t24} · makes Integer
                          let _t26 = rtcall axion_bignum_to_string _t25  ; Δ{_t25} · makes String
                          ret _d1000000  ; Δ{}
                        _ ->
                      drop _t21 : String
                      let _t19 = /. 1f 4f  ; Δ{}
                      let _t20 = +. _t19 0.5f  ; Δ{}
                      let _t21 = rtcall axion_show_float _t20  ; Δ{} · makes String
                      let _t22 = putStrLn _t21  ; Δ{_t21}
                      ret case _t22 of
                    _ ->
                  drop _t17 : String
                  let _t16 = /. 7f 2f  ; Δ{}
                  let _t17 = rtcall axion_show_float _t16  ; Δ{} · makes String
                  let _t18 = putStrLn _t17  ; Δ{_t17}
                  ret case _t18 of
                _ ->
              drop _t14 : String
              let _t11 = call sq 6  ; Δ{}
              let _t12 = div _t11 4  ; Δ{}
              let _t13 = + _t12 1  ; Δ{}
              let _t14 = showInt _t13  ; Δ{} · makes String
              let _t15 = putStrLn _t14  ; Δ{_t14}
              ret case _t15 of
            _ ->
          drop _t9 : String
          let _t10 = putStrLn _t9  ; Δ{_t9}
          let _t7 = div 100 10  ; Δ{}
          let _t8 = div _t7 2  ; Δ{}
          let _t9 = showInt _t8  ; Δ{} · makes String
          ret case _t10 of
        _ ->
      drop _t5 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = * 2 10  ; Δ{}
      let _t4 = div _t3 4  ; Δ{}
      let _t5 = showInt _t4  ; Δ{} · makes String
      let _t6 = putStrLn _t5  ; Δ{_t5}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t6 of
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
  drop _t1 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = div 7 2  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret * x x  ; Δ{}
  ret 0  ; Δ{}
  ret case _t2 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
sq x  =
