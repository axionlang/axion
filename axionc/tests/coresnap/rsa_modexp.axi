












            _ ->
        _ ->
    _ ->
axion_drop_Array _p  =
axion_drop_List _p  =
d  =
              drop _t18 : String
  drop _t3 : String
      drop _t6 : String
          drop _t9 : String
e  =
    else
    else
    else
  else
  else
  else
              let _d1000000 = putStrLn _t18  ; Δ{_t18}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
      let h = call powMod b _t7 m  ; Δ{}
    let q = rtcall axion_bignum_div r newr  ; Δ{}
  let _t0 = call e  ; Δ{}
  let _t0 = call p  ; Δ{}
  let _t0 = call p  ; Δ{}
  let _t0 = rtcall axion_bignum_from_i64 0  ; Δ{}
  let _t0 = rtcall axion_bignum_from_i64 0  ; Δ{}
  let _t0 = rtcall axion_bignum_from_i64 0  ; Δ{}
  let _t0 = rtcall axion_bignum_from_i64 17  ; Δ{}
          let _t10 = putStrLn _t9  ; Δ{_t9}
      let _t10 = rtcall axion_bignum_sub e _t9  ; Δ{}
      let _t11 = call powMod b _t10 m  ; Δ{}
              let _t11 = rtcall axion_bignum_from_i64 42  ; Δ{}
              let _t12 = call e  ; Δ{}
      let _t12 = rtcall axion_bignum_mul b _t11  ; Δ{}
              let _t13 = call n  ; Δ{}
              let _t14 = call powMod _t11 _t12 _t13  ; Δ{}
              let _t15 = call d  ; Δ{}
              let _t16 = call n  ; Δ{}
              let _t17 = call powMod _t14 _t15 _t16  ; Δ{}
              let _t18 = call show$Integer _t17  ; Δ{} · makes String
  let _t1 = call phi  ; Δ{}
  let _t1 = call q  ; Δ{}
  let _t1 = rtcall axion_bignum_eq e _t0  ; Δ{}
  let _t1 = rtcall axion_bignum_eq newr _t0  ; Δ{}
  let _t1 = rtcall axion_bignum_from_i64 1  ; Δ{}
  let _t1 = rtcall axion_bignum_from_i64 1  ; Δ{}
  let _t1 = rtcall axion_bignum_from_i64 3120  ; Δ{}
  let _t2 = call modInverse _t0 _t1  ; Δ{}
    let _t2 = rtcall axion_bignum_from_i64 0  ; Δ{}
    let _t2 = rtcall axion_bignum_from_i64 2  ; Δ{}
  let _t2 = rtcall axion_bignum_sub _t0 _t1  ; Δ{}
  let _t3 = call q  ; Δ{}
  let _t3 = call show$Integer _t2  ; Δ{} · makes String
    let _t3 = rtcall axion_bignum_lt t _t2  ; Δ{}
    let _t3 = rtcall axion_bignum_mod e _t2  ; Δ{}
  let _t4 = putStrLn _t3  ; Δ{_t3}
    let _t4 = rtcall axion_bignum_from_i64 0  ; Δ{}
  let _t4 = rtcall axion_bignum_from_i64 1  ; Δ{}
    let _t4 = rtcall axion_bignum_mul q newt  ; Δ{}
      let _t5 = call n  ; Δ{}
    let _t5 = rtcall axion_bignum_eq _t3 _t4  ; Δ{}
  let _t5 = rtcall axion_bignum_sub _t3 _t4  ; Δ{}
    let _t5 = rtcall axion_bignum_sub t _t4  ; Δ{}
      let _t6 = call show$Integer _t5  ; Δ{} · makes String
      let _t6 = rtcall axion_bignum_from_i64 2  ; Δ{}
    let _t6 = rtcall axion_bignum_mul q newr  ; Δ{}
      let _t7 = putStrLn _t6  ; Δ{_t6}
      let _t7 = rtcall axion_bignum_div e _t6  ; Δ{}
    let _t7 = rtcall axion_bignum_sub r _t6  ; Δ{}
          let _t8 = call d  ; Δ{}
      let _t8 = rtcall axion_bignum_mul h h  ; Δ{}
          let _t9 = call show$Integer _t8  ; Δ{} · makes String
      let _t9 = rtcall axion_bignum_from_i64 1  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
modInverse$loop m t newt r newr  =
modInverse a m  =
n  =
p  =
phi  =
powMod b e m  =
q  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
    ret call modInverse$loop m newt _t5 newr _t7  ; Δ{}
  ret call modInverse$loop m _t0 _t1 m a  ; Δ{}
  ret call modInverse _t0 _t1  ; Δ{}
          ret case _t10 of
  ret case _t4 of
      ret case _t7 of
              ret _d1000000  ; Δ{}
  ret if _t1 then
  ret if _t1 then
    ret if _t3 then
    ret if _t5 then
  ret rtcall axion_array_free _p  ; Δ{}
      ret rtcall axion_bignum_add t m  ; Δ{}
  ret rtcall axion_bignum_from_i64 1000000007  ; Δ{}
  ret rtcall axion_bignum_from_i64 1000000009  ; Δ{}
    ret rtcall axion_bignum_from_i64 1  ; Δ{}
  ret rtcall axion_bignum_from_i64 65537  ; Δ{}
      ret rtcall axion_bignum_mod _t12 m  ; Δ{}
      ret rtcall axion_bignum_mod _t8 m  ; Δ{}
  ret rtcall axion_bignum_mul _t0 _t1  ; Δ{}
  ret rtcall axion_bignum_mul _t2 _t5  ; Δ{}
  ret rtcall axion_bignum_to_string x  ; Δ{} · makes String
      ret t  ; Δ{}
show$Integer x  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
