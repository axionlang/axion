



axion_drop_Array _p  =
axion_drop_List _p  =
  drop _t1 : I32Array
    else
  else
  else
fillI32 a i n  =
    let a2 = rtcall axion_i32_set a i _t1  ; Δ{} · makes I32Array
  let _d1000000 = rtcall axion_i32_sum _t1  ; Δ{_t1}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = == i n  ; Δ{}
  let _t0 = rtcall axion_i32_new 100 0  ; Δ{} · makes I32Array
  let _t1 = call fillI32 _t0 0 100  ; Δ{_t0} · moves{_t0} · makes I32Array
    let _t1 = * i 1000  ; Δ{}
    let _t2 = + i 1  ; Δ{a2}
    let _tag = loadraw _p+0  ; Δ{}
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
    ret a  ; Δ{}
    ret call fillI32 a2 _t2 n  ; Δ{a2} · moves{a2} · makes I32Array
  ret _d1000000  ; Δ{}
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
