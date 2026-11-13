



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
  ; Δ{}
  ; Δ{}
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = ffi abs n  ; Δ{}
  let _t1 = ffi abs _t0 [o]  ; Δ{}
  let _t2 = ffi abs s  ; Δ{}
  let _t3 = ffi abs s  ; Δ{}
  let _t4 = + _t2 _t3  ; Δ{}
  let _t5 = ffi abs s [o]  ; Δ{}
  let s = ffi abs _t1 [o]  ; Δ{}
  ret + _t4 _t5  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
session n  =
