







      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    Cons y ys ->
    Nil ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop b0 : Box
  drop b1 : Box skip{1}
  else
  else
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = field xs b  ; Δ{}
  let _t1 = con Cons 2 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t10 = con Cons 8 _t9  ; Δ{_t9 b0} · moves{_t9} · makes List$Int
  let _t11 = con Cons 7 _t10  ; Δ{_t10 b0} · moves{_t10} · makes List$Int
  let _t12 = call lenXs b0  ; Δ{b0 b1}
  let _t13 = call lenXs b1  ; Δ{b1}
  let _t2 = con Cons 1 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t3 = con Nil  ; Δ{_t2} · makes List$Int
  let _t4 = con Cons 5 _t3  ; Δ{_t2 _t3} · moves{_t3} · makes List$Int
  let _t5 = con Cons 4 _t4  ; Δ{_t2 _t4} · moves{_t4} · makes List$Int
  let _t6 = con Cons 3 _t5  ; Δ{_t2 _t5} · moves{_t5} · makes List$Int
  let _t7 = con Nil  ; Δ{b0} · makes List$Int
  let _t8 = con Cons 10 _t7  ; Δ{_t7 b0} · moves{_t7} · makes List$Int
  let _t9 = con Cons 9 _t8  ; Δ{_t8 b0} · moves{_t8} · makes List$Int
  let b0 = record Box { xs = _t2 ys = _t6}  ; Δ{_t2 _t6} · moves{_t2 _t6} · makes Box
  let b1 = update b0 { xs = _t11}  ; Δ{_t11 b0} · moves{_t11} · makes heap
  ret + _t12 _t13  ; Δ{b1}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call length _t0  ; Δ{}
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_Box _p  =
axion_drop_Box_skip_1 _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
lenXs b  =
length xs  =
main  =
