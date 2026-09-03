








        let _t1 = - n 1  ; Δ{}
        ret call drop _t1 ys  ; Δ{} · makes List
        ret con Cons y ys  ; Δ{}
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = call sum ys  ; Δ{}
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret con Nil  ; Δ{}
      ret if _t0 then
    Cons y ys ->
    Cons y ys ->
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
  drop _t1 : List$Int
  drop _t4 : List$Int
  drop _t8 : List$Int
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
  let _t0 = call range 1 11  ; Δ{} · makes List$Int
  let _t1 = call drop 5 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t2 = call sum _t1  ; Δ{_t1}
  let _t3 = call range 1 11  ; Δ{} · makes List$Int
  let _t4 = call drop 2 _t3  ; Δ{_t3} · moves{_t3} · makes List$Int
  let _t5 = call sum _t4  ; Δ{_t4}
  let _t6 = + _t2 _t5  ; Δ{}
  let _t7 = call range 1 11  ; Δ{} · makes List$Int
  let _t8 = call drop 0 _t7  ; Δ{_t7} · moves{_t7} · makes List$Int
  let _t9 = call sum _t8  ; Δ{_t8}
  ret + _t6 _t9  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case xs of
  ret case xs of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
drop n xs  =
main  =
range lo hi  =
rangeFused lo hi c n  =
rangeFusedSum lo hi acc  =
sum xs  =
