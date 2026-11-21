













































                                      drop _t57 : String
                                      drop _t58 : String
                                      let _d1000000 = putStrLn _t58  ; Δ{_t58}
                                      let _t57 = rtcall axion_strcat "q" ""  ; Δ{} · makes String
                                      let _t58 = call letShadowS _t57  ; Δ{_t57} · makes String
                                      ret _d1000000  ; Δ{}
                                    _ ->
                                  drop _t55 : String
                                  let _t54 = call letShadow "abc" 1000  ; Δ{}
                                  let _t55 = showInt _t54  ; Δ{} · makes String
                                  let _t56 = putStrLn _t55  ; Δ{_t55}
                                  ret case _t56 of
                                _ ->
                              drop _t49 : String
                              drop _t50 : String
                              drop _t51 : List$String
                              drop _t52 : String
                              let _t48 = call words "a bb c"  ; Δ{} · makes List$String
                              let _t49 = showInt 3  ; Δ{_t48} · makes String
                              let _t50 = rtcall axion_strcat "v" _t49  ; Δ{_t48 _t49} · makes String
                              let _t51 = call orTag _t48 _t50  ; Δ{_t48 _t50} · moves{_t48} · makes List$String
                              let _t52 = call catL _t51  ; Δ{_t51} · makes String
                              let _t53 = putStrLn _t52  ; Δ{_t52}
                              ret case _t53 of
                            _ ->
                          drop _t43 : String
                          drop _t44 : String
                          drop _t45 : List$String
                          drop _t46 : String
                          let _t42 = call words "a bb c"  ; Δ{} · makes List$String
                          let _t43 = showInt 2  ; Δ{_t42} · makes String
                          let _t44 = rtcall axion_strcat "u" _t43  ; Δ{_t42 _t43} · makes String
                          let _t45 = call wrapped _t42 _t44  ; Δ{_t42 _t44} · moves{_t42} · makes List$String
                          let _t46 = call catL _t45  ; Δ{_t45} · makes String
                          let _t47 = putStrLn _t46  ; Δ{_t46}
                          ret case _t47 of
                        _ ->
                      drop _t37 : String
                      drop _t38 : String
                      drop _t39 : List$String
                      drop _t40 : String
                      let _t36 = call words "a bb c"  ; Δ{} · makes List$String
                      let _t37 = showInt 1  ; Δ{_t36} · makes String
                      let _t38 = rtcall axion_strcat "t" _t37  ; Δ{_t36 _t37} · makes String
                      let _t39 = call tagged _t36 _t38  ; Δ{_t36 _t38} · moves{_t36} · makes List$String
                      let _t40 = call catL _t39  ; Δ{_t39} · makes String
                      let _t41 = putStrLn _t40  ; Δ{_t40}
                      ret case _t41 of
                    _ ->
                  drop _t32 : Maybe$Int
                  drop _t34 : String
                  let _t32 = con Just 1  ; Δ{} · makes Maybe$Int
                  let _t33 = call viaSibling _t32 100  ; Δ{_t32}
                  let _t34 = showInt _t33  ; Δ{} · makes String
                  let _t35 = putStrLn _t34  ; Δ{_t34}
                  ret case _t35 of
                _ ->
              drop _t28 : List$Int
              drop _t30 : String
              let _t24 = con Nil  ; Δ{} · makes List$Int
              let _t25 = con Cons 3 _t24  ; Δ{_t24} · moves{_t24} · makes List$Int
              let _t26 = con Cons 2 _t25  ; Δ{_t25} · moves{_t25} · makes List$Int
              let _t27 = con Cons 1 _t26  ; Δ{_t26} · moves{_t26} · makes List$Int
              let _t28 = call shadowed _t27 100  ; Δ{_t27} · moves{_t27} · makes List$Int
              let _t29 = call sum _t28  ; Δ{_t28}
              let _t30 = showInt _t29  ; Δ{} · makes String
              let _t31 = putStrLn _t30  ; Δ{_t30}
              ret case _t31 of
            _ ->
          drop _t20 : List$Int
          drop _t22 : String
          let _t16 = con Nil  ; Δ{} · makes List$Int
          let _t17 = con Cons 3 _t16  ; Δ{_t16} · moves{_t16} · makes List$Int
          let _t18 = con Cons 2 _t17  ; Δ{_t17} · moves{_t17} · makes List$Int
          let _t19 = con Cons 1 _t18  ; Δ{_t18} · moves{_t18} · makes List$Int
          let _t20 = call squares _t19  ; Δ{_t19} · moves{_t19} · makes List$Int
          let _t21 = call sum _t20  ; Δ{_t20}
          let _t22 = showInt _t21  ; Δ{} · makes String
          let _t23 = putStrLn _t22  ; Δ{_t22}
          ret case _t23 of
        _ ->
        ret 1  ; Δ{}
        ret == c 13  ; Δ{}
      drop _t0 : String
      drop _t1 : String
      drop _t12 : List$Int
      drop _t14 : String
      drop xs
      drop xs
      drop xs : List$Int
      drop xs : List$String
      else
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
      let _t0 = call sum ys  ; Δ{}
      let _t0 = callclo f y  ; Δ{y ys} · moves{y}
      let _t0 = callclo f y  ; Δ{y ys} · moves{y}
      let _t1 = call map$Int f ys  ; Δ{ys} · moves{ys} · makes List
      let _t1 = call map$String f ys  ; Δ{ys} · moves{ys} · makes List
      let _t1 = rtcall axion_strcat "," _t0  ; Δ{_t0} · makes String
      let _t10 = con Cons 2 _t9  ; Δ{_t9} · moves{_t9} · makes List$Int
      let _t11 = con Cons 1 _t10  ; Δ{_t10} · moves{_t10} · makes List$Int
      let _t12 = call incAll _t11 10  ; Δ{_t11} · moves{_t11} · makes List$Int
      let _t13 = call sum _t12  ; Δ{_t12}
      let _t14 = showInt _t13  ; Δ{} · makes String
      let _t15 = putStrLn _t14  ; Δ{_t14}
      let _t2 = == c 10  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t8 = con Nil  ; Δ{} · makes List$Int
      let _t9 = con Cons 3 _t8  ; Δ{_t8} · moves{_t8} · makes List$Int
      ret "."  ; Δ{}
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret call viaSibling$bump k k$90001  ; Δ{}
      ret call wordEnd s _t3 n  ; Δ{}
      ret case _t15 of
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret i  ; Δ{}
      ret if _t2 then
    Cons a rest ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Just k$90001 ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nothing ->
    _ ->
    else
    else
    else
    else
    else
    let $aliascopy2000 = rtcall axion_strcat s ""  ; Δ{} · makes String
    let $aliascopy2001 = rtcall axion_strcat tag ""  ; Δ{} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
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
    ret $aliascopy2000  ; Δ{$aliascopy2000} · moves{$aliascopy2000}
    ret $aliascopy2001  ; Δ{$aliascopy2001} · moves{$aliascopy2001}
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
  drop _t0
  drop _t0
  drop _t0
  drop _t0
  drop _t0
  drop _t0
  drop _t0
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t1 : String
  drop _t1 : String
  drop _t4 : List$Int
  drop _t6 : String
  drop s : String
  drop s : String
  drop s : String
  else
  else
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = call map$Int _t0 xs  ; Δ{_t0} · makes List$Int
  let _d1000000 = call map$Int _t0 xs  ; Δ{_t0} · makes List$Int
  let _d1000000 = call map$Int _t0 xs  ; Δ{_t0} · makes List$Int
  let _d1000000 = call map$Int _t0 xs  ; Δ{_t0} · makes List$Int
  let _d1000000 = call map$String _t0 ss  ; Δ{_t0} · makes List$String
  let _d1000000 = call map$String _t0 ss  ; Δ{_t0} · makes List$String
  let _d1000000 = call map$String _t0 ss  ; Δ{_t0} · makes List$String
  let _d1000000 = call orTag$pickW tag s  ; Δ{} · makes String
  let _d1000000 = call tagged$tagIt tag s  ; Δ{} · makes String
  let _d1000000 = call wrapped$wrapped$wrap$let0 tag s  ; Δ{} · makes String
  let _d1000000 = rtcall axion_strcat "<" _t0  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat "<" _t1  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
  let _d1000000 = rtcall axion_strcat tag _t0  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat tag$90003 _t0  ; Δ{_t0} · makes String
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = - j i  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = == c 32  ; Δ{}
  let _t0 = call letShadow$bump tag tag$90002  ; Δ{}
  let _t0 = call letShadow$letShadow$g$let0 tag n "xy"  ; Δ{}
  let _t0 = call letShadowS$letShadowS$wrap$let0 tag "a"  ; Δ{} · makes String
  let _t0 = call letShadowS$pad tag  ; Δ{} · makes String
  let _t0 = call squares$squares$sq$let0 x 2  ; Δ{}
  let _t0 = closure lam$0 k  ; Δ{} · makes Closure
  let _t0 = closure lam$1 k  ; Δ{} · makes Closure
  let _t0 = closure lam$2  ; Δ{} · makes Closure
  let _t0 = closure lam$3 k  ; Δ{} · makes Closure
  let _t0 = closure lam$4 tag  ; Δ{} · makes Closure
  let _t0 = closure lam$5 tag  ; Δ{} · makes Closure
  let _t0 = closure lam$6 tag  ; Δ{} · makes Closure
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len x  ; Δ{}
  let _t0 = rtcall axion_strcat ":" s  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat s ">"  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat tag ">"  ; Δ{} · makes String
  let _t1 = * _t0 10  ; Δ{}
  let _t1 = > _t0 1  ; Δ{}
  let _t1 = call isSpace _t0  ; Δ{}
  let _t1 = call letShadow$letShadow$g$let0 tag n tag  ; Δ{}
  let _t1 = call letShadowS$letShadowS$wrap$let0 tag tag  ; Δ{_t0} · makes String
  let _t1 = call squares$squares$sq$let0 x 1  ; Δ{}
  let _t1 = con Cons 3 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t1 = rtcall axion_strcat tag _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t2 = call wordsFrom s j n  ; Δ{_t1} · makes List$String
  let _t2 = con Cons 2 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t2 = rtcall axion_str_len tag  ; Δ{}
  let _t3 = con Cons 1 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  let _t4 = call bumpAll _t3 10  ; Δ{_t3} · moves{_t3} · makes List$Int
  let _t5 = call sum _t4  ; Δ{_t4}
  let _t6 = showInt _t5  ; Δ{} · makes String
  let _t7 = putStrLn _t6  ; Δ{_t6}
  ret * y x  ; Δ{}
  ret + _t0 _t1  ; Δ{}
  ret + _t0 _t1  ; Δ{}
  ret + _t0 n  ; Δ{}
  ret + _t1 _t2  ; Δ{}
  ret + y k  ; Δ{}
  ret + y k  ; Δ{}
  ret + y k  ; Δ{}
  ret + y k  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret call bumpAll$bump k x  ; Δ{}
  ret call incAll$incAll$inc$let0 k x  ; Δ{}
  ret call shadowed$bump k k$90000  ; Δ{}
  ret call viaSibling$pick k m  ; Δ{}
  ret call wordsFrom s 0 _t0  ; Δ{} · makes List$String
  ret case _t7 of
  ret case mm of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Cons _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes List$String
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$Int _p  =
bumpAll xs k  =
bumpAll$bump k y  =
catL xs  =
consWord s i n j  =
incAll xs k  =
incAll$incAll$inc$let0 k y  =
isSpace c  =
lam$0 [env k]x  =
lam$1 [env k]x  =
lam$2 [env ]x  =
lam$3 [env k]k$90000  =
lam$4 [env tag]s  =
lam$5 [env tag]s  =
lam$6 [env tag]s  =
letShadow tag n  =
letShadow$bump tag x  =
letShadow$letShadow$g$let0 tag n tag$90002  =
letShadowS tag  =
letShadowS$letShadowS$wrap$let0 tag tag$90003  =
letShadowS$pad tag  =
main  =
map$Int f xs  =
map$String f xs  =
orTag ss tag  =
orTag$pickW tag s  =
shadowed xs k  =
shadowed$bump k y  =
squares xs  =
squares$squares$sq$let0 x y  =
sum xs  =
tagged ss tag  =
tagged$tagIt tag s  =
viaSibling m k  =
viaSibling$bump k y  =
viaSibling$pick k mm  =
wordEnd s i n  =
words s  =
wordsFrom s i n  =
wordsStep s i n  =
wrapped ss tag  =
wrapped$wrapped$wrap$let0 tag s  =
