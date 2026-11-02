






                          drop _t21 : Integer
                          drop _t22 : String
                          let _d1000000 = putStrLn _t22  ; Δ{_t22}
                          let _t21 = rtcall axion_bignum_from_str "-99999999999999999999"  ; Δ{} · makes Integer
                          let _t22 = call show$Integer _t21  ; Δ{_t21} · makes String
                          ret _d1000000  ; Δ{}
                        _ ->
                      drop _t19 : String
                      let _t19 = rtcall axion_show_float -3f  ; Δ{} · makes String
                      let _t20 = putStrLn _t19  ; Δ{_t19}
                      ret case _t20 of
                    _ ->
                  drop _t17 : String
                  let _t12 = con N  ; Δ{} · makes L
                  let _t13 = con C 10 _t12  ; Δ{_t12} · moves{_t12} · makes L
                  let _t14 = con C -2 _t13  ; Δ{_t13} · moves{_t13} · makes L
                  let _t15 = con C -1 _t14  ; Δ{_t14} · moves{_t14} · makes L
                  let _t16 = call sumL _t15  ; Δ{_t15} · moves{_t15}
                  let _t17 = showInt _t16  ; Δ{} · makes String
                  let _t18 = putStrLn _t17  ; Δ{_t17}
                  ret case _t18 of
                _ ->
              drop _t10 : String
              let _t10 = showInt _t9  ; Δ{} · makes String
              let _t11 = putStrLn _t10  ; Δ{_t10}
              let _t9 = call classify 5  ; Δ{}
              ret case _t11 of
            _ ->
          drop _t7 : String
          let _t6 = call classify -2  ; Δ{}
          let _t7 = showInt _t6  ; Δ{} · makes String
          let _t8 = putStrLn _t7  ; Δ{_t7}
          ret case _t8 of
        _ ->
      drop _t4 : String
      drop xs
      drop xs : L
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_L _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t0 = call sumL t  ; Δ{t} · moves{t}
      let _t3 = call classify -1  ; Δ{}
      let _t4 = showInt _t3  ; Δ{} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
      ret + h _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 10  ; Δ{}
      ret 20  ; Δ{}
      ret 30  ; Δ{}
      ret case _t5 of
    -1 ->
    -2 ->
    C h t ->
    N ->
    _ ->
    _ ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
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
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = - 0 7  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case _t2 of
  ret case n of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_to_string x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_L _p  =
axion_drop_List _p  =
classify n  =
main  =
show$Integer x  =
sumL xs  =
