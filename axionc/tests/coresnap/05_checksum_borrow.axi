





axion_drop_Array _p  =
axion_drop_List _p  =
checksum buf  =
    else
  else
encrypt buf  =
lam$0 [env ]_op0 _op1  =
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let sig = call checksum buf  ; Δ{}
  let _t0 = call encrypt buf  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
    let _tag = loadraw _p+0  ; Δ{}
process buf  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret + _op0 _op1  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_buf_xor buf 90  ; Δ{}
  ret rtcall axion_fold_bytes _t0 0 buf  ; Δ{_t0} · moves{_t0}
  ret tuple sig _t0  ; Δ{} · makes heap
  ; Δ{}
  ; Δ{}
