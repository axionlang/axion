


                          drop _t18 : String
                          let _d1000000 = putStrLn _t18  ; Δ{_t18}
                          let _t18 = rtcall axion_read_file "/etc/hostname"  ; Δ{} · makes String
                          ret _d1000000  ; Δ{}
                        _ ->
                      drop _t16 : String
                      let _t15 = rtcall axion_file_exists "/"  ; Δ{}
                      let _t16 = showInt _t15  ; Δ{} · makes String
                      let _t17 = putStrLn _t16  ; Δ{_t16}
                      ret case _t17 of
                    _ ->
                  drop _t13 : String
                  let _t12 = rtcall axion_system "true"  ; Δ{}
                  let _t13 = showInt _t12  ; Δ{} · makes String
                  let _t14 = putStrLn _t13  ; Δ{_t13}
                  ret case _t14 of
                _ ->
              drop _t10 : String
              drop _t8 : String
              let _t10 = showInt _t9  ; Δ{} · makes String
              let _t11 = putStrLn _t10  ; Δ{_t10}
              let _t8 = rtcall axion_readdir "/"  ; Δ{} · makes String
              let _t9 = rtcall axion_str_len _t8  ; Δ{_t8}
              ret case _t11 of
            _ ->
          drop _t4 : String
          drop _t6 : String
          let _t4 = rtcall axion_rand_hex 4  ; Δ{} · makes String
          let _t5 = rtcall axion_str_len _t4  ; Δ{_t4}
          let _t6 = showInt _t5  ; Δ{} · makes String
          let _t7 = putStrLn _t6  ; Δ{_t6}
          ret case _t7 of
        _ ->
      drop _t2 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = rtcall axion_run "printf sanitize-ok"  ; Δ{} · makes String
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
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = rtcall axion_getenv "PATH"  ; Δ{} · makes String
  let _t1 = putStrLn _t0  ; Δ{_t0}
  ret 0  ; Δ{}
  ret case _t1 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
