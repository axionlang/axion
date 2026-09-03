










      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Box _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_Box _dd2  ; Δ{}
      let _t0 = call lenBox b  ; Δ{}
      let _t0 = call lenBox b  ; Δ{}
      let _t0 = call length p  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t1 = call lenRest rest  ; Δ{}
      let _t1 = call lenRest rest  ; Δ{}
      let _t1 = call length q  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret + _t0 _t1  ; Δ{}
      ret + _t0 _t1  ; Δ{}
      ret + _t0 _t1  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    Box p q ->
    Cons b rest ->
    Cons b rest ->
    Cons y ys ->
    Nil ->
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
  ; Δ{}
  ; Δ{}
  drop b0 : Box skip{1}
  drop lst : List$Box
  else
  else
  else
  let _d1000000 = call firstLen lst  ; Δ{b0 lst}
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
  let _t1 = con Cons 1 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t2 = con Nil  ; Δ{_t1} · makes List$Int
  let _t3 = con Cons 2 _t2  ; Δ{_t1 _t2} · moves{_t2} · makes List$Int
  let _t4 = con Cons 2 _t3  ; Δ{_t1 _t3} · moves{_t3} · makes List$Int
  let _t5 = con Nil  ; Δ{b0} · makes List$Int
  let _t6 = con Cons 3 _t5  ; Δ{_t5 b0} · moves{_t5} · makes List$Int
  let _t7 = con Cons 3 _t6  ; Δ{_t6 b0} · moves{_t6} · makes List$Int
  let _t8 = con Cons 3 _t7  ; Δ{_t7 b0} · moves{_t7} · makes List$Int
  let _t9 = con Nil  ; Δ{b0 b1} · makes List$Box
  let b0 = record Box { xs = _t1 ys = _t4}  ; Δ{_t1 _t4} · moves{_t1 _t4} · makes Box
  let b1 = update b0 { xs = _t8}  ; Δ{_t8 b0} · moves{_t8} · makes heap
  let lst = con Cons b1 _t9  ; Δ{_t9 b0 b1} · moves{_t9 b1} · makes List$Box
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{b0}
  ret case b of
  ret case bs of
  ret case bs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_Box _p  =
axion_drop_Box_skip_1 _p  =
axion_drop_List _p  =
axion_drop_List$Box _p  =
axion_drop_List$Int _p  =
firstLen bs  =
lenBox b  =
lenRest bs  =
length xs  =
main  =
