







      drop _t4 : Lst
      drop _t6 : String
      let _d1000000 = putStrLn _t6  ; Δ{_t6}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_Lst _dd0  ; Δ{}
      let _t0 = call sumL ys  ; Δ{}
      let _t4 = con LNil  ; Δ{} · makes Lst
      let _t5 = call use2 _t4  ; Δ{_t4}
      let _t6 = showInt _t5  ; Δ{} · makes String
      ret + x _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{}
    LCons x ys ->
    LNil ->
    _ ->
    else
    else
    let $aliascopy0 = call axion_copy_Lst s  ; Δ{} · makes Lst
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = - n 1  ; Δ{}
    let _t2 = call build _t1  ; Δ{} · makes Lst
    let _t2 = con LNil  ; Δ{} · makes Lst
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret $aliascopy0  ; Δ{$aliascopy0} · moves{$aliascopy0}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret con LCons 42 _t2  ; Δ{_t2} · moves{_t2} · makes Lst
    ret con LCons n _t2  ; Δ{_t2} · moves{_t2} · makes Lst
    ret con LNil  ; Δ{} · makes Lst
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : Lst
  drop _t2 : String
  drop r : Lst
  else
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = == n 0  ; Δ{}
  let _t0 = call build 3  ; Δ{} · makes Lst
  let _t0 = call sumL r  ; Δ{r}
  let _t0 = call sumL s  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = call sumL xs  ; Δ{}
  let _t1 = call use2 _t0  ; Δ{_t0}
  let _t2 = showInt _t1  ; Δ{} · makes String
  let _t3 = putStrLn _t2  ; Δ{_t2}
  let r = call tagOr xs  ; Δ{} · makes Lst
  ret + _t0 _t1  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case _t3 of
  ret case xs of
  ret if _t0 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Lst _p  =
build n  =
main  =
sumL xs  =
tagOr s  =
use2 xs  =
