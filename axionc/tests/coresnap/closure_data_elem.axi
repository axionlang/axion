













add a b  =
axion_drop_Array _p  =
axion_drop_List$Int _p  =
axion_drop_List$P _p  =
axion_drop_List _p  =
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop y
    else
    else
    else
  else
  else
  else
  else
  else
  else
foldr$$add z xs  =
getA p  =
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
      let _t0 = call foldr$$add z ys  ; Δ{y ys} · moves{ys}
      let _t0 = call getA y  ; Δ{y ys}
      let _t0 = call mkP y  ; Δ{y ys} · moves{y} · makes P
  let _t0 = call range 1 5  ; Δ{} · makes List$Int
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
      let _t1 = call map$$getA ys  ; Δ{ys} · moves{ys} · makes List$Int
  let _t1 = call map$$mkP _t0  ; Δ{_t0} · moves{_t0} · makes List$P
      let _t1 = call map$$mkP ys  ; Δ{_t0 ys} · moves{ys} · makes List$P
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t2 = + acc lo  ; Δ{}
    let _t2 = callclo c lo n  ; Δ{}
  let _t2 = call map$$getA _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
map$$getA xs  =
map$$mkP xs  =
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
      ret call add y _t0  ; Δ{y}
  ret call foldr$$add 0 _t2  ; Δ{_t2} · moves{_t2}
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
  ret case p of
  ret case xs of
  ret case xs of
  ret case xs of
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$P
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
    ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$P
  ret con P n  ; Δ{} · makes P
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
