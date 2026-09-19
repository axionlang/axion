














      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call sum ys  ; Δ{}
      let _t4 = + d 1  ; Δ{}
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret call noDivFrom n _t4  ; Δ{}
    Cons y ys ->
    Nil ->
    else
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = call chunkSize  ; Δ{}
    let _t1 = call isPrime i  ; Δ{}
    let _t2 = * i _t1  ; Δ{}
    let _t2 = if _t1 then
    let _t2 = mod n d  ; Δ{}
    let _t3 = + i 1  ; Δ{}
    let _t3 = + i 1  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t4 = call countRange _t3 hi  ; Δ{}
    let _t4 = call startsFrom _t3 k  ; Δ{} · makes List$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret + _t2 _t4  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret call noDivFrom n 2  ; Δ{}
    ret con Cons _t2 _t4  ; Δ{_t4} · moves{_t4} · makes List$Int
    ret con Nil  ; Δ{} · makes List$Int
    ret if _t3 then
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
  drop _t3 : List$Int
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = call sum _t3  ; Δ{_t3}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = * d d  ; Δ{}
  let _t0 = < n 2  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = call >=$Int i hi  ; Δ{}
  let _t0 = call >=$Int i k  ; Δ{}
  let _t0 = call chunkSize  ; Δ{}
  let _t0 = call chunks  ; Δ{}
  let _t1 = + lo _t0  ; Δ{}
  let _t1 = > _t0 n  ; Δ{}
  let _t1 = call starts _t0  ; Δ{} · makes List$Int
  let _t2 = &worker$step  ; Δ{_t1}
  let _t3 = rtcall axion_par_map _t2 48 16 _t1  ; Δ{_t1} · moves{_t1} · makes List
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 2500  ; Δ{}
  ret 4  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call countRange lo _t1  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call startsFrom 0 k  ; Δ{} · makes List$Int
  ret case xs of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
>=$Int x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
chunkSize  =
chunks  =
countChunk lo  =
countRange i hi  =
isPrime n  =
le$Int x y  =
main  =
noDivFrom n d  =
starts k  =
startsFrom i k  =
sum xs  =
