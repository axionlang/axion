










          drop e
          drop e : Either$String$Int
          drop s : String
          let _d1000000 = rtcall axion_str_len s  ; Δ{c s}
          ret 0  ; Δ{c}
          ret _d1000000  ; Δ{c}
        Left s ->
        Right _ ->
      drop a
      drop a : Either$String$Int
      drop b
      drop b : Maybe$Either$String$Int
      drop c
      drop rest : List
      drop s : String
      drop s : String
      let _d1000001 = rtcall axion_str_len s  ; Δ{b c s}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_Either$String$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t8 = rtcall axion_str_len s  ; Δ{rest s}
      let _t9 = call length rest  ; Δ{rest}
      ret + 1 _t0  ; Δ{}
      ret + _t8 _t9  ; Δ{}
      ret 0  ; Δ{b c}
      ret 0  ; Δ{c}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000001  ; Δ{b c}
      ret case e of
    Box s rest ->
    Cons y ys ->
    Just e ->
    Left s ->
    Nil ->
    Nothing ->
    Right _ ->
    else
    else
    else
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
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
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{a b c}
  ; Δ{b c}
  ; Δ{c e}
  ; Δ{c}
  ; Δ{}
  ; Δ{}
  ; Δ{}
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
  else
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = showInt 123  ; Δ{} · makes String
  let _t1 = showInt 45  ; Δ{a} · makes String
  let _t10 = case c of
  let _t2 = con Left _t1  ; Δ{_t1 a} · moves{_t1} · makes Either$String$Int
  let _t3 = rtcall axion_strcat "x" "y"  ; Δ{a b} · makes String
  let _t4 = con Nil  ; Δ{_t3 a b} · makes List$Int
  let _t5 = case a of
  let _t6 = case b of
  let _t7 = + _t5 _t6  ; Δ{c}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let a = con Left _t0  ; Δ{_t0} · moves{_t0} · makes Either$String$Int
  let b = con Just _t2  ; Δ{_t2 a} · moves{_t2} · makes Maybe$Either$String$Int
  let c = con Box _t3 _t4  ; Δ{_t3 _t4 a b} · moves{_t3 _t4} · makes Box$String$Int
  ret + _t7 _t10  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_Box _p  =
axion_drop_Box$String _p  =
axion_drop_Box$String$Int _p  =
axion_drop_Either$String _p  =
axion_drop_Either$String$Int _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_Maybe$Either$String$Int _p  =
length xs  =
main  =
