









      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t4 = rtcall axion_str_at i s  ; Δ{}
      ret - _t4 48  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t3 = call isDigit _t2  ; Δ{}
    let _t5 = if _t3 then
    let _t6 = + i 1  ; Δ{}
    let _t7 = call digits s _t6  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret + _t5 _t7  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret call <=$Int c 57  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  else
  else
  else
  else
  let _d1000000 = rtcall axion_strcat s _t0  ; Δ{_t0} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = < x y  ; Δ{}
  let _t0 = call >=$Int c 48  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = showInt n  ; Δ{} · makes String
  let _t1 = call >=$Int i _t0  ; Δ{}
  let sess$fa = &main$step  ; Δ{}
  let sess$res = rtcall axion_sess_run sess$sched sess$fa sess$root  ; Δ{}
  let sess$root = rtcall axion_sess_alloc sess$sched 48  ; Δ{}
  let sess$sched = rtcall axion_sess_new  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret call grow "s" n  ; Δ{} · makes String
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret sess$res  ; Δ{}
<=$Int x y  =
>=$Int x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
digits s i  =
grow s n  =
isDigit c  =
le$Int x y  =
main  =
seed n  =
