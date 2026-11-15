



















        drop rest : List$String
        drop s : String
        let _t3 = call keepGood rest  ; Δ{rest s} · moves{rest} · makes Either$Int$List$String
        ret 1  ; Δ{}
        ret == c 13  ; Δ{}
        ret call consRight s _t3  ; Δ{_t3 s} · moves{_t3 s} · makes Either$Int$List$String
        ret con Left 403  ; Δ{} · makes Either$Int$List$String
      drop _t6 : Either$Int$List$String
      drop _t8 : String
      drop r
      drop r
      drop s : String
      drop segs
      drop segs
      else
      else
      let _d1000000 = putStrLn _t8  ; Δ{_t8}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = con Cons s xs  ; Δ{xs} · moves{xs} · makes List$String
      let _t0 = con Nil  ; Δ{} · makes List$String
      let _t1 = rtcall axion_str_cmp s ".."  ; Δ{rest s}
      let _t2 = == _t1 0  ; Δ{rest s}
      let _t2 = == c 10  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t5 = call words "a .. c"  ; Δ{} · makes List$String
      let _t6 = call keepGood _t5  ; Δ{_t5} · moves{_t5} · makes Either$Int$List$String
      let _t7 = call count _t6  ; Δ{_t6}
      let _t8 = call show$Int _t7  ; Δ{} · makes String
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret _d1000000  ; Δ{}
      ret call hoflam12 y  ; Δ{}
      ret call hoflam13 x  ; Δ{}
      ret call wordEnd s _t3 n  ; Δ{}
      ret con Left e  ; Δ{e} · moves{e} · makes Either$Int$List$String
      ret con Right _t0  ; Δ{_t0} · moves{_t0} · makes Either$Int$List$String
      ret con Right _t0  ; Δ{_t0} · moves{_t0} · makes Either$Int$List$String
      ret i  ; Δ{}
      ret if _t2 then
      ret if _t2 then
    Cons s rest ->
    Cons y ys ->
    Left e ->
    Left x ->
    Nil ->
    Nil ->
    Right xs ->
    Right y ->
    _ ->
    else
    else
    else
    else
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = == c 9  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = call isSpace _t1  ; Δ{}
    let _t3 = call wordEnd s i n  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
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
  ; Δ{rest s}
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
  drop _t1 : Either$Int$List$String
  drop _t3 : String
  else
  else
  else
  else
  else
  else
  else
  let _dd2 = == _tag 1  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = - j i  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = == c 32  ; Δ{}
  let _t0 = call words "a b c"  ; Δ{} · makes List$String
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = call isSpace _t0  ; Δ{}
  let _t1 = call keepGood _t0  ; Δ{_t0} · moves{_t0} · makes Either$Int$List$String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t2 = call count _t1  ; Δ{_t1}
  let _t2 = call wordsFrom s j n  ; Δ{_t1} · makes List$String
  let _t3 = call show$Int _t2  ; Δ{} · makes String
  let _t4 = putStrLn _t3  ; Δ{_t3}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call either$$hoflam13$$hoflam12 r  ; Δ{}
  ret call length xs  ; Δ{}
  ret call wordsFrom s 0 _t0  ; Δ{} · makes List$String
  ret case _t4 of
  ret case e of
  ret case r of
  ret case segs of
  ret case xs of
  ret con Cons _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes List$String
  ret e  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_Either$Int _p  =
axion_drop_Either$Int$List$String _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
consRight s r  =
consWord s i n j  =
count r  =
either$$hoflam13$$hoflam12 e  =
hoflam12 xs  =
hoflam13 e  =
isSpace c  =
keepGood segs  =
length xs  =
main  =
show$Int x  =
wordEnd s i n  =
words s  =
wordsFrom s i n  =
wordsStep s i n  =
