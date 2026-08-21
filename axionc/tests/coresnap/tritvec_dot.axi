




axion_drop_Array _p  =
axion_drop_List _p  =
  drop a : Array
  drop t : TritVec
    else
  else
  else
  else
fillIdx a i n  =
fillTrit t i n  =
    let a2 = rtcall axion_array_set a i i  ; Δ{} · makes Array
  let a = call fillIdx _t1 0 10  ; Δ{_t1 t} · moves{_t1} · makes Array
  let _d1000000 = rtcall axion_tritvec_dot t a  ; Δ{a t}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = == i n  ; Δ{}
  let _t0 = == i n  ; Δ{}
  let _t0 = rtcall axion_tritvec_new 10 0  ; Δ{} · makes TritVec
    let _t1 = + i 1  ; Δ{a2}
    let _t1 = mod i 3  ; Δ{}
  let _t1 = newArray 10 0  ; Δ{t} · makes Array
    let t2 = rtcall axion_tritvec_set t i _t2  ; Δ{} · makes TritVec
    let _t2 = - _t1 1  ; Δ{}
    let _t3 = + i 1  ; Δ{t2}
    let _tag = loadraw _p+0  ; Δ{}
  let t = call fillTrit _t0 0 10  ; Δ{_t0} · moves{_t0} · makes TritVec
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
    ret a  ; Δ{}
    ret call fillIdx a2 _t1 n  ; Δ{a2} · moves{a2} · makes Array
    ret call fillTrit t2 _t3 n  ; Δ{t2} · moves{t2} · makes TritVec
  ret _d1000000  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
    ret t  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
