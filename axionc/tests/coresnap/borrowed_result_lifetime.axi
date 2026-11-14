
















      drop _t0 : W
      drop _t0 : W
      drop _t3
      drop _t3 : Maybe$String
      drop s : String
      let _d1000000 = + x _t2  ; Δ{_t0}
      let _d1000000 = rtcall axion_str_len s  ; Δ{s}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call sum ys  ; Δ{}
      let _t2 = call length rest  ; Δ{_t0}
      ret + 1 _t0  ; Δ{}
      ret + y _t0  ; Δ{}
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
      ret _d1000000  ; Δ{}
      ret _d1000000  ; Δ{}
      ret s  ; Δ{}
    BoxS s n ->
    Cons x rest ->
    Cons y ys ->
    Cons y ys ->
    Just s ->
    Nil ->
    Nil ->
    Nil ->
    Nothing ->
    else
    else
    else
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
  ; Δ{_t0}
  ; Δ{_t3}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  drop _t1 : BoxS
  drop _t1 : BoxS
  drop _t2 : BoxS
  drop _t5 : W
  drop w : W
  else
  else
  else
  let $borrowcopy0 = rtcall axion_strcat _t2 ""  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_str_len _t2  ; Δ{_t1}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call direct 888  ; Δ{}
  let _t0 = call length i  ; Δ{w}
  let _t0 = call mk n  ; Δ{} · makes W
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = showInt n  ; Δ{} · makes String
  let _t0 = showInt n  ; Δ{} · makes String
  let _t0 = showInt n  ; Δ{} · makes String
  let _t1 = call caseOn 5  ; Δ{}
  let _t1 = call getInner _t0  ; Δ{_t0}
  let _t1 = call sum i  ; Δ{w}
  let _t1 = con BoxS _t0 1  ; Δ{_t0} · moves{_t0} · makes BoxS
  let _t1 = con BoxS _t0 6  ; Δ{_t0} · moves{_t0} · makes BoxS
  let _t1 = con Cons 2 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t1 = rtcall axion_strcat _t0 "!"  ; Δ{_t0} · makes String
  let _t2 = + _t0 _t1  ; Δ{}
  let _t2 = call unboxS _t1  ; Δ{_t1}
  let _t2 = call unboxS _t1  ; Δ{_t1}
  let _t2 = con BoxS _t1 n  ; Δ{_t1} · moves{_t1} · makes BoxS
  let _t2 = con Cons n _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t3 = call chained 42  ; Δ{}
  let _t3 = call unboxS _t2  ; Δ{_t2}
  let _t3 = con Just $borrowcopy0  ; Δ{$borrowcopy0} · moves{$borrowcopy0} · makes Maybe$String
  let _t3 = con Nil  ; Δ{_t2} · makes List$Int
  let _t4 = + _t2 _t3  ; Δ{}
  let _t4 = con Cons 9 _t3  ; Δ{_t2 _t3} · moves{_t3} · makes List$Int
  let _t4 = rtcall axion_str_len _t3  ; Δ{_t2}
  let _t5 = call mk n  ; Δ{} · makes W
  let _t5 = call projected 3  ; Δ{}
  let _t6 = + _t4 _t5  ; Δ{}
  let _t6 = call getInner _t5  ; Δ{_t5}
  let _t7 = call length _t6  ; Δ{_t5}
  let _t7 = call moved 77  ; Δ{}
  let i = field inner w  ; Δ{w}
  let w = call mk n  ; Δ{} · makes W
  ret + _t0 _t1  ; Δ{}
  ret + _t4 _t7  ; Δ{}
  ret + _t6 _t7  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case _t1 of
  ret case _t3 of
  ret case b of
  ret case xs of
  ret case xs of
  ret field inner w  ; Δ{}
  ret record W { inner = _t2 other = _t4}  ; Δ{_t2 _t4} · moves{_t2 _t4} · makes W
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_BoxS _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_Maybe$String _p  =
axion_drop_W _p  =
caseOn n  =
chained n  =
direct n  =
getInner w  =
length xs  =
main  =
mk n  =
moved n  =
projected n  =
sum xs  =
unboxS b  =
