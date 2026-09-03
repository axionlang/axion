







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
      ret call length xs  ; Δ{}
    Box xs ->
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
    let _t1 = - k 1  ; Δ{}
    let _t2 = field items acc  ; Δ{}
    let _t3 = con Cons k _t2  ; Δ{} · makes List$Int
    let _t4 = record Box { items = _t3}  ; Δ{_t3} · moves{_t3} · makes Box
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret acc  ; Δ{}
    ret call build _t1 _t4  ; Δ{_t4} · moves{_t4} · makes Box
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t2 : Box
  else
  else
  else
  let _d1000000 = call lenB _t2  ; Δ{_t2}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = < k 1  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t1 = record Box { items = _t0}  ; Δ{_t0} · moves{_t0} · makes Box
  let _t2 = call build 5 _t1  ; Δ{_t1} · moves{_t1} · makes Box
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case b of
  ret case xs of
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_Box _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
build k acc  =
lenB b  =
length xs  =
main  =
