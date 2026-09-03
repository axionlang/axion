





      drop e : Expr
      drop xs
      drop xs : List$Expr
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Expr _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_Expr _dd2  ; Δ{}
      let _t0 = call len rest  ; Δ{rest} · moves{rest}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    Cons e rest ->
    Nil ->
    else
    else
    let _dd0 = loadraw _p+16  ; Δ{}
    let _dd1 = call axion_drop_Expr _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = loadraw _p+8  ; Δ{}
    let _dd3 = call axion_drop_Expr _dd2  ; Δ{}
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
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  else
  else
  let _dd4 = == _tag 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = con Lit 1  ; Δ{} · makes Expr
  let _t1 = con Lit 2  ; Δ{_t0} · makes Expr
  let _t2 = con Lit 3  ; Δ{_t0 _t1} · makes Expr
  let _t3 = con Add _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t1 _t2} · makes Expr
  let _t4 = con Nil  ; Δ{_t0 _t3} · makes List$Expr
  let _t5 = con Cons _t3 _t4  ; Δ{_t0 _t3 _t4} · moves{_t3 _t4} · makes List$Expr
  let _t6 = con Cons _t0 _t5  ; Δ{_t0 _t5} · moves{_t0 _t5} · makes List$Expr
  let _tag = loadraw _p+0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call len _t6  ; Δ{_t6} · moves{_t6}
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_Expr _p  =
axion_drop_List _p  =
axion_drop_List$Expr _p  =
len xs  =
main  =
