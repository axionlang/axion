







          drop _t13 : String
          let _d1000000 = putStrLn _t13  ; Δ{_t13}
          let _t10 = call popCount 7  ; Δ{}
          let _t11 = call complement 0  ; Δ{}
          let _t12 = + _t10 _t11  ; Δ{}
          let _t13 = showInt _t12  ; Δ{} · makes String
          ret _d1000000  ; Δ{}
        _ ->
        ret "n"  ; Δ{}
        ret "y"  ; Δ{}
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t5 = 1  ; Δ{}
      let _t6 = 0  ; Δ{}
      let _t7 = call xor _t5 _t6  ; Δ{}
      let _t8 = if _t7 then
      let _t9 = putStrLn _t8  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t9 of
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = - x 1  ; Δ{}
    let _t2 = .&. x _t1  ; Δ{}
    let _t3 = call popCount _t2  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "n"  ; Δ{}
    ret "y"  ; Δ{}
    ret + 1 _t3  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret b  ; Δ{}
    ret b  ; Δ{}
    ret call not b  ; Δ{}
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
  else
  else
  else
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = 1  ; Δ{}
  let _t0 = == x 0  ; Δ{}
  let _t1 = 0  ; Δ{}
  let _t2 = call .&. _t0 _t1  ; Δ{}
  let _t3 = if _t2 then
  let _t4 = putStrLn _t3  ; Δ{}
  ret - -1 x  ; Δ{}
  ret 0  ; Δ{}
  ret case _t4 of
  ret if _t0 then
  ret if a then
  ret if a then
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
.&. a b  =
axion_drop_Array _p  =
axion_drop_List _p  =
complement x  =
main  =
not b  =
popCount x  =
xor a b  =
