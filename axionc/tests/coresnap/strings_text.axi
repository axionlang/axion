
























                                  drop _t23 : List$String
                                  drop _t25 : String
                                  let _d1000000 = putStrLn _t25  ; Δ{_t25}
                                  let _t23 = call words "one two three four"  ; Δ{} · makes List$String
                                  let _t24 = call length _t23  ; Δ{_t23}
                                  let _t25 = call show$Int _t24  ; Δ{} · makes String
                                  ret _d1000000  ; Δ{}
                                _ ->
                              drop _t20 : List$String
                              drop _t21 : String
                              let _t20 = call words "round  trip"  ; Δ{} · makes List$String
                              let _t21 = call unwords _t20  ; Δ{_t20} · makes String
                              let _t22 = putStrLn _t21  ; Δ{_t21}
                              ret case _t22 of
                            _ ->
                          drop _t17 : List$String
                          drop _t18 : String
                          let _t17 = call splitOn 44 "x,,y"  ; Δ{} · makes List$String
                          let _t18 = call show$List$String _t17  ; Δ{_t17} · makes String
                          let _t19 = putStrLn _t18  ; Δ{_t18}
                          ret case _t19 of
                        _ ->
                      drop _t14 : List$String
                      drop _t15 : String
                      let _t14 = call lines "a\nb\nc\n"  ; Δ{} · makes List$String
                      let _t15 = call show$List$String _t14  ; Δ{_t14} · makes String
                      let _t16 = putStrLn _t15  ; Δ{_t15}
                      ret case _t16 of
                    _ ->
                  drop _t11 : List$String
                  drop _t12 : String
                  let _t11 = call words "  the  quick brown  "  ; Δ{} · makes List$String
                  let _t12 = call show$List$String _t11  ; Δ{_t11} · makes String
                  let _t13 = putStrLn _t12  ; Δ{_t12}
                  ret case _t13 of
                _ ->
              drop _t9 : String
              let _t10 = putStrLn _t9  ; Δ{_t9}
              let _t9 = rtcall axion_substr 6 5 "hello world"  ; Δ{} · makes String
              ret case _t10 of
            _ ->
          drop _t7 : String
          let _t6 = rtcall axion_str_at 9 "hello"  ; Δ{}
          let _t7 = call show$Int _t6  ; Δ{} · makes String
          let _t8 = putStrLn _t7  ; Δ{_t7}
          ret case _t8 of
        _ ->
        ret 1  ; Δ{}
        ret == c 13  ; Δ{}
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t1 : String
      drop _t1 : String
      drop _t1 : String
      drop _t2 : String
      drop _t4 : String
      else
      let _d1000000 = rtcall axion_strcat " " _t1  ; Δ{_t1} · makes String
      let _d1000000 = rtcall axion_strcat ", " _t2  ; Δ{_t2} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _d1000000 = rtcall axion_strcat s _t0  ; Δ{_t0} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call show$String y  ; Δ{} · makes String
      let _t0 = call show$String z  ; Δ{} · makes String
      let _t0 = call unwordsRest ss  ; Δ{} · makes String
      let _t0 = call unwordsRest ts  ; Δ{} · makes String
      let _t1 = call showListRest$String ys  ; Δ{_t0} · makes String
      let _t1 = call showListRest$String zs  ; Δ{_t0} · makes String
      let _t1 = rtcall axion_strcat t _t0  ; Δ{_t0} · makes String
      let _t2 = == c 10  ; Δ{}
      let _t2 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = rtcall axion_str_at 1 "hello"  ; Δ{}
      let _t4 = call show$Int _t3  ; Δ{} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret call findChar c s _t3 n  ; Δ{}
      ret call wordEnd s _t3 n  ; Δ{}
      ret case _t5 of
      ret i  ; Δ{}
      ret i  ; Δ{}
      ret if _t2 then
    Cons s ss ->
    Cons t ts ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
    Nil ->
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
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = == c 9  ; Δ{}
    let _t1 = call findChar 10 s i n  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = == _t1 c  ; Δ{}
    let _t2 = call isSpace _t1  ; Δ{}
    let _t3 = + j 1  ; Δ{_t1}
    let _t3 = call wordEnd s i n  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret call consLine s i n _t1  ; Δ{} · makes List$String
    ret call consWord s i n _t3  ; Δ{} · makes List$String
    ret call splitFrom c s _t3 n  ; Δ{_t1} · makes List$String
    ret call wordsFrom s _t2 n  ; Δ{} · makes List$String
    ret call wordsStep s i n  ; Δ{} · makes List$String
    ret con Nil  ; Δ{_t1} · makes List$String
    ret con Nil  ; Δ{} · makes List$String
    ret con Nil  ; Δ{} · makes List$String
    ret i  ; Δ{}
    ret if _t1 then
    ret if _t2 then
    ret if _t2 then
    ret n  ; Δ{}
  ; Δ{_t1}
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
  drop _t0 : String
  drop _t0 : String
  drop _t1 : String
  drop _t1 : String
  else
  else
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = rtcall axion_strcat "[" _t1  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_strcat "\"" _t0  ; Δ{_t0} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = - j i  ; Δ{}
  let _t0 = - j i  ; Δ{}
  let _t0 = - j i  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = == c 32  ; Δ{}
  let _t0 = call findChar c s i n  ; Δ{}
  let _t0 = call showListElems$String xs  ; Δ{} · makes String
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_len "hello"  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_strcat s "\""  ; Δ{} · makes String
  let _t1 = call isSpace _t0  ; Δ{}
  let _t1 = call show$Int _t0  ; Δ{} · makes String
  let _t1 = rtcall axion_strcat _t0 "]"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t2 = + j 1  ; Δ{_t1}
  let _t2 = < j n  ; Δ{_t1}
  let _t2 = call wordsFrom s j n  ; Δ{_t1} · makes List$String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  let _t3 = call linesFrom s _t2 n  ; Δ{_t1} · makes List$String
  let _t4 = if _t2 then
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret call consSplit c s i n _t0  ; Δ{} · makes List$String
  ret call linesFrom s 0 _t0  ; Δ{} · makes List$String
  ret call splitFrom c s 0 _t0  ; Δ{} · makes List$String
  ret call wordsFrom s 0 _t0  ; Δ{} · makes List$String
  ret case _t2 of
  ret case ss of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case ys of
  ret con Cons _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes List$String
  ret con Cons _t1 _t3  ; Δ{_t1 _t3} · moves{_t1 _t3} · makes List$String
  ret con Cons _t1 _t4  ; Δ{_t1} · moves{_t1} · makes List$String
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
consLine s i n j  =
consSplit c s i n j  =
consWord s i n j  =
findChar c s i n  =
isSpace c  =
length xs  =
lines s  =
linesFrom s i n  =
main  =
show$Int x  =
show$List$String xs  =
show$String s  =
showListElems$String xs  =
showListRest$String ys  =
splitFrom c s i n  =
splitOn c s  =
unwords xs  =
unwordsRest ss  =
wordEnd s i n  =
words s  =
wordsFrom s i n  =
wordsStep s i n  =
