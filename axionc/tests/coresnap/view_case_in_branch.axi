









        drop a : String
        drop p
        drop xs
        drop xs
        drop xs
        drop xs
        let _t0 = + y 1  ; Δ{}
        let _t1 = + y 1  ; Δ{y ys}
        ret b  ; Δ{}
        ret con Cons _t0 ys  ; Δ{} · makes List$Int
        ret con Cons _t1 ys  ; Δ{y ys} · moves{ys} · makes List$Int
        ret con Nil  ; Δ{} · makes List$Int
        ret con Nil  ; Δ{} · makes List$Int
      Cons y ys ->
      Cons y ys ->
      Nil ->
      Nil ->
      Pair a b ->
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    Cons y ys ->
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
    let _t1 = - _p0 1  ; Δ{}
    let _t2 = - _p0 1  ; Δ{}
    let _t2 = - k 1  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let p = _p1  ; Δ{}
    let p$1 = _p1  ; Δ{}
    let xs = _p1  ; Δ{}
    let xs$1 = _p1  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret call bumpClause _t2 xs$1  ; Δ{} · makes List$Int
    ret call bumpIf _t2 xs  ; Δ{} · makes List$Int
    ret call rest _t1 p$1  ; Δ{} · makes List$String
    ret case p of
    ret case xs of
    ret case xs of
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t10 : List$Int
  drop _t17 : List$String
  drop _t4 : List$Int
  else
  else
  else
  else
  else
  else
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = == _p0 0  ; Δ{}
  let _t0 = == k 0  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t1 = == _p0 0  ; Δ{}
  let _t1 = con Cons 3 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t10 = call bumpIf 1 _t9  ; Δ{_t9} · moves{_t9} · makes List$Int
  let _t11 = call length _t10  ; Δ{_t10}
  let _t12 = + _t5 _t11  ; Δ{}
  let _t13 = con Nil  ; Δ{} · makes List$String
  let _t14 = con Cons "b" _t13  ; Δ{_t13} · moves{_t13} · makes List$String
  let _t15 = con Cons "a" _t14  ; Δ{_t14} · moves{_t14} · makes List$String
  let _t16 = con Pair "x" _t15  ; Δ{_t15} · moves{_t15} · makes Pair
  let _t17 = call rest 1 _t16  ; Δ{_t16} · moves{_t16} · makes List$String
  let _t18 = call length _t17  ; Δ{_t17}
  let _t2 = con Cons 2 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t3 = con Cons 1 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  let _t4 = call bumpClause 2 _t3  ; Δ{_t3} · moves{_t3} · makes List$Int
  let _t5 = call length _t4  ; Δ{_t4}
  let _t6 = con Nil  ; Δ{} · makes List$Int
  let _t7 = con Cons 6 _t6  ; Δ{_t6} · moves{_t6} · makes List$Int
  let _t8 = con Cons 5 _t7  ; Δ{_t7} · moves{_t7} · makes List$Int
  let _t9 = con Cons 4 _t8  ; Δ{_t8} · moves{_t8} · makes List$Int
  ret + _t12 _t18  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case xs of
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_List$String _p  =
axion_drop_Pair _p  =
bumpClause _p0 _p1  =
bumpIf k xs  =
length xs  =
main  =
rest _p0 _p1  =
