











            let _t4 = con Cons z les  ; Δ{_t2 z} · moves{z}
            let _t5 = con Cons z gre  ; Δ{_t2 z} · moves{z}
            ret tuple _t4 gre  ; Δ{_t2} · makes heap
            ret tuple les _t5  ; Δ{_t2} · makes heap
          drop _t0 : tuple2$List$String$List$String skip{0 1}
          drop _t2 : tuple2$List$String$List$String skip{0 1}
          drop a : String
          drop a : String
          drop b : String
          drop b : String
          drop r
          drop r
          drop r
          drop r
          else
          let _t0 = con Nil  ; Δ{a} · makes List$String
          let _t0 = rtcall axion_strcat a b  ; Δ{a b m} · makes String
          let _t1 = call sort$String les  ; Δ{_t0 y} · makes List$String
          let _t1 = call ulines$ulPairs m  ; Δ{_t0 a m} · moves{m} · makes List$String
          let _t1 = rtcall axion_strcat a b  ; Δ{a b m} · makes String
          let _t2 = call sort$String gre  ; Δ{_t0 _t1 y} · makes List$String
          let _t2 = call ulines$ulPairs m  ; Δ{_t1 a m} · moves{m} · makes List$String
          let _t2 = con Cons _t0 _t1  ; Δ{_t0 _t1 a} · moves{_t0 _t1} · makes List$String
          let _t3 = call le$String z pivot  ; Δ{_t2 z}
          let _t3 = con Cons y _t2  ; Δ{_t0 _t1 _t2 y} · moves{_t2 y}
          ret a  ; Δ{a} · moves{a}
          ret call append _t1 _t3  ; Δ{_t0 _t1} · moves{_t1} · makes List
          ret call ulines$ulBal _t2  ; Δ{_t2} · moves{_t2} · makes String
          ret con Cons _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes List$String
          ret con Cons a _t0  ; Δ{_t0 a} · moves{_t0 a} · makes List$String
          ret if _t3 then
        (les, gre) ->
        (les, gre) ->
        Cons b m ->
        Cons b m ->
        Nil ->
        Nil ->
      drop xs
      drop xs
      drop xs
      drop xs : List$String
      drop y : String
      drop ys
      drop ys
      drop ys
      drop ys
      drop ys
      drop ys
      drop ys
      drop ys
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call append zs ys  ; Δ{z zs} · moves{zs} · makes List
      let _t0 = call partitionLe$String y ys  ; Δ{y ys} · moves{ys} · makes tuple2$List$String$List$String
      let _t0 = con Nil  ; Δ{}
      let _t0 = rtcall axion_strcat y "\n"  ; Δ{y yss} · makes String
      let _t1 = call ulines$ulTag yss  ; Δ{_t0 yss} · moves{yss} · makes List$String
      let _t1 = con Nil  ; Δ{}
      let _t2 = call partitionLe$String pivot zs  ; Δ{z zs} · moves{zs} · makes tuple2$List$String$List$String
      ret ""  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t0 of
      ret case _t2 of
      ret case r of
      ret case r of
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$String
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret tuple _t0 _t1  ; Δ{} · makes heap
      ret ys  ; Δ{}
    Cons a r ->
    Cons a r ->
    Cons y ys ->
    Cons y yss ->
    Cons z zs ->
    Cons z zs ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
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
  ; Δ{_t2 z}
  ; Δ{_t2 z}
  ; Δ{a r}
  ; Δ{a r}
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
  drop _t6 : String
  else
  else
  else
  let _d1000000 = putStr _t6  ; Δ{_t6}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = call ulines$ulTag xs  ; Δ{} · makes List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = rtcall axion_str_cmp x y  ; Δ{}
  let _t1 = < _t0 0  ; Δ{}
  let _t1 = con Cons "aa" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t2 = con Cons "bb" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t3 = con Cons "cc" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t4 = con Cons "dd" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t5 = call sort$String _t4  ; Δ{_t4} · moves{_t4} · makes List$String
  let _t6 = call ulines _t5  ; Δ{_t5} · moves{_t5} · makes String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call ulines$ulBal _t0  ; Δ{_t0} · moves{_t0} · makes String
  ret case xs of
  ret case xs of
  ret case ys of
  ret case ys of
  ret case ys of
  ret case ys of
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
append xs ys  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
le$String x y  =
main  =
partitionLe$String pivot ys  =
sort$String xs  =
ulines xs  =
ulines$ulBal ys  =
ulines$ulPairs ys  =
ulines$ulTag ys  =
