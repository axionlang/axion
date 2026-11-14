






      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    drop _t2 : String
    else
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = call axion_drop_Req _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = rtcall axion_strcat "GET" ""  ; Δ{} · makes String
    let _t2 = showInt n  ; Δ{_t1} · makes String
    let _t3 = rtcall axion_strcat "/f" _t2  ; Δ{_t1 _t2} · makes String
    let _t4 = con Req _t1 _t3  ; Δ{_t1 _t3} · moves{_t1 _t3} · makes Req
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret con Left 400  ; Δ{} · makes Either$Int$Req
    ret con Right _t4  ; Δ{_t4} · moves{_t4} · makes Either$Int$Req
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  else
  else
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = < n 0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let sess$fa = &main$step  ; Δ{}
  let sess$res = rtcall axion_sess_run sess$sched sess$fa sess$root  ; Δ{}
  let sess$root = rtcall axion_sess_alloc sess$sched 144  ; Δ{}
  let sess$sched = rtcall axion_sess_new  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret sess$res  ; Δ{}
axion_drop_Array _p  =
axion_drop_Either$Int _p  =
axion_drop_Either$Int$Req _p  =
axion_drop_List _p  =
axion_drop_Req _p  =
main  =
parse n  =
