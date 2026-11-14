







          drop _t10 : String
          drop _t11 : String
          drop _t12 : String
          drop _t5 : String
          drop _t8 : String
          let _d1000000 = putStrLn _t5  ; Δ{_t5}
          let _d1000001 = rtcall axion_strcat "not a file " _t8  ; Δ{_t8} · makes String
          let _d1000002 = rtcall axion_strcat _t11 _t12  ; Δ{_t11 _t12} · makes String
          let _t10 = showInt n  ; Δ{} · makes String
          let _t11 = rtcall axion_strcat _t10 " bytes, sum "  ; Δ{_t10} · makes String
          let _t12 = showInt s  ; Δ{_t11} · makes String
          let _t5 = call report "."  ; Δ{} · makes String
          let _t8 = showInt e  ; Δ{} · makes String
          ret _d1000000  ; Δ{}
          ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
          ret _d1000002  ; Δ{_d1000002} · moves{_d1000002}
        _ ->
        _ ->
        _ ->
        drop _t3 : String
        let _d1000000 = rtcall axion_strcat "error " _t3  ; Δ{_t3} · makes String
        let _t3 = showInt e  ; Δ{} · makes String
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      _ ->
      drop _t3 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = call report "no_such_file.axi"  ; Δ{} · makes String
      let _t4 = putStrLn _t3  ; Δ{_t3}
      let _t6 = rtcall axion_file_size f  ; Δ{}
      let _t7 = rtcall axion_file_close f  ; Δ{}
      let _t9 = rtcall axion_file_close f  ; Δ{}
      let e = - 0 _t6  ; Δ{}
      let n = rtcall axion_file_size f  ; Δ{}
      let s = call sumChunks f 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t4 of
      ret case _t7 of
      ret case _t9 of
    _ ->
    drop b : Buffer
    drop b : Buffer
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t2 = rtcall axion_buf_sum b  ; Δ{b}
    let _t2 = rtcall axion_file_close f  ; Δ{}
    let _t3 = + acc _t2  ; Δ{}
    let _t4 = rtcall axion_file_size f  ; Δ{}
    let _t5 = < _t4 0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let e = rtcall axion_file_errno f  ; Δ{}
    ret "axionc/tests/fixtures/file_read_chunks.axi"  ; Δ{}
    ret "tests/fixtures/file_read_chunks.axi"  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret acc  ; Δ{}
    ret call sumChunks f _t3  ; Δ{}
    ret case _t2 of
    ret if _t5 then
  ; Δ{b}
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
  drop _t0 : String
  drop _t1 : String
  else
  else
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call eq$Int x y  ; Δ{}
  let _t0 = call selfPath 0  ; Δ{} · makes String
  let _t0 = rtcall axion_buf_len b  ; Δ{b}
  let _t0 = rtcall axion_file_errno f  ; Δ{}
  let _t0 = rtcall axion_file_exists "tests/fixtures/file_read_chunks.axi"  ; Δ{}
  let _t1 = == _t0 0  ; Δ{b}
  let _t1 = == _t0 1  ; Δ{}
  let _t1 = call /=$Int _t0 0  ; Δ{}
  let _t1 = call report _t0  ; Δ{_t0} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  let b = rtcall axion_file_read f 64  ; Δ{} · makes Buffer
  let f = rtcall axion_file_open path  ; Δ{}
  ret 0  ; Δ{}
  ret == x y  ; Δ{}
  ret case _t2 of
  ret if _t0 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
/=$Int x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
eq$Int x y  =
main  =
report path  =
selfPath d  =
sumChunks f acc  =
