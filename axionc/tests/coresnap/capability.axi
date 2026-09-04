




                                  drop _t26 : String
                                  drop _t28 : String
                                  let _d1000000 = putStrLn _t28  ; Δ{_t28}
                                  let _t26 = call path  ; Δ{} · makes String
                                  let _t27 = rtcall axion_unlink _t26  ; Δ{_t26}
                                  let _t28 = showInt _t27  ; Δ{} · makes String
                                  ret _d1000000  ; Δ{}
                                _ ->
                              drop _t22 : String
                              drop _t24 : String
                              let _t22 = call path  ; Δ{} · makes String
                              let _t23 = rtcall axion_file_exists _t22  ; Δ{_t22}
                              let _t24 = showInt _t23  ; Δ{} · makes String
                              let _t25 = putStrLn _t24  ; Δ{_t24}
                              ret case _t25 of
                            _ ->
                          drop _t19 : String
                          drop _t20 : String
                          let _t19 = call path  ; Δ{} · makes String
                          let _t20 = rtcall axion_read_file _t19  ; Δ{_t19} · makes String
                          let _t21 = putStrLn _t20  ; Δ{_t20}
                          ret case _t21 of
                        _ ->
                      drop _t15 : String
                      drop _t17 : String
                      let _t15 = call path  ; Δ{} · makes String
                      let _t16 = rtcall axion_write_file _t15 "roundtrip"  ; Δ{_t15}
                      let _t17 = showInt _t16  ; Δ{} · makes String
                      let _t18 = putStrLn _t17  ; Δ{_t17}
                      ret case _t18 of
                    _ ->
                  drop _t11 : String
                  drop _t13 : String
                  let _t11 = call dir  ; Δ{} · makes String
                  let _t12 = rtcall axion_mkdir_p _t11  ; Δ{_t11}
                  let _t13 = showInt _t12  ; Δ{} · makes String
                  let _t14 = putStrLn _t13  ; Δ{_t13}
                  ret case _t14 of
                _ ->
              drop _t7 : String
              drop _t9 : String
              let _t10 = putStrLn _t9  ; Δ{_t9}
              let _t7 = rtcall axion_rand_hex 16  ; Δ{} · makes String
              let _t8 = rtcall axion_str_len _t7  ; Δ{_t7}
              let _t9 = showInt _t8  ; Δ{} · makes String
              ret case _t10 of
            _ ->
          drop _t5 : String
          let _t5 = rtcall axion_getenv "CAP_VAR"  ; Δ{} · makes String
          let _t6 = putStrLn _t5  ; Δ{_t5}
          ret case _t6 of
        _ ->
      drop _t3 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = rtcall axion_system "exit 7"  ; Δ{}
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
  drop _t0 : String
  else
  let _d1000000 = rtcall axion_strcat _t0 "/note.txt"  ; Δ{_t0} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call dir  ; Δ{} · makes String
  let _t0 = rtcall axion_run "printf ok"  ; Δ{} · makes String
  let _t1 = putStrLn _t0  ; Δ{_t0}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret case _t1 of
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_getenv "CAP_DIR"  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
dir  =
main  =
path  =
