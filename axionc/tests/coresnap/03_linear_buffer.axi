





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
  let _t0 = call run buf  ; Δ{} · makes Buffer
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t1 = rtcall axion_buf_new 4096  ; Δ{_t0} · makes Buffer
  let buf' = call encrypt buf  ; Δ{} · makes Buffer
  ret 0  ; Δ{}
  ret buf'  ; Δ{buf'} · moves{buf'}
  ret callclo _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1}
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_buf_free _t0  ; Δ{_t0} · moves{_t0}
  ret rtcall axion_buf_xor buf 90  ; Δ{} · makes Buffer
axion_drop_Array _p  =
axion_drop_List _p  =
encrypt buf  =
lam$0 [env ]buf  =
main  =
run buf  =
