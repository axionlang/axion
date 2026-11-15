














      drop xs
      drop xs
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call foldr$$hoflam11 z ys  ; Δ{y ys} · moves{ys}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call sum ys  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret call hoflam11 y _t0  ; Δ{y}
      ret z  ; Δ{}
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t2 = + acc lo  ; Δ{}
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
    let _t2 = callclo c lo n  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 7  ; Δ{}
    ret 7  ; Δ{}
    ret acc  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
    ret con Nil  ; Δ{} · makes List$Int
    ret n  ; Δ{}
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
  drop fuse$0_clo
  drop fuse$1_clo
  drop fuse$2_clo
  else
  else
  else
  else
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t2 = call range 1 6  ; Δ{} · makes List$Int
  let _t4 = call rangeFused 1 0 fuse$1_clo 1  ; Δ{fuse$1_clo}
  let _t6 = call rangeFused 1 1 fuse$2_clo 1  ; Δ{fuse$2_clo}
  let _t7 = + a c  ; Δ{}
  let _t8 = + _t7 g  ; Δ{}
  let _t9 = + _t8 h  ; Δ{}
  let a = call rangeFusedSum 1 11 0  ; Δ{}
  let c = call rangeFused 1 11 fuse$0_clo 0  ; Δ{fuse$0_clo}
  let fuse$0_clo = closure fuse$0  ; Δ{} · makes heap
  let fuse$1_clo = closure fuse$1  ; Δ{} · makes heap
  let fuse$2_clo = closure fuse$2  ; Δ{} · makes heap
  let g = call foldr$$hoflam11 1 _t2  ; Δ{_t2} · moves{_t2}
  let h = if _t4 then
  let i = if _t6 then
  ret * x acc  ; Δ{}
  ret + 1 acc  ; Δ{}
  ret + _t9 i  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
foldr$$hoflam11 z xs  =
fuse$0 [env ]x acc  =
fuse$1 [env ]x acc  =
fuse$2 [env ]x acc  =
hoflam11 x acc  =
length xs  =
main  =
null xs  =
range lo hi  =
rangeFused lo hi c n  =
rangeFusedSum lo hi acc  =
sum xs  =
