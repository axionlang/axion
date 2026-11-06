













              drop _t15 : V2
              drop _t16 : V2
              drop _t17 : V2
              drop _t18 : String
              let _d1000000 = putStrLn _t18  ; Δ{_t18}
              let _t15 = con V2 20 12  ; Δ{} · makes V2
              let _t16 = con V2 5 4  ; Δ{_t15} · makes V2
              let _t17 = call /$V2 _t15 _t16  ; Δ{_t15 _t16} · makes V2
              let _t18 = call showV _t17  ; Δ{_t17} · makes String
              ret _d1000000  ; Δ{}
            _ ->
          drop _t10 : V2
          drop _t11 : V2
          drop _t12 : V2
          drop _t13 : String
          let _t0 = * ax bx  ; Δ{}
          let _t0 = + ax bx  ; Δ{}
          let _t0 = - ax bx  ; Δ{}
          let _t0 = div ax bx  ; Δ{}
          let _t1 = * ay by  ; Δ{}
          let _t1 = + ay by  ; Δ{}
          let _t1 = - ay by  ; Δ{}
          let _t1 = div ay by  ; Δ{}
          let _t10 = con V2 2 3  ; Δ{} · makes V2
          let _t11 = con V2 3 4  ; Δ{_t10} · makes V2
          let _t12 = call *$V2 _t10 _t11  ; Δ{_t10 _t11} · makes V2
          let _t13 = call showV _t12  ; Δ{_t12} · makes String
          let _t14 = putStrLn _t13  ; Δ{_t13}
          ret case _t14 of
          ret con V2 _t0 _t1  ; Δ{} · makes V2
          ret con V2 _t0 _t1  ; Δ{} · makes V2
          ret con V2 _t0 _t1  ; Δ{} · makes V2
          ret con V2 _t0 _t1  ; Δ{} · makes V2
        V2 bx by ->
        V2 bx by ->
        V2 bx by ->
        V2 bx by ->
        _ ->
      drop _t5 : V2
      drop _t6 : V2
      drop _t7 : V2
      drop _t8 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t5 = con V2 10 9  ; Δ{} · makes V2
      let _t6 = con V2 3 4  ; Δ{_t5} · makes V2
      let _t7 = call -$V2 _t5 _t6  ; Δ{_t5 _t6} · makes V2
      let _t8 = call showV _t7  ; Δ{_t7} · makes String
      let _t9 = putStrLn _t8  ; Δ{_t8}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t9 of
      ret case b of
      ret case b of
      ret case b of
      ret case b of
      ret x  ; Δ{}
      ret y  ; Δ{}
    V2 ax ay ->
    V2 ax ay ->
    V2 ax ay ->
    V2 ax ay ->
    V2 x y ->
    V2 x y ->
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : V2
  drop _t1 : String
  drop _t1 : V2
  drop _t2 : V2
  drop _t3 : String
  drop _t3 : String
  drop _t4 : String
  else
  let _d1000000 = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call fstV v  ; Δ{}
  let _t0 = con V2 1 2  ; Δ{} · makes V2
  let _t1 = con V2 3 4  ; Δ{_t0} · makes V2
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = call +$V2 _t0 _t1  ; Δ{_t0 _t1} · makes V2
  let _t2 = call sndV v  ; Δ{_t1}
  let _t3 = call showV _t2  ; Δ{_t2} · makes String
  let _t3 = showInt _t2  ; Δ{_t1} · makes String
  let _t4 = putStrLn _t3  ; Δ{_t3}
  let _t4 = rtcall axion_strcat " " _t3  ; Δ{_t1 _t3} · makes String
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret call addV a b  ; Δ{} · makes V2
  ret call divV a b  ; Δ{} · makes V2
  ret call mulV a b  ; Δ{} · makes V2
  ret call subV a b  ; Δ{} · makes V2
  ret case _t4 of
  ret case a of
  ret case a of
  ret case a of
  ret case a of
  ret case v of
  ret case v of
  ret rtcall axion_array_free _p  ; Δ{}
*$V2 a b  =
+$V2 a b  =
-$V2 a b  =
/$V2 a b  =
addV a b  =
axion_drop_Array _p  =
axion_drop_List _p  =
divV a b  =
fstV v  =
main  =
mulV a b  =
showV v  =
sndV v  =
subV a b  =
