














        ret 1  ; Δ{}
        ret == c 13  ; Δ{}
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call sum y  ; Δ{}
      let _t0 = call sum ys  ; Δ{}
      let _t0 = rtcall axion_str_len y  ; Δ{}
      let _t1 = call sumAll ys  ; Δ{}
      let _t1 = call sumStrLens ys  ; Δ{}
      let _t2 = == c 10  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      ret + _t0 _t1  ; Δ{}
      ret + _t0 _t1  ; Δ{}
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
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret call wordEnd s _t3 n  ; Δ{}
      ret i  ; Δ{}
      ret if _t2 then
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Nil ->
    Nil ->
    Nil ->
    else
    else
    else
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = == c 9  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = call isSpace _t1  ; Δ{}
    let _t3 = call wordEnd s i n  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
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
    ret 1  ; Δ{}
    ret call consWord s i n _t3  ; Δ{} · makes List$String
    ret call wordsFrom s _t2 n  ; Δ{} · makes List$String
    ret call wordsStep s i n  ; Δ{} · makes List$String
    ret con Nil  ; Δ{} · makes List$String
    ret i  ; Δ{}
    ret if _t1 then
    ret if _t2 then
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : List$String
  drop _t9 : List$List$Int
  else
  else
  else
  else
  else
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _t0 = - j i  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = == c 32  ; Δ{}
  let _t0 = call words "alpha beta gamma delta"  ; Δ{} · makes List$String
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = call isSpace _t0  ; Δ{}
  let _t1 = call sumStrLens _t0  ; Δ{_t0}
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t10 = call sumAll _t9  ; Δ{_t9}
  let _t2 = call wordsFrom s j n  ; Δ{_t1} · makes List$String
  let _t2 = con Nil  ; Δ{} · makes List$Int
  let _t3 = con Cons 2 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  let _t4 = con Cons 1 _t3  ; Δ{_t3} · moves{_t3} · makes List$Int
  let _t5 = con Nil  ; Δ{_t4} · makes List$Int
  let _t6 = con Cons 3 _t5  ; Δ{_t4 _t5} · moves{_t5} · makes List$Int
  let _t7 = con Nil  ; Δ{_t4 _t6} · makes List$List$Int
  let _t8 = con Cons _t6 _t7  ; Δ{_t4 _t6 _t7} · moves{_t6 _t7} · makes List$List$Int
  let _t9 = con Cons _t4 _t8  ; Δ{_t4 _t8} · moves{_t4 _t8} · makes List$List$Int
  ret + _t1 _t10  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call wordsFrom s 0 _t0  ; Δ{} · makes List$String
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Cons _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes List$String
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_List$List$Int _p  =
axion_drop_List$String _p  =
consWord s i n j  =
isSpace c  =
main  =
sum xs  =
sumAll xs  =
sumStrLens xs  =
wordEnd s i n  =
words s  =
wordsFrom s i n  =
wordsStep s i n  =
