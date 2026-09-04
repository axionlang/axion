


                  drop _t12 : String
                  let _d1000000 = putStrLn _t12  ; Δ{_t12}
                  let _t12 = rtcall axion_run "printf spawned"  ; Δ{} · makes String
                  ret _d1000000  ; Δ{}
                _ ->
              drop _t10 : String
              drop _t9 : String
              let _t10 = rtcall axion_strcat "home=" _t9  ; Δ{_t9} · makes String
              let _t11 = putStrLn _t10  ; Δ{_t10}
              let _t9 = rtcall axion_getenv "HELLO_HOME"  ; Δ{} · makes String
              ret case _t11 of
            _ ->
          drop _t6 : String
          drop _t7 : String
          let _t6 = rtcall axion_getarg 5  ; Δ{} · makes String
          let _t7 = rtcall axion_strcat "missing=" _t6  ; Δ{_t6} · makes String
          let _t8 = putStrLn _t7  ; Δ{_t7}
          ret case _t8 of
        _ ->
      drop _t3 : String
      drop _t4 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = rtcall axion_getarg 1  ; Δ{} · makes String
      let _t4 = rtcall axion_strcat "arg=" _t3  ; Δ{_t3} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t5 of
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
  drop _t1 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = rtcall axion_getarg 0  ; Δ{} · makes String
  let _t1 = rtcall axion_strcat "cmd=" _t0  ; Δ{_t0} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret 0  ; Δ{}
  ret case _t2 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
