









      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Box _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_Box _dd2  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret call lenX h  ; Δ{}
    Cons h r ->
    Cons y ys ->
    Nil ->
    Nil ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop b0 : Box skip{1}
  drop lst : List$Box
  else
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
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = field xs b  ; Δ{}
  let _t1 = con Cons 1 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t2 = con Nil  ; Δ{_t1} · makes List$Int
  let _t3 = con Cons 2 _t2  ; Δ{_t1 _t2} · moves{_t2} · makes List$Int
  let _t4 = con Nil  ; Δ{b0} · makes List$Int
  let _t5 = con Cons 3 _t4  ; Δ{_t4 b0} · moves{_t4} · makes List$Int
  let _t6 = con Cons 3 _t5  ; Δ{_t5 b0} · moves{_t5} · makes List$Int
  let _t7 = con Nil  ; Δ{b0 b1} · makes List$Box
  let _t8 = call lenX b0  ; Δ{b0 lst}
  let _t9 = call firstX lst  ; Δ{b0 lst}
  let b0 = record Box { xs = _t1 ys = _t3}  ; Δ{_t1 _t3} · moves{_t1 _t3} · makes Box
  let b1 = update b0 { xs = _t6}  ; Δ{_t6 b0} · moves{_t6} · makes heap
  let lst = con Cons b1 _t7  ; Δ{_t7 b0 b1} · moves{_t7 b1} · makes List$Box
  ret + _t8 _t9  ; Δ{b0}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call length _t0  ; Δ{}
  ret case bs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_Box _p  =
axion_drop_Box_skip_1 _p  =
axion_drop_List _p  =
axion_drop_List$Box _p  =
axion_drop_List$Int _p  =
firstX bs  =
lenX b  =
length xs  =
main  =
