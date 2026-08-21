




axion_drop_Array _p  =
axion_drop_List _p  =
  drop t$1 : TritVec
    else
  else
  else
  else
fillTrit t i n  =
  let _d1000000 = call sumTrit t$1 0 99 0  ; Δ{t$1}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let t$1 = call fillTrit t 0 99  ; Δ{t} · moves{t} · makes TritVec
  let _t0 = == i n  ; Δ{}
  let _t0 = == i n  ; Δ{}
    let _t1 = + i 1  ; Δ{}
    let _t1 = mod i 3  ; Δ{}
    let _t2 = rtcall axion_tritvec_get t i  ; Δ{}
    let t2 = rtcall axion_tritvec_set t i _t2  ; Δ{} · makes TritVec
    let _t2 = - _t1 1  ; Δ{}
    let _t3 = + acc _t2  ; Δ{}
    let _t3 = + i 1  ; Δ{t2}
    let _tag = loadraw _p+0  ; Δ{}
  let t = rtcall axion_tritvec_new 99 0  ; Δ{} · makes TritVec
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
    ret acc  ; Δ{}
    ret call fillTrit t2 _t3 n  ; Δ{t2} · moves{t2} · makes TritVec
    ret call sumTrit t _t1 n _t3  ; Δ{}
  ret _d1000000  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
    ret t  ; Δ{}
sumTrit t i n acc  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
