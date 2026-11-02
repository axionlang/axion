


                  drop _t9 : String
                  let _d1000000 = putStrLn _t9  ; Δ{_t9}
                  let _t8 = +. 0.5f 0.25f  ; Δ{}
                  let _t9 = rtcall axion_show_float _t8  ; Δ{} · makes String
                  ret _d1000000  ; Δ{}
                _ ->
              drop _t6 : String
              let _t6 = rtcall axion_show_float 0.5f  ; Δ{} · makes String
              let _t7 = putStrLn _t6  ; Δ{_t6}
              ret case _t7 of
            _ ->
          drop _t4 : String
          let _t4 = rtcall axion_show_float 0.0015f  ; Δ{} · makes String
          let _t5 = putStrLn _t4  ; Δ{_t4}
          ret case _t5 of
        _ ->
      drop _t2 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = rtcall axion_show_float 20000000000f  ; Δ{} · makes String
      let _t3 = putStrLn _t2  ; Δ{_t2}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t3 of
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
  drop _t0 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = rtcall axion_show_float 1000000000f  ; Δ{} · makes String
  let _t1 = putStrLn _t0  ; Δ{_t0}
  ret 0  ; Δ{}
  ret case _t1 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
