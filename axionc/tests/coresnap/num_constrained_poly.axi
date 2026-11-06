








          let _t0 = + ax bx  ; Δ{}
          let _t1 = + ay by  ; Δ{}
          ret con V2 _t0 _t1  ; Δ{} · makes V2
        V2 bx by ->
      drop _t3 : V2
      drop _t4 : V2
      drop _t5 : V2
      drop _t6 : V2
      drop _t8 : String
      let _d1000000 = putStrLn _t8  ; Δ{_t8}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = con V2 1 0  ; Δ{} · makes V2
      let _t4 = con V2 2 0  ; Δ{_t3} · makes V2
      let _t5 = con V2 3 0  ; Δ{_t3 _t4} · makes V2
      let _t6 = call sum3$V2 _t3 _t4 _t5  ; Δ{_t3 _t4 _t5} · makes V2
      let _t7 = call fstV _t6  ; Δ{_t6}
      let _t8 = showInt _t7  ; Δ{} · makes String
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{}
      ret case b of
      ret x  ; Δ{}
    V2 ax ay ->
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
  drop _t0 : V2
  drop _t1 : String
  else
  let _d1000000 = call +$V2 _t0 z  ; Δ{_t0} · makes V2
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = + x y  ; Δ{}
  let _t0 = + x y  ; Δ{}
  let _t0 = call +$V2 x y  ; Δ{} · makes V2
  let _t0 = call sum3$Int 1 2 3  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret + _t0 z  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret call addV a b  ; Δ{} · makes V2
  ret case _t2 of
  ret case a of
  ret case v of
  ret rtcall axion_array_free _p  ; Δ{}
+$V2 a b  =
addV a b  =
axion_drop_Array _p  =
axion_drop_List _p  =
fstV v  =
main  =
sum3 x y z  =
sum3$Int x y z  =
sum3$V2 x y z  =
