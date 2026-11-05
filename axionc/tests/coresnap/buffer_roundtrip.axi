


                  drop _t22 : String
                  drop b : Buffer
                  let _d1000000 = putStrLn _t22  ; Δ{_t22}
                  let _t21 = rtcall axion_peek_f64 b 16  ; Δ{b}
                  let _t22 = rtcall axion_show_float _t21  ; Δ{} · makes String
                  ret _d1000000  ; Δ{}
                _ ->
              drop _t19 : String
              let _t18 = rtcall axion_peek_u64 b 8  ; Δ{b}
              let _t19 = showInt _t18  ; Δ{b} · makes String
              let _t20 = putStrLn _t19  ; Δ{_t19 b}
              ret case _t20 of
            _ ->
          drop _t16 : String
          let _t15 = rtcall axion_peek_u32 b 4  ; Δ{b}
          let _t16 = showInt _t15  ; Δ{b} · makes String
          let _t17 = putStrLn _t16  ; Δ{_t16 b}
          ret case _t17 of
        _ ->
      drop _t13 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t12 = rtcall axion_peek_u16 b 2  ; Δ{b}
      let _t13 = showInt _t12  ; Δ{b} · makes String
      let _t14 = putStrLn _t13  ; Δ{_t13 b}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t14 of
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{b}
  ; Δ{b}
  ; Δ{b}
  ; Δ{b}
  ; Δ{}
  ; Δ{}
  drop _t10 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = rtcall axion_poke_u8 b 0 200  ; Δ{b}
  let _t1 = rtcall axion_poke_u16 b 2 40000  ; Δ{b}
  let _t10 = showInt _t9  ; Δ{b} · makes String
  let _t11 = putStrLn _t10  ; Δ{_t10 b}
  let _t2 = + _t0 _t1  ; Δ{b}
  let _t3 = rtcall axion_poke_u32 b 4 4000000000  ; Δ{b}
  let _t4 = + _t2 _t3  ; Δ{b}
  let _t5 = rtcall axion_poke_u64 b 8 1234567890123  ; Δ{b}
  let _t6 = + _t4 _t5  ; Δ{b}
  let _t7 = rtcall axion_poke_f64 b 16 2.5f  ; Δ{b}
  let _t8 = rtcall axion_peek_u8 b 0  ; Δ{b}
  let _t9 = + _t8 w  ; Δ{b}
  let b = rtcall axion_buf_new 32  ; Δ{} · makes Buffer
  let w = + _t6 _t7  ; Δ{b}
  ret 0  ; Δ{}
  ret case _t11 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
