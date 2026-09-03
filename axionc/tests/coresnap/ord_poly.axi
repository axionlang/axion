




      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret x  ; Δ{}
    ret x  ; Δ{}
    ret y  ; Δ{}
    ret y  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = < x y  ; Δ{}
  let _t0 = <. x y  ; Δ{}
  let _t0 = call maxOf$Float 3f 5f  ; Δ{}
  let _t1 = call maxOf$Float 1f 2f  ; Δ{}
  ret +. _t0 _t1  ; Δ{}
  ret 0  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
maxOf x y  =
maxOf$Float x y  =
