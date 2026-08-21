


axion_drop_Array _p  =
axion_drop_List _p  =
  drop acts : Array
  drop t : TritVec
  drop w32 : I32Array
  drop w8 : I8Array
    else
  else
  let acts = rtcall axion_array_iota 4096  ; Δ{} · makes Array
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = rtcall axion_tritvec_matvec_sum t acts 4096  ; Δ{acts t w32 w8}
  let _t1 = rtcall axion_i8_matvec_sum w8 acts 1000  ; Δ{acts t w32 w8}
  let _t2 = + _t0 _t1  ; Δ{acts t w32}
  let _t3 = rtcall axion_i32_matvec_sum w32 acts 4096  ; Δ{acts t w32}
  let _t4 = + _t2 _t3  ; Δ{acts t}
  let _t5 = rtcall axion_tritvec_matvec_sum t acts 777  ; Δ{acts t}
    let _tag = loadraw _p+0  ; Δ{}
  let t = rtcall axion_tritvec_iota 200003  ; Δ{acts} · makes TritVec
  let w32 = rtcall axion_i32_iota 200003  ; Δ{acts t w8} · makes I32Array
  let w8 = rtcall axion_i8_iota 200003  ; Δ{acts t} · makes I8Array
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret + _t4 _t5  ; Δ{}
  ; Δ{}
  ; Δ{}
