










      drop _t0 : String
      drop _t1 : String
      drop _t2 : String
      let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call baseName y  ; Δ{} · makes String
      let _t1 = call bnGo ys  ; Δ{_t0} · makes String
      let _t2 = rtcall axion_strcat "\n" _t1  ; Δ{_t0 _t1} · makes String
      let _t4 = + i 1  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      ret ""  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret call lastIndex c s _t4 i  ; Δ{}
      ret call lastIndex c s _t5 best  ; Δ{}
    Cons y ys ->
    Nil ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + k 1  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t3 = - _t2 k  ; Δ{}
    let _t3 = == _t2 c  ; Δ{}
    let _t4 = - _t3 1  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret best  ; Δ{}
    ret if _t3 then
    ret rtcall axion_strcat s ""  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 s  ; Δ{} · makes String
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : List$String
  drop _t1 : String
  else
  else
  else
  else
  else
  let _d1000000 = putStr _t1  ; Δ{_t1}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = - 0 1  ; Δ{}
  let _t0 = < k 0  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = call sample  ; Δ{} · makes List$String
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_strcat "foo" ""  ; Δ{} · makes String
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call bnGo _t0  ; Δ{_t0} · makes String
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = rtcall axion_strcat "bar" ""  ; Δ{_t0} · makes String
  let _t2 = rtcall axion_strcat "baz" ""  ; Δ{_t0 _t1} · makes String
  let _t3 = con Nil  ; Δ{_t0 _t1 _t2} · makes List$String
  let _t4 = con Cons _t2 _t3  ; Δ{_t0 _t1 _t2 _t3} · moves{_t2 _t3} · makes List$String
  let _t5 = con Cons _t1 _t4  ; Δ{_t0 _t1 _t4} · moves{_t1 _t4} · makes List$String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call baseAfter s _t1  ; Δ{} · makes String
  ret call le$Int y x  ; Δ{}
  ret case xs of
  ret con Cons _t0 _t5  ; Δ{_t0 _t5} · moves{_t0 _t5} · makes List$String
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
>=$Int x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
baseAfter s k  =
baseName s  =
bnGo xs  =
lastIndex c s i best  =
le$Int x y  =
main  =
sample  =
