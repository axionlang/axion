



axion_drop_Array _p  =
axion_drop_List$P _p  =
axion_drop_List _p  =
    Cons y _ ->
      drop lst : List$P
      drop lst : List$P
    else
    else
  else
  else
      let _d1000000 = field x y  ; Δ{lst y}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$P _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
      let _dd3 = rtcall axion_free _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
  let lst = con Cons _t0 _t3  ; Δ{_t0 _t3} · moves{_t0 _t3} · makes List$P
  let _t0 = record P { x = 5}  ; Δ{} · makes P
  let _t1 = record P { x = 6}  ; Δ{_t0} · makes P
  let _t2 = con Nil  ; Δ{_t0 _t1} · makes List$P
  let _t3 = con Cons _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t1 _t2} · makes List$P
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
  ret case lst of
      ret _d1000000  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{lst}
