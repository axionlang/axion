





      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let $aliascopy0 = rtcall axion_strcat s ""  ; Δ{} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret $aliascopy0  ; Δ{$aliascopy0} · moves{$aliascopy0}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret rtcall axion_strcat s ""  ; Δ{} · makes String
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  else
  else
  let _d1000000 = rtcall axion_strcat "t" _t0  ; Δ{_t0} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = showInt n  ; Δ{} · makes String
  let _t1 = > _t0 100  ; Δ{}
  let sess$fa = &main$step  ; Δ{}
  let sess$res = rtcall axion_sess_run sess$sched sess$fa sess$root  ; Δ{}
  let sess$root = rtcall axion_sess_alloc sess$sched 72  ; Δ{}
  let sess$sched = rtcall axion_sess_new  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_strcat s "!"  ; Δ{} · makes String
  ret sess$res  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
same s  =
shout s  =
tagOf n  =
