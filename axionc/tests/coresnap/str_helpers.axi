


























                                      drop _t31 : String
                                      let _d1000000 = putStrLn _t31  ; Δ{_t31}
                                      let _t28 = 0  ; Δ{}
                                      let _t29 = 1  ; Δ{}
                                      let _t30 = call || _t28 _t29  ; Δ{}
                                      let _t31 = call show$Bool _t30  ; Δ{} · makes String
                                      ret _d1000000  ; Δ{}
                                    _ ->
                                  drop _t26 : String
                                  let _t23 = 1  ; Δ{}
                                  let _t24 = 0  ; Δ{}
                                  let _t25 = call && _t23 _t24  ; Δ{}
                                  let _t26 = call show$Bool _t25  ; Δ{} · makes String
                                  let _t27 = putStrLn _t26  ; Δ{_t26}
                                  ret case _t27 of
                                _ ->
                              drop _t21 : String
                              let _t21 = call baseName "a/b/c"  ; Δ{} · makes String
                              let _t22 = putStrLn _t21  ; Δ{_t21}
                              ret case _t22 of
                            _ ->
                          drop _t19 : String
                          let _t19 = call dirName "a/b/c"  ; Δ{} · makes String
                          let _t20 = putStrLn _t19  ; Δ{_t19}
                          ret case _t20 of
                        _ ->
                      drop _t16 : Maybe$Int
                      drop _t17 : String
                      let _t16 = call readInt "4x"  ; Δ{} · makes Maybe$Int
                      let _t17 = call show$Maybe$Int _t16  ; Δ{_t16} · makes String
                      let _t18 = putStrLn _t17  ; Δ{_t17}
                      ret case _t18 of
                    _ ->
                  drop _t13 : Maybe$Int
                  drop _t14 : String
                  let _t13 = call readInt "42"  ; Δ{} · makes Maybe$Int
                  let _t14 = call show$Maybe$Int _t13  ; Δ{_t13} · makes String
                  let _t15 = putStrLn _t14  ; Δ{_t14}
                  ret case _t15 of
                _ ->
              drop _t11 : String
              let _t10 = call isDigit 53  ; Δ{}
              let _t11 = call show$Bool _t10  ; Δ{} · makes String
              let _t12 = putStrLn _t11  ; Δ{_t11}
              ret case _t12 of
            _ ->
          drop _t8 : String
          let _t7 = call hasSuffix "oo" "foo"  ; Δ{}
          let _t8 = call show$Bool _t7  ; Δ{} · makes String
          let _t9 = putStrLn _t8  ; Δ{_t8}
          ret case _t9 of
        _ ->
        ret 1  ; Δ{}
        ret == c 13  ; Δ{}
      drop _t0 : String
      drop _t1 : String
      drop _t5 : String
      else
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t0 = rtcall axion_strcat "Just" " "  ; Δ{} · makes String
      let _t1 = call showArg$Int a0  ; Δ{_t0} · makes String
      let _t2 = == c 10  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = - j 1  ; Δ{}
      let _t4 = call hasPrefix "fo" "foo"  ; Δ{}
      let _t5 = * acc 10  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t5 = call show$Bool _t4  ; Δ{} · makes String
      let _t6 = putStrLn _t5  ; Δ{_t5}
      let _t6 = rtcall axion_str_at i s  ; Δ{}
      let _t7 = - _t6 48  ; Δ{}
      let _t8 = + _t5 _t7  ; Δ{}
      ret "Nothing"  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret call lastIndex c s _t4 i  ; Δ{}
      ret call lastIndex c s _t5 best  ; Δ{}
      ret call readIntGo s _t4 _t8  ; Δ{} · makes Maybe$Int
      ret call trimEnd s _t4  ; Δ{}
      ret call trimStart s _t4  ; Δ{}
      ret case _t6 of
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret i  ; Δ{}
      ret if _t2 then
      ret j  ; Δ{}
    Just a0 ->
    Nothing ->
    _ ->
    drop _t4 : String
    drop _t7 : String
    else
    else
    else
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + k 1  ; Δ{}
    let _t1 = - j 1  ; Δ{}
    let _t1 = == c 9  ; Δ{}
    let _t2 = rtcall axion_str_at _t1 s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t3 = - _t2 k  ; Δ{}
    let _t3 = == _t2 c  ; Δ{}
    let _t3 = call isDigit _t2  ; Δ{}
    let _t3 = call isSpace _t2  ; Δ{}
    let _t3 = call isSpace _t2  ; Δ{}
    let _t3 = rtcall axion_str_len p  ; Δ{}
    let _t3 = rtcall axion_str_len s  ; Δ{}
    let _t4 = - _t3 1  ; Δ{}
    let _t4 = rtcall axion_str_len q  ; Δ{}
    let _t4 = rtcall axion_substr 0 _t3 s  ; Δ{} · makes String
    let _t5 = - _t3 _t4  ; Δ{}
    let _t5 = rtcall axion_str_cmp _t4 p  ; Δ{_t4}
    let _t6 = rtcall axion_str_len q  ; Δ{}
    let _t7 = rtcall axion_substr _t5 _t6 s  ; Δ{} · makes String
    let _t8 = rtcall axion_str_cmp _t7 q  ; Δ{_t7}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "."  ; Δ{}
    ret "false"  ; Δ{}
    ret "true"  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret == _t5 0  ; Δ{}
    ret == _t8 0  ; Δ{}
    ret == x y  ; Δ{}
    ret best  ; Δ{}
    ret call readIntGo s 0 0  ; Δ{} · makes Maybe$Int
    ret con Just acc  ; Δ{} · makes Maybe$Int
    ret con Nothing  ; Δ{} · makes Maybe$Int
    ret i  ; Δ{}
    ret if _t1 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret j  ; Δ{}
    ret rtcall axion_substr 0 k s  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 s  ; Δ{} · makes String
    ret s  ; Δ{}
    ret y  ; Δ{}
    ret y  ; Δ{}
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  drop _t2 : String
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
  else
  else
  else
  else
  else
  else
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = - 0 1  ; Δ{}
  let _t0 = - 0 1  ; Δ{}
  let _t0 = < k 0  ; Δ{}
  let _t0 = < k 0  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == c 32  ; Δ{}
  let _t0 = > j 0  ; Δ{}
  let _t0 = call >=$Int c 48  ; Δ{}
  let _t0 = call trim "  ab  "  ; Δ{} · makes String
  let _t0 = call trimStart s 0  ; Δ{}
  let _t0 = rtcall axion_str_len p  ; Δ{}
  let _t0 = rtcall axion_str_len q  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = < i _t0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = call <=$Int c 57  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = call show$Int _t1  ; Δ{} · makes String
  let _t2 = call trimEnd s _t1  ; Δ{}
  let _t3 = call trimStart s 0  ; Δ{}
  let _t3 = putStrLn _t2  ; Δ{_t2}
  let _t4 = - _t2 _t3  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call && _t0 _t1  ; Δ{}
  ret call baseAfter s _t1  ; Δ{} · makes String
  ret call dirBefore s _t1  ; Δ{} · makes String
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret case _t3 of
  ret case x of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t2 then
  ret if _t2 then
  ret if x then
  ret if x then
  ret if x then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_substr _t0 _t4 s  ; Δ{} · makes String
  ret showInt x  ; Δ{} · makes String
  ret showInt x  ; Δ{} · makes String
&& x y  =
<=$Int x y  =
>=$Int x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Maybe$Int _p  =
baseAfter s k  =
baseName s  =
dirBefore s k  =
dirName s  =
hasPrefix p s  =
hasSuffix q s  =
isDigit c  =
isSpace c  =
lastIndex c s i best  =
le$Int x y  =
main  =
readInt s  =
readIntGo s i acc  =
show$Bool x  =
show$Int x  =
show$Maybe$Int x  =
showArg$Int x  =
trim s  =
trimEnd s j  =
trimStart s i  =
|| x y  =
