




      drop xs
      drop xs : List$P
      drop y
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$P _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_free _dd2  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret call dropList$P ys  ; Δ{ys} · moves{ys}
    Cons y ys ->
    Nil ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
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
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = record P { x = 1}  ; Δ{} · makes P
  let _t1 = record P { x = 2}  ; Δ{_t0} · makes P
  let _t2 = record P { x = 3}  ; Δ{_t0 _t1} · makes P
  let _t3 = con Nil  ; Δ{_t0 _t1 _t2} · makes List$P
  let _t4 = con Cons _t2 _t3  ; Δ{_t0 _t1 _t2 _t3} · moves{_t2 _t3} · makes List$P
  let _t5 = con Cons _t1 _t4  ; Δ{_t0 _t1 _t4} · moves{_t1 _t4} · makes List$P
  let _t6 = con Cons _t0 _t5  ; Δ{_t0 _t5} · moves{_t0 _t5} · makes List$P
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call dropList$P _t6  ; Δ{_t6} · moves{_t6}
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$P _p  =
dropList$P xs  =
main  =
