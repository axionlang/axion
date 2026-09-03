



      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + i 1  ; Δ{}
    let _t2 = rtcall axion_tritvec_get t i  ; Δ{}
    let _t3 = + acc _t2  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret acc  ; Δ{}
    ret call sumT t _t1 n _t3  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop t : TritVec
  else
  else
  let _d1000000 = call sumT t 0 25 0  ; Δ{t}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = == i n  ; Δ{}
  let _t0 = rtcall axion_buf_new 5  ; Δ{}
  let b = rtcall axion_buf_iota _t0  ; Δ{}
  let done = rtcall axion_buf_free b  ; Δ{t}
  let t = rtcall axion_tritvec_from_buffer b 25  ; Δ{} · makes TritVec
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
sumT t i n acc  =
