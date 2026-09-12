









            let _t4 = con Cons z les  ; Δ{_t2 z} · moves{z} · makes List$Int
            let _t5 = con Cons z gre  ; Δ{_t2 z} · moves{z} · makes List$Int
            ret tuple _t4 gre  ; Δ{_t2 _t4} · moves{_t4} · makes heap
            ret tuple les _t5  ; Δ{_t2 _t5} · moves{_t5} · makes heap
          drop _t0 : tuple$List$Int$List$Int skip{0 1}
          drop _t2 : tuple$List$Int$List$Int skip{0 1}
          else
          let _t1 = call sortBy$$ge les  ; Δ{_t0 y} · makes List$Int
          let _t2 = call sortBy$$ge gre  ; Δ{_t0 _t1 y} · makes List$Int
          let _t3 = call ge z pivot  ; Δ{_t2 z}
          let _t3 = con Cons y _t2  ; Δ{_t0 _t1 _t2 y} · moves{_t2 y} · makes List$Int
          ret call append$Int _t1 _t3  ; Δ{_t0 _t1 _t3} · moves{_t1 _t3} · makes List$Int
          ret if _t3 then
        (les, gre) ->
        (les, gre) ->
      drop xs
      drop xs
      drop xs
      drop xs
      drop ys
      drop ys
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call append$Int zs ys  ; Δ{z zs} · moves{zs} · makes List$Int
      let _t0 = call partitionBy$$ge y ys  ; Δ{y ys} · moves{ys} · makes tuple$List$Int$List$Int
      let _t0 = call sum ys  ; Δ{}
      let _t0 = con Nil  ; Δ{} · makes List$Int
      let _t1 = con Nil  ; Δ{_t0} · makes List$Int
      let _t2 = call partitionBy$$ge pivot zs  ; Δ{z zs} · moves{zs} · makes tuple$List$Int$List$Int
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t0 of
      ret case _t2 of
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Nil  ; Δ{} · makes List$Int
      ret tuple _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes heap
      ret ys  ; Δ{}
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
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
    ret 1  ; Δ{}
    ret == a b  ; Δ{}
  ; Δ{_t0 y}
  ; Δ{_t2 z}
  ; Δ{_t2 z}
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
  let _d1000000 = putStrLn _t7  ; Δ{_t7}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = > a b  ; Δ{}
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
  ret case xs of
  ret case xs of
  ret case xs of
  ret case ys of
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
append$Int xs ys  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
ge a b  =
main  =
partitionBy$$ge pivot ys  =
show$Int x  =
sortBy$$ge xs  =
sum xs  =
