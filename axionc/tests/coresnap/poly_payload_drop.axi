





axion_drop_Array _p  =
axion_drop_List$P _p  =
axion_drop_List _p  =
build n  =
    Cons y ys ->
      drop xs : List$P
      drop xs : List$P
    else
    else
  else
  else
  else
firstOr xs  =
      let _d1000000 = field a y  ; Δ{xs y ys}
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
  let _t0 = call build 3  ; Δ{} · makes List$P
  let _t0 = == n 0  ; Δ{}
    let _t1 = record P { a = n}  ; Δ{} · makes P
    let _t2 = - n 1  ; Δ{_t1}
    let _t3 = call build _t2  ; Δ{_t1} · makes List$P
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
  ret call firstOr _t0  ; Δ{_t0} · moves{_t0}
  ret case xs of
    ret con Cons _t1 _t3  ; Δ{_t1 _t3} · moves{_t1 _t3} · makes List$P
    ret con Nil  ; Δ{} · makes List$P
      ret _d1000000  ; Δ{}
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
