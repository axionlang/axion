









axion_drop_Array _p  =
axion_drop_Box _p  =
axion_drop_Box_skip_0 _p  =
axion_drop_Box_skip_1 _p  =
axion_drop_List$Int _p  =
axion_drop_List _p  =
    Cons y ys ->
  drop b0 : Box
  drop b1 : Box skip{1}
  drop b2 : Box skip{0}
    else
    else
  else
  else
length xs  =
lenX b  =
lenY b  =
  let b0 = record Box { xs = _t1 ys = _t3}  ; Δ{_t1 _t3} · moves{_t1 _t3} · makes Box
  let b1 = update b0 { xs = _t6}  ; Δ{_t6 b0} · moves{_t6} · makes heap
  let b2 = update b1 { ys = _t10}  ; Δ{_t10 b1} · moves{_t10} · makes heap
  let _dd0 = loadraw _p+0  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
  let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = call length ys  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = field xs b  ; Δ{}
  let _t0 = field ys b  ; Δ{}
  let _t10 = con Cons 4 _t9  ; Δ{_t9 b1} · moves{_t9} · makes List$Int
  let _t11 = call lenX b2  ; Δ{b1 b2}
  let _t12 = call lenY b2  ; Δ{b1 b2}
  let _t1 = con Cons 1 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t2 = con Nil  ; Δ{_t1} · makes List$Int
  let _t3 = con Cons 2 _t2  ; Δ{_t1 _t2} · moves{_t2} · makes List$Int
  let _t4 = con Nil  ; Δ{b0} · makes List$Int
  let _t5 = con Cons 3 _t4  ; Δ{_t4 b0} · moves{_t4} · makes List$Int
  let _t6 = con Cons 3 _t5  ; Δ{_t5 b0} · moves{_t5} · makes List$Int
  let _t7 = con Nil  ; Δ{b1} · makes List$Int
  let _t8 = con Cons 4 _t7  ; Δ{_t7 b1} · moves{_t7} · makes List$Int
  let _t9 = con Cons 4 _t8  ; Δ{_t8 b1} · moves{_t8} · makes List$Int
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
  ret 0  ; Δ{}
      ret + 1 _t0  ; Δ{}
  ret call length _t0  ; Δ{}
  ret call length _t0  ; Δ{}
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
  ret + _t11 _t12  ; Δ{b1 b2}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
