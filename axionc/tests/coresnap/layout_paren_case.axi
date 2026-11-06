






                  drop _t19 : String
                  let _d1000000 = putStrLn _t19  ; Δ{_t19}
                  let _t18 = call pick 5 5  ; Δ{}
                  let _t19 = showInt _t18  ; Δ{} · makes String
                  ret _d1000000  ; Δ{}
                _ ->
              drop _t16 : String
              let _t15 = call pick 0 9  ; Δ{}
              let _t16 = showInt _t15  ; Δ{} · makes String
              let _t17 = putStrLn _t16  ; Δ{_t16}
              ret case _t17 of
            _ ->
          drop _t13 : String
          let _t0 = + ax bx  ; Δ{}
          let _t1 = + ay by  ; Δ{}
          let _t12 = call pick 0 0  ; Δ{}
          let _t13 = showInt _t12  ; Δ{} · makes String
          let _t14 = putStrLn _t13  ; Δ{_t13}
          ret 10  ; Δ{}
          ret 11  ; Δ{}
          ret case _t14 of
          ret con C _t0 _t1  ; Δ{} · makes C
        0 ->
        C bx by ->
        _ ->
        _ ->
      drop _t10 : String
      drop _t6 : C
      drop _t7 : C
      drop _t8 : C
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t10 = showInt _t9  ; Δ{} · makes String
      let _t11 = putStrLn _t10  ; Δ{_t10}
      let _t6 = con C 1 2  ; Δ{} · makes C
      let _t7 = con C 3 4  ; Δ{_t6} · makes C
      let _t8 = call add _t6 _t7  ; Δ{_t6 _t7} · makes C
      let _t9 = call sndC _t8  ; Δ{_t8}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 12  ; Δ{}
      ret case _t11 of
      ret case b of
      ret case b of
      ret x  ; Δ{}
      ret y  ; Δ{}
    0 ->
    C ax ay ->
    C x y ->
    C x y ->
    _ ->
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
  ; Δ{}
  ; Δ{}
  drop _t0 : C
  drop _t1 : C
  drop _t2 : C
  drop _t4 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = con C 1 2  ; Δ{} · makes C
  let _t1 = con C 3 4  ; Δ{_t0} · makes C
  let _t2 = call add _t0 _t1  ; Δ{_t0 _t1} · makes C
  let _t3 = call fstC _t2  ; Δ{_t2}
  let _t4 = showInt _t3  ; Δ{} · makes String
  let _t5 = putStrLn _t4  ; Δ{_t4}
  ret 0  ; Δ{}
  ret case _t5 of
  ret case a of
  ret case a of
  ret case c of
  ret case c of
  ret rtcall axion_array_free _p  ; Δ{}
add a b  =
axion_drop_Array _p  =
axion_drop_List _p  =
fstC c  =
main  =
pick a b  =
sndC c  =
