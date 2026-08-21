



            _ ->
        _ ->
    _ ->
axion_drop_Array _p  =
axion_drop_List _p  =
          drop _t11 : String
              drop _t14 : String
  drop _t3 : String
      drop _t8 : String
    else
  else
  else
              let _d1000000 = putStrLn _t14  ; Δ{_t14}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call tenpow 30  ; Δ{}
  let _t0 = < k 1  ; Δ{}
          let _t10 = div 100 7  ; Δ{}
          let _t11 = showInt _t10  ; Δ{} · makes String
          let _t12 = putStrLn _t11  ; Δ{_t11}
              let _t13 = mod 100 7  ; Δ{}
              let _t14 = showInt _t13  ; Δ{} · makes String
    let _t1 = rtcall axion_bignum_from_i64 10  ; Δ{}
  let _t1 = rtcall axion_bignum_from_i64 7  ; Δ{}
    let _t2 = - k 1  ; Δ{}
  let _t2 = rtcall axion_bignum_div _t0 _t1  ; Δ{}
    let _t3 = call tenpow _t2  ; Δ{}
  let _t3 = rtcall axion_bignum_to_string _t2  ; Δ{} · makes String
  let _t4 = putStrLn _t3  ; Δ{_t3}
      let _t5 = call tenpow 30  ; Δ{}
      let _t6 = rtcall axion_bignum_from_i64 7  ; Δ{}
      let _t7 = rtcall axion_bignum_mod _t5 _t6  ; Δ{}
      let _t8 = rtcall axion_bignum_to_string _t7  ; Δ{} · makes String
      let _t9 = putStrLn _t8  ; Δ{_t8}
    let _tag = loadraw _p+0  ; Δ{}
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
          ret case _t12 of
  ret case _t4 of
      ret case _t9 of
              ret _d1000000  ; Δ{}
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
    ret rtcall axion_bignum_from_i64 1  ; Δ{}
    ret rtcall axion_bignum_mul _t1 _t3  ; Δ{}
tenpow k  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
