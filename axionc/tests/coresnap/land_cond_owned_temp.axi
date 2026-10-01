





                      drop _t14 : String
                      let _d1000000 = putStrLn _t14  ; Δ{_t14}
                      let _t14 = call viaArg 0 "zz"  ; Δ{} · makes String
                      ret _d1000000  ; Δ{}
                    _ ->
                  drop _t12 : String
                  let _t12 = call viaArg 1 "zz"  ; Δ{} · makes String
                  let _t13 = putStrLn _t12  ; Δ{_t12}
                  ret case _t13 of
                _ ->
              drop _t10 : String
              drop _t8 : Integer
              drop _t9 : Integer
              let _t10 = rtcall axion_bignum_to_string _t9  ; Δ{_t9} · makes String
              let _t11 = putStrLn _t10  ; Δ{_t10}
              let _t8 = rtcall axion_bignum_from_i64 99  ; Δ{} · makes Integer
              let _t9 = call pickInt 0 _t8  ; Δ{_t8} · makes Integer
              ret case _t11 of
            _ ->
          drop _t4 : Integer
          drop _t5 : Integer
          drop _t6 : String
          let _t4 = rtcall axion_bignum_from_i64 99  ; Δ{} · makes Integer
          let _t5 = call pickInt 1 _t4  ; Δ{_t4} · makes Integer
          let _t6 = rtcall axion_bignum_to_string _t5  ; Δ{_t5} · makes String
          let _t7 = putStrLn _t6  ; Δ{_t6}
          ret case _t7 of
        _ ->
      drop _t2 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = call pickStr 0 "zz"  ; Δ{} · makes String
      let _t3 = putStrLn _t2  ; Δ{_t2}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t3 of
    _ ->
    drop _t1 : Integer
    drop _t2 : Integer
    else
    let _d1000001 = rtcall axion_bignum_add _t1 _t2  ; Δ{_t1 _t2} · makes Integer
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = rtcall axion_bignum_from_i64 10  ; Δ{} · makes Integer
    let _t2 = rtcall axion_bignum_from_i64 20  ; Δ{_t1} · makes Integer
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
    ret rtcall axion_bignum_copy n  ; Δ{} · makes Integer
    ret rtcall axion_strcat "ab" "cd"  ; Δ{} · makes String
    ret rtcall axion_strcat "x" "y"  ; Δ{} · makes String
    ret rtcall axion_strcat s ""  ; Δ{} · makes String
    ret rtcall axion_strcat s ""  ; Δ{} · makes String
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
  drop _t1 : String
  drop _t3 : Integer
  drop x : Integer
  drop x : String
  else
  else
  else
  else
  let _d1000000 = rtcall axion_bignum_add x _t3  ; Δ{_t3} · makes Integer
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _rcl2000000 = rtcall axion_strcat x "!"  ; Δ{} · makes String
  let _rcl2000001 = rtcall axion_strcat _t1 "?"  ; Δ{} · makes String
  let _t0 = > c 0  ; Δ{}
  let _t0 = > c 0  ; Δ{}
  let _t0 = > c 0  ; Δ{}
  let _t0 = call pickStr 1 "zz"  ; Δ{} · makes String
  let _t1 = if _t0 then
  let _t1 = putStrLn _t0  ; Δ{_t0}
  let _t3 = rtcall axion_bignum_from_i64 1  ; Δ{} · makes Integer
  let x = if _t0 then
  let x = if _t0 then
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _rcl2000000  ; Δ{_rcl2000000} · moves{_rcl2000000}
  ret _rcl2000001  ; Δ{_rcl2000001} · moves{_rcl2000001}
  ret case _t1 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
pickInt c n  =
pickStr c s  =
viaArg c s  =
