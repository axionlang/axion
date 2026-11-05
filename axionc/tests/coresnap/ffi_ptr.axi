





                ret "nonnull"  ; Δ{}
                ret "null"  ; Δ{}
              else
              let _t10 = call isNull _t9  ; Δ{}
              let _t11 = if _t10 then
              let _t9 = call asWin 7  ; Δ{}
              ret putStrLn _t11  ; Δ{}
            _ ->
            ret "nonnull"  ; Δ{}
            ret "null"  ; Δ{}
          else
          let _t6 = call isNull 0  ; Δ{}
          let _t7 = if _t6 then
          let _t8 = putStrLn _t7  ; Δ{}
          ret case _t8 of
        _ ->
      drop _t4 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = call asRen 2000  ; Δ{}
      let _t4 = showInt _t3  ; Δ{} · makes String
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
  ; Δ{}
  drop _t1 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call asWin 1000  ; Δ{}
  let _t0 = p  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret 0  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret case _t2 of
  ret n  ; Δ{}
  ret n  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
asRen n  =
asWin n  =
axion_drop_Array _p  =
axion_drop_List _p  =
isNull p  =
main  =
