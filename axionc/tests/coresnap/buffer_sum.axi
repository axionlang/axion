


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
  let b = rtcall axion_buf_new 100  ; Δ{}
  let b1 = rtcall axion_buf_iota b  ; Δ{}
  let done = rtcall axion_buf_free b1  ; Δ{}
  let s = rtcall axion_buf_sum b1  ; Δ{}
  ret 0  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret s  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
