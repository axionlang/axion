






      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call sum ys  ; Δ{}
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    Cons y ys ->
    Nil ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = - n 1  ; Δ{}
    let _t1 = - n 1  ; Δ{}
    let _t2 = call fib _t1  ; Δ{}
    let _t2 = call replicate _t1 x  ; Δ{} · makes List
    let _t3 = - n 2  ; Δ{}
    let _t4 = call fib _t3  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret + _t2 _t4  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret con Cons x _t2  ; Δ{_t2} · moves{_t2}
    ret con Nil  ; Δ{}
    ret n  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t2 : List$Int
  else
  else
  else
  else
  let _d1000000 = call sum _t2  ; Δ{_t2}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = < n 1  ; Δ{}
  let _t0 = < n 2  ; Δ{}
  let _t0 = call replicate 4 25  ; Δ{} · makes List$Int
  let _t1 = &worker$step  ; Δ{_t0}
  let _t2 = rtcall axion_par_map _t1 48 16 _t0  ; Δ{_t0} · moves{_t0} · makes List
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case xs of
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
fib n  =
main  =
replicate n x  =
sum xs  =
