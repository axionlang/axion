












            let _t4 = con Cons z les  ; Δ{_t2 z} · moves{z}
            let _t4 = con Cons z les  ; Δ{_t2 z} · moves{z} · makes List$String
            let _t5 = con Cons z gre  ; Δ{_t2 z} · moves{z}
            let _t5 = con Cons z gre  ; Δ{_t2 z} · moves{z} · makes List$String
            ret tuple _t4 gre  ; Δ{_t2 _t4} · moves{_t4} · makes heap
            ret tuple _t4 gre  ; Δ{_t2} · makes heap
            ret tuple les _t5  ; Δ{_t2 _t5} · moves{_t5} · makes heap
            ret tuple les _t5  ; Δ{_t2} · makes heap
          drop _t0 : tuple$List$String$List$String skip{0 1}
          drop _t0 : tuple$List$String$List$String skip{0 1}
          drop _t2 : tuple$List$String$List$String skip{0 1}
          drop _t2 : tuple$List$String$List$String skip{0 1}
          else
          else
          let _t1 = call sort$String les  ; Δ{_t0 y} · makes List$String
          let _t1 = call sortBy$$byLen les  ; Δ{_t0 y} · makes List$String
          let _t2 = call sort$String gre  ; Δ{_t0 _t1 y} · makes List$String
          let _t2 = call sortBy$$byLen gre  ; Δ{_t0 _t1 y} · makes List$String
          let _t3 = call byLen z pivot  ; Δ{_t2 z}
          let _t3 = call le$String z pivot  ; Δ{_t2 z}
          let _t3 = con Cons y _t2  ; Δ{_t0 _t1 _t2 y} · moves{_t2 y}
          let _t3 = con Cons y _t2  ; Δ{_t0 _t1 _t2 y} · moves{_t2 y} · makes List$String
          ret call append _t1 _t3  ; Δ{_t0 _t1} · moves{_t1} · makes List
          ret call append$String _t1 _t3  ; Δ{_t0 _t1 _t3} · moves{_t1 _t3} · makes List$String
          ret if _t3 then
          ret if _t3 then
        (les, gre) ->
        (les, gre) ->
        (les, gre) ->
        (les, gre) ->
      drop _t0 : String
      drop _t1 : String
      drop _t13 : List$String
      drop _t14 : String
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs : List$String
      drop ys
      drop ys
      drop ys
      drop ys
      let _d1000000 = putStr _t14  ; Δ{_t14}
      let _d1000000 = rtcall axion_strcat s _t1  ; Δ{_t1} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call append zs ys  ; Δ{z zs} · moves{zs} · makes List
      let _t0 = call append$String zs ys  ; Δ{z zs} · moves{zs} · makes List$String
      let _t0 = call partitionBy$$byLen y ys  ; Δ{y ys} · moves{ys} · makes tuple$List$String$List$String
      let _t0 = call partitionLe$String y ys  ; Δ{y ys} · moves{ys} · makes tuple$List$String$List$String
      let _t0 = call unlines ss  ; Δ{} · makes String
      let _t0 = con Nil  ; Δ{}
      let _t0 = con Nil  ; Δ{} · makes List$String
      let _t1 = con Nil  ; Δ{_t0} · makes List$String
      let _t1 = con Nil  ; Δ{}
      let _t1 = rtcall axion_strcat "\n" _t0  ; Δ{_t0} · makes String
      let _t10 = con Cons "dddd" _t9  ; Δ{_t9} · moves{_t9} · makes List$String
      let _t11 = con Cons "a" _t10  ; Δ{_t10} · moves{_t10} · makes List$String
      let _t12 = con Cons "ccc" _t11  ; Δ{_t11} · moves{_t11} · makes List$String
      let _t13 = call sortBy$$byLen _t12  ; Δ{_t12} · moves{_t12} · makes List$String
      let _t14 = call unlines _t13  ; Δ{_t13} · makes String
      let _t2 = call partitionBy$$byLen pivot zs  ; Δ{z zs} · moves{zs} · makes tuple$List$String$List$String
      let _t2 = call partitionLe$String pivot zs  ; Δ{z zs} · moves{zs} · makes tuple$List$String$List$String
      let _t8 = con Nil  ; Δ{} · makes List$String
      let _t9 = con Cons "bb" _t8  ; Δ{_t8} · moves{_t8} · makes List$String
      ret ""  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{}
      ret case _t0 of
      ret case _t0 of
      ret case _t2 of
      ret case _t2 of
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{} · makes List$String
      ret tuple _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes heap
      ret tuple _t0 _t1  ; Δ{} · makes heap
      ret ys  ; Δ{}
      ret ys  ; Δ{}
    Cons s ss ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
    Cons z zs ->
    Cons z zs ->
    Cons z zs ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    _ ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t2 = rtcall axion_str_cmp x y  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret == _t2 0  ; Δ{}
  ; Δ{_t0 y}
  ; Δ{_t0 y}
  ; Δ{_t2 z}
  ; Δ{_t2 z}
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t5 : List$String
  drop _t6 : String
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = rtcall axion_str_cmp x y  ; Δ{}
  let _t0 = rtcall axion_str_len a  ; Δ{}
  let _t1 = < _t0 0  ; Δ{}
  let _t1 = con Cons "date" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = rtcall axion_str_len b  ; Δ{}
  let _t2 = con Cons "kiwi" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t3 = con Cons "fig" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t4 = con Cons "pear" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t5 = call sort$String _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t6 = call unlines _t5  ; Δ{_t5} · makes String
  let _t7 = putStr _t6  ; Δ{_t6}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret < _t0 _t1  ; Δ{}
  ret case _t7 of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case ys of
  ret case ys of
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
append xs ys  =
append$String xs ys  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
byLen a b  =
le$String x y  =
main  =
partitionBy$$byLen pivot ys  =
partitionLe$String pivot ys  =
sort$String xs  =
sortBy$$byLen xs  =
unlines xs  =
