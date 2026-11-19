








        drop _t1 : String
        let _d1000001 = rtcall axion_strcat "one" _t1  ; Δ{_t1} · makes String
        let _t1 = showInt n  ; Δ{} · makes String
        ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
        ret rtcall axion_strcat "many" ""  ; Δ{} · makes String
        ret rtcall axion_strcat "zero" ""  ; Δ{} · makes String
      0 ->
      1 ->
      _ ->
      drop _t10 : String
      drop _t11 : String
      drop _t12 : String
      drop _t13 : String
      drop _t14 : String
      drop _t15 : String
      drop _t16 : String
      drop _t2 : String
      let _d1000000 = putStrLn _t16  ; Δ{_t16}
      let _d1000000 = rtcall axion_strcat " d" _t2  ; Δ{_t2} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t10 = call kind _t9  ; Δ{} · makes String
      let _t11 = call kind 0  ; Δ{_t10} · makes String
      let _t12 = call kind 1  ; Δ{_t10 _t11} · makes String
      let _t13 = call kind 7  ; Δ{_t10 _t11 _t12} · makes String
      let _t14 = rtcall axion_strcat _t12 _t13  ; Δ{_t10 _t11 _t12 _t13} · makes String
      let _t15 = rtcall axion_strcat _t11 _t14  ; Δ{_t10 _t11 _t14} · makes String
      let _t16 = rtcall axion_strcat _t10 _t15  ; Δ{_t10 _t15} · makes String
      let _t2 = showInt d  ; Δ{} · makes String
      let _t9 = - 0 3  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{}
      ret rtcall axion_strcat "" ""  ; Δ{} · makes String
    _ ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = call /=$Int d 0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret case n of
    ret if _t1 then
    ret rtcall axion_strcat " off" ""  ; Δ{} · makes String
    ret rtcall axion_strcat "neg" ""  ; Δ{} · makes String
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1 : String
  drop _t2 : String
  drop _t3 : String
  drop _t3 : String
  drop _t3 : String
  drop _t5 : String
  drop _t6 : String
  drop _t7 : String
  else
  else
  else
  else
  else
  let _d1000000 = rtcall axion_strcat "<" _t3  ; Δ{_t3} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _rcl2000000 = rtcall axion_strcat "x" _t3  ; Δ{} · makes String
  let _t0 = 1  ; Δ{}
  let _t0 = < n 0  ; Δ{}
  let _t0 = call eq$Int x y  ; Δ{}
  let _t0 = call not on  ; Δ{}
  let _t0 = callclo f x  ; Δ{}
  let _t1 = call status _t0 5  ; Δ{} · makes String
  let _t1 = callclo f y  ; Δ{}
  let _t2 = 0  ; Δ{_t1}
  let _t2 = if _t0 then
  let _t3 = call status _t2 0  ; Δ{_t1} · makes String
  let _t3 = if _t0 then
  let _t3 = rtcall axion_strcat _t2 ">"  ; Δ{} · makes String
  let _t4 = 1  ; Δ{_t1 _t3}
  let _t5 = call status _t4 0  ; Δ{_t1 _t3} · makes String
  let _t6 = rtcall axion_strcat _t3 _t5  ; Δ{_t1 _t3 _t5} · makes String
  let _t7 = rtcall axion_strcat _t1 _t6  ; Δ{_t1 _t6} · makes String
  let _t8 = putStrLn _t7  ; Δ{_t7}
  ret 0  ; Δ{}
  ret == x y  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _rcl2000000  ; Δ{_rcl2000000} · moves{_rcl2000000}
  ret callclo g _t0 _t1  ; Δ{}
  ret case _t8 of
  ret if _t0 then
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
/=$Int x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
eq$Int x y  =
kind n  =
main  =
not b  =
on g f x y  =
status on d  =
