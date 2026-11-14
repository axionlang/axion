











                          drop _t23 : String
                          let _d1000000 = putStrLn _t23  ; Δ{_t23}
                          let _t22 = call /=$Float 2.5f 2.5f  ; Δ{}
                          let _t23 = call show$Bool _t22  ; Δ{} · makes String
                          ret _d1000000  ; Δ{}
                        _ ->
                        ret 0  ; Δ{}
                        ret call /=$Int 2 1  ; Δ{}
                      drop _t20 : String
                      else
                      let _t17 = + 1 2  ; Δ{}
                      let _t18 = call /=$Int _t17 3  ; Δ{}
                      let _t19 = if _t18 then
                      let _t20 = call show$Bool _t19  ; Δ{} · makes String
                      let _t21 = putStrLn _t20  ; Δ{_t20}
                      ret case _t21 of
                    _ ->
                  drop _t15 : String
                  let _t12 = con Red  ; Δ{}
                  let _t13 = con Green  ; Δ{}
                  let _t14 = call /=$Color _t12 _t13  ; Δ{}
                  let _t15 = call show$Bool _t14  ; Δ{} · makes String
                  let _t16 = putStrLn _t15  ; Δ{_t15}
                  ret case _t16 of
                _ ->
              drop _t10 : String
              let _t10 = call show$Bool _t9  ; Δ{} · makes String
              let _t11 = putStrLn _t10  ; Δ{_t10}
              let _t9 = call /=$String "ab" "ac"  ; Δ{}
              ret case _t11 of
            _ ->
          drop _t7 : String
          let _t6 = call /=$String "ab" "ab"  ; Δ{}
          let _t7 = call show$Bool _t6  ; Δ{} · makes String
          let _t8 = putStrLn _t7  ; Δ{_t7}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret case _t8 of
        Green ->
        Red ->
        _ ->
        _ ->
        _ ->
      drop _t4 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = call /=$Int 3 3  ; Δ{}
      let _t4 = call show$Bool _t3  ; Δ{} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t5 of
      ret case y of
      ret case y of
    Green ->
    Red ->
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "false"  ; Δ{}
    ret "true"  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1 : String
  else
  else
  else
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call /=$Int 3 4  ; Δ{}
  let _t0 = call eq$Color x y  ; Δ{}
  let _t0 = call eq$Float x y  ; Δ{}
  let _t0 = call eq$Int x y  ; Δ{}
  let _t0 = call eq$String x y  ; Δ{}
  let _t0 = rtcall axion_str_cmp x y  ; Δ{}
  let _t1 = call show$Bool _t0  ; Δ{} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret 0  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret == x y  ; Δ{}
  ret ==. x y  ; Δ{}
  ret case _t2 of
  ret case x of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if x then
  ret rtcall axion_array_free _p  ; Δ{}
/=$Color x y  =
/=$Float x y  =
/=$Int x y  =
/=$String x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
eq$Color x y  =
eq$Float x y  =
eq$Int x y  =
eq$String x y  =
main  =
show$Bool x  =
