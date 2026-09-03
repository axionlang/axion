


              ret putStrLn "echoed and closed"  ; Δ{}
            _ ->
          let _t5 = ffi ax_net_close _t0  ; Δ{}
          ret case _t5 of
        _ ->
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t4 = ffi ax_net_close _t1  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t4 of
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = ffi ax_net_listen 8080  ; Δ{}
  let _t1 = ffi ax_net_accept _t0  ; Δ{}
  let _t2 = ffi ax_net_recv _t1  ; Δ{}
  let _t3 = ffi ax_net_send _t1 _t2  ; Δ{}
  ret 0  ; Δ{}
  ret case _t3 of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
