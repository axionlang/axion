




axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Tree _p  =
      drop t
      drop t
    else
  else
  else
    Leaf n ->
      let _dd0 = loadraw _p+16  ; Δ{}
    let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd1 = call axion_drop_Tree _dd0  ; Δ{}
    let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = call axion_drop_Tree _dd2  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = == _tag 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = call sumTree l  ; Δ{l r} · moves{l}
  let _t0 = con Leaf 1  ; Δ{} · makes Tree
      let _t1 = call sumTree r  ; Δ{r} · moves{r}
  let _t1 = con Leaf 2  ; Δ{_t0} · makes Tree
  let _t2 = con Node _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes Tree
    let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
main  =
    Node l r ->
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call sumTree _t2  ; Δ{_t2} · moves{_t2}
  ret case t of
      ret n  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
      ret + _t0 _t1  ; Δ{}
sumTree t  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
