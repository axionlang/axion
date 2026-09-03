












        let _t1 = call filter p ys  ; Δ{} · makes List
        ret call filter p ys  ; Δ{} · makes List
        ret con Cons y _t1  ; Δ{_t1} · moves{_t1}
      drop _t0
      drop _t1
      drop xs
      drop xs
      drop xs
      drop xs
      drop ys : List$Int
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call append$Int zs ys  ; Δ{z zs} · moves{zs} · makes List$Int
      let _t0 = call sum ys  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = closure lam$0 y  ; Δ{y ys} · makes heap
      let _t1 = closure lam$1 y  ; Δ{less y ys} · makes heap
      let _t2 = call sortBy$$ge less  ; Δ{greq less y} · moves{less} · makes List$Int
      let _t3 = call sortBy$$ge greq  ; Δ{_t2 greq y} · moves{greq} · makes List$Int
      let _t4 = con Cons y _t3  ; Δ{_t2 _t3 y} · moves{_t3 y} · makes List$Int
      let greq = call filter _t1 ys  ; Δ{_t1 less y ys} · makes List$Int
      let less = call filter _t0 ys  ; Δ{_t0 y ys} · makes List$Int
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret call append$Int _t2 _t4  ; Δ{_t2 _t4} · moves{_t2 _t4} · makes List$Int
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{} · makes List$Int
      ret if _t0 then
      ret ys  ; Δ{}
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
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
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret == a b  ; Δ{}
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
  drop _t5 : List$Int
  drop _t7 : String
  else
  else
  else
  else
  let _d1000000 = putStrLn _t7  ; Δ{_t7}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = > a b  ; Δ{}
  let _t0 = call ge z y  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t1 = con Cons 5 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t2 = con Cons 1 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t3 = con Cons 9 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  let _t4 = con Cons 2 _t3  ; Δ{_t3} · moves{_t3} · makes List$Int
  let _t5 = call sortBy$$ge _t4  ; Δ{_t4} · moves{_t4} · makes List$Int
  let _t6 = call sum _t5  ; Δ{_t5}
  let _t7 = call show$Int _t6  ; Δ{} · makes String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call ge z y  ; Δ{}
  ret call not _t0  ; Δ{}
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret if _t0 then
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
append$Int xs ys  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
filter p xs  =
ge a b  =
lam$0 [env y]z  =
lam$1 [env y]z  =
main  =
not b  =
show$Int x  =
sortBy$$ge xs  =
sum xs  =
