











        ret call myDropWhile p ys  ; Δ{} · makes List
        ret call myDropWhile$$lt5 ys  ; Δ{y ys} · moves{ys} · makes List$Int
        ret con Cons y ys  ; Δ{y ys} · moves{y ys} · makes List$Int
        ret con Cons y ys  ; Δ{}
      drop xs
      drop xs
      else
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call lt5 y  ; Δ{y ys}
      let _t0 = call sum ys  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{} · makes List$Int
      ret if _t0 then
      ret if _t0 then
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
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
    ret acc  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
    ret con Nil  ; Δ{} · makes List$Int
    ret n  ; Δ{}
  ; Δ{y ys}
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
  drop _t1 : List$Int
  drop _t3 : String
  else
  else
  else
  else
  else
  let _d1000000 = putStrLn _t3  ; Δ{_t3}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = call range 1 6  ; Δ{} · makes List$Int
  let _t1 = call myDropWhile$$lt5 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t2 = call sum _t1  ; Δ{_t1}
  let _t3 = call show$Int _t2  ; Δ{} · makes String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret < n 5  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case xs of
  ret case xs of
  ret case xs of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
lt5 n  =
main  =
myDropWhile p xs  =
myDropWhile$$lt5 xs  =
range lo hi  =
rangeFused lo hi c n  =
rangeFusedSum lo hi acc  =
show$Int x  =
sum xs  =
