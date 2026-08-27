
















add a b  =
axion_drop_Array _p  =
axion_drop_List$Int _p  =
axion_drop_List$P _p  =
axion_drop_List _p  =
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
  drop eta$4 : P
  drop _t0
  drop _t1
  drop _t2
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs : List$Int
      drop xs : List$P
    else
    else
    else
  else
  else
  else
  else
  else
  else
foldr$Int f z xs  =
getA p  =
lam$0 [env ]eta$1 eta$2  =
lam$1 [env ]eta$4  =
lam$2 [env ]eta$6  =
  let _d1000000 = call foldr$Int _t0 0 _t5  ; Δ{_t0 _t5} · moves{_t5}
  let _d1000000 = call getA eta$4  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$P _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
      let _dd3 = rtcall axion_free _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = callclo f y  ; Δ{y ys} · moves{y}
      let _t0 = callclo f y  ; Δ{y ys} · moves{y}
      let _t0 = call foldr$Int f z ys  ; Δ{y ys} · moves{ys}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
      let _t1 = call map$Int f ys  ; Δ{ys} · moves{ys} · makes List
      let _t1 = call map$P f ys  ; Δ{ys} · moves{ys} · makes List
  let _t1 = closure lam$1  ; Δ{_t0} · makes heap
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t2 = + acc lo  ; Δ{}
    let _t2 = callclo c lo n  ; Δ{}
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
  let _t2 = closure lam$2  ; Δ{_t0 _t1} · makes heap
  let _t3 = call range 1 5  ; Δ{_t0 _t1 _t2} · makes List$Int
  let _t4 = call map$Int _t2 _t3  ; Δ{_t0 _t1 _t2 _t3} · moves{_t3} · makes List$P
  let _t5 = call map$P _t1 _t4  ; Δ{_t0 _t1 _t4} · moves{_t4} · makes List$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
map$Int f xs  =
map$P f xs  =
mkP n  =
    Nil ->
    Nil ->
    Nil ->
    P a ->
rangeFused lo hi c n  =
rangeFusedSum lo hi acc  =
range lo hi  =
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
  ret 0  ; Δ{}
  ret + a b  ; Δ{}
    ret acc  ; Δ{}
      ret a  ; Δ{}
  ret call add eta$1 eta$2  ; Δ{}
      ret callclo f y _t0  ; Δ{y} · moves{y}
  ret call mkP eta$6  ; Δ{} · makes P
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
  ret case p of
  ret case xs of
  ret case xs of
  ret case xs of
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
    ret con Nil  ; Δ{} · makes List$Int
  ret con P n  ; Δ{} · makes P
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
    ret n  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
      ret z  ; Δ{}
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
