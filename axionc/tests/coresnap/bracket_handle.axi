









          drop _t4
          drop _t4
          let _t5 = + x y  ; Δ{x y}
          ret con Left $bindErr  ; Δ{$bindErr x} · moves{$bindErr} · makes Either$String$Int
          ret con Right _t5  ; Δ{x y} · makes Either$String$Int
        Left $bindErr ->
        Right y ->
      drop _t1
      drop _t1
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = ffi abs h  ; Δ{x}
      let _t3 = - _t2 1  ; Δ{x}
      let _t4 = call check _t3  ; Δ{x} · makes Either$String$Int
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t4 of
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$Int
      ret r  ; Δ{r} · moves{r}
      ret r  ; Δ{}
    Left $bindErr ->
    Right x ->
    _ ->
    _ ->
    else
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret con Left "bad"  ; Δ{} · makes Either$String$Int
    ret con Right n  ; Δ{} · makes Either$String$Int
  ; Δ{_t1}
  ; Δ{_t4 x}
  ; Δ{r}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  else
  else
  else
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 0  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = > n 0  ; Δ{}
  let _t0 = ffi abs h  ; Δ{}
  let _t0 = ffi abs h [o]  ; Δ{r}
  let _t0 = ffi abs h [o]  ; Δ{}
  let _t1 = call check _t0  ; Δ{} · makes Either$String$Int
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let h = ffi abs n  ; Δ{}
  let h = ffi abs n  ; Δ{}
  let r = call hoflam9 h  ; Δ{} · makes Either$String$Int
  let r = callclo body h  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call withDev$$hoflam9 n  ; Δ{} · makes Either$String$Int
  ret case _t0 of
  ret case _t0 of
  ret case _t1 of
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_Either$String _p  =
axion_drop_Either$String$Int _p  =
axion_drop_List _p  =
check n  =
hoflam9 h  =
main  =
withDev n body  =
withDev$$hoflam9 n  =
work n  =
