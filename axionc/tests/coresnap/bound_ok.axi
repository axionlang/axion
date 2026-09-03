



          ret callclo close d  ; Δ{}
        _ ->
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t0 = callclo close c  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t0 of
    (c, d) ->
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
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t1 = case newChannel of
  let sess$fa = &main$step  ; Δ{}
  let sess$res = rtcall axion_sess_run sess$sched sess$fa sess$root  ; Δ{}
  let sess$root = rtcall axion_sess_alloc sess$sched 32  ; Δ{}
  let sess$sched = rtcall axion_sess_new  ; Δ{}
  ret 0  ; Δ{}
  ret callclo bound _t1  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret sess$res  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
main  =
