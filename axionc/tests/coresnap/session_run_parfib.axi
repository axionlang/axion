



axion_drop_Array _p  =
axion_drop_List _p  =
    else
  else
  else
fib n  =
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let sess$fa = &main$step  ; Δ{}
  let sess$res = rtcall axion_sess_run sess$sched sess$fa sess$root  ; Δ{}
  let sess$root = rtcall axion_sess_alloc sess$sched 144  ; Δ{}
  let sess$sched = rtcall axion_sess_new  ; Δ{}
  let _t0 = < n 2  ; Δ{}
    let _t1 = - n 1  ; Δ{}
    let _t2 = call fib _t1  ; Δ{}
    let _t3 = - n 2  ; Δ{}
    let _t4 = call fib _t3  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret if _t0 then
    ret n  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret sess$res  ; Δ{}
    ret + _t2 _t4  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
