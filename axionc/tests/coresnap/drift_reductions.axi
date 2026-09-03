



      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = * i 37  ; Δ{}
    let _t2 = mod _t1 255  ; Δ{}
    let _t3 = - _t2 127  ; Δ{}
    let _t4 = + i 1  ; Δ{a2}
    let _tag = loadraw _p+0  ; Δ{}
    let a2 = rtcall axion_i8_set a i _t3  ; Δ{} · makes I8Array
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret a  ; Δ{}
    ret call seed a2 _t4 n  ; Δ{a2} · moves{a2} · makes I8Array
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop acts : Array
  drop ar : Array
  drop iv : I32Array
  drop v : I8Array
  drop w : I8Array
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = == i n  ; Δ{}
  let _t0 = rtcall axion_i8_iota 40000  ; Δ{} · makes I8Array
  let _t1 = + d1 d2  ; Δ{}
  let _t2 = + _t1 s1  ; Δ{}
  let _t3 = + _t2 d3  ; Δ{}
  let _t4 = + _t3 s2  ; Δ{}
  let _t5 = + _t4 d4  ; Δ{}
  let acts = rtcall axion_array_iota 40000  ; Δ{v w} · makes Array
  let ar = rtcall axion_array_iota 40000  ; Δ{acts} · makes Array
  let d1 = rtcall axion_i8_dot_i8 w v  ; Δ{acts v w}
  let d2 = rtcall axion_i8_dot w acts  ; Δ{acts w}
  let d3 = rtcall axion_array_dot ar acts  ; Δ{acts ar}
  let d4 = rtcall axion_i32_dot iv acts  ; Δ{acts iv}
  let iv = rtcall axion_i32_iota 40000  ; Δ{acts} · makes I32Array
  let s1 = rtcall axion_i8_sum w  ; Δ{acts w}
  let s2 = rtcall axion_array_sum ar  ; Δ{acts ar}
  let s3 = rtcall axion_i32_sum iv  ; Δ{iv}
  let v = rtcall axion_i8_iota 40000  ; Δ{w} · makes I8Array
  let w = call seed _t0 0 40000  ; Δ{_t0} · moves{_t0} · makes I8Array
  ret + _t5 s3  ; Δ{}
  ret 0  ; Δ{}
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
seed a i n  =
