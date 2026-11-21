





















                      drop _t19 : List$String
                      drop _t20 : String
                      let _d1000000 = putStrLn _t20  ; Δ{_t20}
                      let _t19 = call words "p q"  ; Δ{} · makes List$String
                      let _t20 = call reads _t19  ; Δ{_t19} · makes String
                      ret _d1000000  ; Δ{}
                    _ ->
                  drop _t13 : String
                  drop _t14 : String
                  drop _t15 : String
                  drop _t16 : String
                  drop _t17 : String
                  drop t : String
                  let _t13 = call kindTop t 0  ; Δ{t} · makes String
                  let _t14 = call kindTop t 1  ; Δ{_t13 t} · makes String
                  let _t15 = call kindTop t 9  ; Δ{_t13 _t14 t} · makes String
                  let _t16 = rtcall axion_strcat _t14 _t15  ; Δ{_t13 _t14 _t15} · makes String
                  let _t17 = rtcall axion_strcat _t13 _t16  ; Δ{_t13 _t16} · makes String
                  let _t18 = putStrLn _t17  ; Δ{_t17}
                  let t = rtcall axion_strcat "q" "r"  ; Δ{} · makes String
                  ret case _t18 of
                _ ->
              drop _t10 : String
              drop _t11 : String
              let _t10 = rtcall axion_strcat "t" "g"  ; Δ{} · makes String
              let _t11 = call guarded _t10 5  ; Δ{_t10} · makes String
              let _t12 = putStrLn _t11  ; Δ{_t11}
              ret case _t12 of
            _ ->
          drop _t7 : List$String
          drop _t8 : String
          let _t7 = con Nil  ; Δ{} · makes List$String
          let _t8 = call firstOr _t7  ; Δ{_t7} · makes String
          let _t9 = putStrLn _t8  ; Δ{_t8}
          ret case _t9 of
        _ ->
        ret 1  ; Δ{}
        ret == c 13  ; Δ{}
      drop _t0 : String
      drop _t1 : String
      drop _t4 : List$String
      drop _t5 : String
      drop ys
      drop ys
      else
      let $aliascopy0 = rtcall axion_strcat _p0 ""  ; Δ{} · makes String
      let $aliascopy2000 = rtcall axion_strcat _p0 ""  ; Δ{} · makes String
      let $fieldcopy1000 = rtcall axion_strcat y ""  ; Δ{} · makes String
      let _d1000000 = rtcall axion_strcat a _t1  ; Δ{_t1} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call catL rest  ; Δ{} · makes String
      let _t0 = call copied$cp rest  ; Δ{rest y} · moves{rest} · makes List$String
      let _t0 = call lenL rest  ; Δ{}
      let _t1 = rtcall axion_strcat "," _t0  ; Δ{_t0} · makes String
      let _t2 = == c 10  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t4 = call words "x y"  ; Δ{} · makes List$String
      let _t5 = call firstOr _t4  ; Δ{_t4} · makes String
      let _t6 = putStrLn _t5  ; Δ{_t5}
      ret "."  ; Δ{}
      ret "a"  ; Δ{}
      ret "none"  ; Δ{}
      ret $aliascopy0  ; Δ{$aliascopy0} · moves{$aliascopy0}
      ret $aliascopy2000  ; Δ{$aliascopy2000} · moves{$aliascopy2000}
      ret $fieldcopy1000  ; Δ{$fieldcopy1000} · moves{$fieldcopy1000}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret call catL _p0  ; Δ{} · makes String
      ret call wordEnd s _t3 n  ; Δ{}
      ret case _t6 of
      ret con Cons y _t0  ; Δ{_t0 y} · moves{_t0 y} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret i  ; Δ{}
      ret if _t2 then
      ret rtcall axion_strcat _p0 "!"  ; Δ{} · makes String
      ret rtcall axion_strcat _p0 "!"  ; Δ{} · makes String
    Cons _ rest ->
    Cons a rest ->
    Cons y _ ->
    Cons y rest ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    _ ->
    else
    else
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
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = < _p1 2  ; Δ{}
    let _t1 = < _p1 2  ; Δ{}
    let _t1 = < _p1 5  ; Δ{}
    let _t1 = == c 9  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = call isSpace _t1  ; Δ{}
    let _t3 = call wordEnd s i n  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "z"  ; Δ{}
    ret "zero"  ; Δ{}
    ret "zero"  ; Δ{}
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
    ret if _t1 then
    ret if _t1 then
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
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t3 : String
  drop _t3 : String
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = - j i  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = == _p1 0  ; Δ{}
  let _t0 = == _p1 0  ; Δ{}
  let _t0 = == _p1 0  ; Δ{}
  let _t0 = == c 32  ; Δ{}
  let _t0 = call copied$cp xs  ; Δ{} · makes List$String
  let _t0 = call firstOr$pickW xs  ; Δ{} · makes String
  let _t0 = call guarded$guarded$kind$let0 tag 0  ; Δ{} · makes String
  let _t0 = call reads$kind xs 0  ; Δ{} · makes String
  let _t0 = call words "a bb ccc"  ; Δ{} · makes List$String
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = call catL xs  ; Δ{_t0} · makes String
  let _t1 = call copied _t0  ; Δ{_t0} · moves{_t0}
  let _t1 = call guarded$guarded$kind$let0 tag 1  ; Δ{_t0} · makes String
  let _t1 = call isSpace _t0  ; Δ{}
  let _t1 = call lenL _t0  ; Δ{_t0}
  let _t1 = call reads$kind xs 3  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t2 = call guarded$guarded$kind$let0 tag k  ; Δ{_t0 _t1} · makes String
  let _t2 = call reads$kind xs 7  ; Δ{_t0 _t1} · makes String
  let _t2 = call wordsFrom s j n  ; Δ{_t1} · makes List$String
  let _t2 = rtcall axion_strcat "/" _t1  ; Δ{_t0 _t1} · makes String
  let _t2 = showInt _t1  ; Δ{} · makes String
  let _t3 = putStrLn _t2  ; Δ{_t2}
  let _t3 = rtcall axion_strcat _t1 _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t3 = rtcall axion_strcat _t1 _t2  ; Δ{_t0 _t1 _t2} · makes String
  ret + _t1 1  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret call wordsFrom s 0 _t0  ; Δ{} · makes List$String
  ret case _t3 of
  ret case xs of
  ret case xs of
  ret case ys of
  ret case ys of
  ret con Cons _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes List$String
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_List$String _p  =
catL xs  =
consWord s i n j  =
copied xs  =
copied$cp ys  =
firstOr xs  =
firstOr$pickW ys  =
guarded tag k  =
guarded$guarded$kind$let0 _p0 _p1  =
isSpace c  =
kindTop _p0 _p1  =
lenL xs  =
main  =
reads xs  =
reads$kind _p0 _p1  =
wordEnd s i n  =
words s  =
wordsFrom s i n  =
wordsStep s i n  =
