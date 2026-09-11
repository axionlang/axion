










          drop _t1 : List$String
          drop _t13 : String
          drop p : tuple$String$List$String skip{0 1}
          drop p : tuple$String$List$String skip{0}
          let _d1000000 = call length _t1  ; Δ{_t1 p}
          let _d1000000 = putStrLn _t13  ; Δ{_t13}
          let _t1 = con Cons h t  ; Δ{p} · makes List$String
          let _t10 = con Cons "y" _t9  ; Δ{_t9} · moves{_t9} · makes List$String
          let _t11 = con Cons "x" _t10  ; Δ{_t10} · moves{_t10} · makes List$String
          let _t12 = call rebuildLen _t11  ; Δ{_t11} · moves{_t11}
          let _t13 = showInt _t12  ; Δ{} · makes String
          let _t8 = con Nil  ; Δ{} · makes List$String
          let _t9 = con Cons "z" _t8  ; Δ{_t8} · moves{_t8} · makes List$String
          ret _d1000000  ; Δ{p}
          ret _d1000000  ; Δ{}
          ret x  ; Δ{p}
        (h, t) ->
        (x, _) ->
        _ ->
      drop _t0
      drop _t0
      drop _t0
      drop _t0 : Maybe$tuple$String$List$String
      drop _t6 : String
      drop xs
      drop xs : List$String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = call axion_drop_tuple$String$List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = tuple y ys  ; Δ{y ys} · moves{y ys} · makes heap
      let _t5 = con Nil  ; Δ{} · makes List$String
      let _t6 = call firstOr _t5  ; Δ{_t5} · moves{_t5} · makes String
      let _t7 = putStrLn _t6  ; Δ{_t6}
      ret "none"  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t7 of
      ret case p of
      ret case p of
      ret con Just _t0  ; Δ{_t0} · moves{_t0}
      ret con Nothing  ; Δ{}
    Cons y ys ->
    Cons y ys ->
    Just p ->
    Just p ->
    Nil ->
    Nil ->
    Nothing ->
    Nothing ->
    _ ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{p}
  ; Δ{p}
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
  drop _t3 : String
  else
  else
  else
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call uncons$String xs  ; Δ{} · makes Maybe$tuple$String$List$String
  let _t0 = call uncons$String xs  ; Δ{} · makes Maybe$tuple$String$List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t1 = con Cons "b" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t2 = con Cons "a" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t3 = call firstOr _t2  ; Δ{_t2} · moves{_t2} · makes String
  let _t4 = putStrLn _t3  ; Δ{_t3}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case _t0 of
  ret case _t0 of
  ret case _t4 of
  ret case xs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$tuple$String$List$String _p  =
axion_drop_tuple$String$List$String _p  =
axion_drop_tuple$String$List$String_skip_0 _p  =
firstOr xs  =
length xs  =
main  =
rebuildLen xs  =
uncons$String xs  =
