






        (a, b) ->
axion_drop_Array _p  =
axion_drop_List$Box _p  =
axion_drop_List$tuple$Box$Box _p  =
axion_drop_List _p  =
    Cons h t ->
    Cons t ts ->
countV xs  =
          drop b
      drop h
          drop t
      drop xs
      drop xs
      drop xs
      drop xs : List$Box
    else
    else
    else
  else
  else
  else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$Box _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple$Box$Box _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
      let _dd3 = rtcall axion_free _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = call countV t  ; Δ{t} · moves{t}
          let _t0 = call mapFst ts  ; Δ{ts} · moves{ts} · makes List$Box
  let _t0 = record Box { v = 3}  ; Δ{} · makes Box
  let _t1 = record Box { v = 9}  ; Δ{_t0} · makes Box
  let _t2 = tuple _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes heap
  let _t3 = record Box { v = 4}  ; Δ{_t2} · makes Box
  let _t4 = record Box { v = 9}  ; Δ{_t2 _t3} · makes Box
  let _t5 = tuple _t3 _t4  ; Δ{_t2 _t3 _t4} · moves{_t3 _t4} · makes heap
  let _t6 = con Nil  ; Δ{_t2 _t5} · makes List$tuple$Box$Box
  let _t7 = con Cons _t5 _t6  ; Δ{_t2 _t5 _t6} · moves{_t5 _t6} · makes List$tuple$Box$Box
  let _t8 = con Cons _t2 _t7  ; Δ{_t2 _t7} · moves{_t2 _t7} · makes List$tuple$Box$Box
  let _t9 = call mapFst _t8  ; Δ{_t8} · moves{_t8} · makes List$Box
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
mapFst xs  =
    Nil ->
    Nil ->
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
      ret + 1 _t0  ; Δ{}
  ret call countV _t9  ; Δ{_t9} · moves{_t9}
      ret case t of
  ret case xs of
  ret case xs of
          ret con Cons a _t0  ; Δ{_t0} · moves{_t0} · makes List$Box
      ret con Nil  ; Δ{} · makes List$Box
  ret rtcall axion_array_free _p  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{t ts}
