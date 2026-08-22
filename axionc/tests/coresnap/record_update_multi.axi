







axion_drop_Array _p  =
axion_drop_List$Int _p  =
axion_drop_List _p  =
axion_drop_Q _p  =
axion_drop_Q_skip_0_2 _p  =
    Cons y ys ->
  drop q0 : Q
  drop q1 : Q skip{0 2}
    else
    else
  else
  else
lenA q  =
length xs  =
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
  let _dd0 = loadraw _p+24  ; Δ{}
  let _dd0 = loadraw _p+24  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd2 = loadraw _p+16  ; Δ{}
  let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
  let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
  let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = loadraw _p+8  ; Δ{}
  let _dd5 = call axion_drop_List$Int _dd4  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = loadraw _p+0  ; Δ{}
  let _dd7 = call axion_drop_List$Int _dd6  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let q0 = record Q { a = _t1 b = _t4 c = _t6 d = _t9}  ; Δ{_t1 _t4 _t6 _t9} · moves{_t1 _t4 _t6 _t9} · makes Q
  let q1 = update q0 { b = _t13 d = _t15}  ; Δ{_t13 _t15 q0} · moves{_t13 _t15} · makes heap
      let _t0 = call length ys  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = field a q  ; Δ{}
  let _t10 = con Nil  ; Δ{q0} · makes List$Int
  let _t11 = con Cons 9 _t10  ; Δ{_t10 q0} · moves{_t10} · makes List$Int
  let _t12 = con Cons 9 _t11  ; Δ{_t11 q0} · moves{_t11} · makes List$Int
  let _t13 = con Cons 9 _t12  ; Δ{_t12 q0} · moves{_t12} · makes List$Int
  let _t14 = con Nil  ; Δ{_t13 q0} · makes List$Int
  let _t15 = con Cons 7 _t14  ; Δ{_t13 _t14 q0} · moves{_t14} · makes List$Int
  let _t16 = call lenA q0  ; Δ{q0 q1}
  let _t17 = call lenA q1  ; Δ{q1}
  let _t1 = con Cons 1 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t2 = con Nil  ; Δ{_t1} · makes List$Int
  let _t3 = con Cons 2 _t2  ; Δ{_t1 _t2} · moves{_t2} · makes List$Int
  let _t4 = con Cons 2 _t3  ; Δ{_t1 _t3} · moves{_t3} · makes List$Int
  let _t5 = con Nil  ; Δ{_t1 _t4} · makes List$Int
  let _t6 = con Cons 3 _t5  ; Δ{_t1 _t4 _t5} · moves{_t5} · makes List$Int
  let _t7 = con Nil  ; Δ{_t1 _t4 _t6} · makes List$Int
  let _t8 = con Cons 4 _t7  ; Δ{_t1 _t4 _t6 _t7} · moves{_t7} · makes List$Int
  let _t9 = con Cons 4 _t8  ; Δ{_t1 _t4 _t6 _t8} · moves{_t8} · makes List$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
    Nil ->
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
      ret + 1 _t0  ; Δ{}
  ret call length _t0  ; Δ{}
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
  ret + _t16 _t17  ; Δ{q1}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
