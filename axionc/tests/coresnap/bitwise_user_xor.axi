




        ret "no"  ; Δ{}
        ret "yes"  ; Δ{}
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t5 = 1  ; Δ{}
      let _t6 = 1  ; Δ{}
      let _t7 = call xor _t5 _t6  ; Δ{}
      let _t8 = if _t7 then
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret putStrLn _t8  ; Δ{}
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "no"  ; Δ{}
    ret "yes"  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret b  ; Δ{}
    ret call not b  ; Δ{}
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
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = 1  ; Δ{}
  let _t1 = 0  ; Δ{}
  let _t2 = call xor _t0 _t1  ; Δ{}
  let _t3 = if _t2 then
  let _t4 = putStrLn _t3  ; Δ{}
  ret 0  ; Δ{}
  ret case _t4 of
  ret if a then
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
not b  =
xor a b  =
