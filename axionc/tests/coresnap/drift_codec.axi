



axion_drop_Array _p  =
axion_drop_List _p  =
  drop acts : Array
  drop t : TritVec
    else
  else
  else
  let acts = rtcall axion_array_iota 100003  ; Δ{t} · makes Array
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call sumTrit t 0 100003 0  ; Δ{acts t}
  let _t0 = == i n  ; Δ{}
    let _t1 = + i 1  ; Δ{}
  let _t1 = rtcall axion_tritvec_dot t acts  ; Δ{acts t}
    let _t2 = rtcall axion_tritvec_get t i  ; Δ{}
  let _t2 = + _t0 _t1  ; Δ{t}
    let _t3 = + acc _t2  ; Δ{}
  let _t3 = rtcall axion_tritvec_len t  ; Δ{t}
    let _tag = loadraw _p+0  ; Δ{}
  let t = rtcall axion_tritvec_iota 100003  ; Δ{} · makes TritVec
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
    ret acc  ; Δ{}
    ret call sumTrit t _t1 n _t3  ; Δ{}
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret + _t2 _t3  ; Δ{}
sumTrit t i n acc  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
