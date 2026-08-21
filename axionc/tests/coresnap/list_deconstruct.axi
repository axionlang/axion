


























                    _ ->
                _ ->
            _ ->
        _ ->
    _ ->
axion_drop_Array _p  =
axion_drop_List$Int _p  =
axion_drop_List _p  =
axion_drop_Maybe$Int _p  =
axion_drop_Maybe$List$Int _p  =
axion_drop_Maybe$tuple$Int$List$Int _p  =
    (c0, c1) ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
        Cons z zs ->
        Cons z zs ->
double x  =
drop n xs  =
          drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
  drop _t0 : String
  drop _t0 : String
      drop _t10 : Maybe$Int
      drop _t11 : String
          drop _t17 : Maybe$List$Int
          drop _t18 : String
      drop _t1 : String
      drop _t1 : String
      drop _t1 : String
      drop _t1 : String
  drop _t1 : String
  drop _t1 : String
              drop _t23 : List$Int
              drop _t24 : Maybe$Int
              drop _t25 : String
                  drop _t28 : List$Int
                  drop _t29 : Maybe$Int
          drop _t2 : String
      drop _t2 : String
                  drop _t30 : String
                      drop _t32
                      drop _t33 : List$Int
                      drop _t34 : List$Int
                      drop _t35 : Maybe$Int
                      drop _t36 : String
          drop _t3 : String
      drop _t3 : String
  drop _t4 : Maybe$tuple$Int$List$Int
      drop _t4 : String
  drop _t5 : String
      drop _t9 : List$Int
      drop xs
      drop xs : List$Int
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
head xs  =
    Just a0 ->
    Just a0 ->
    Just a0 ->
lam$0 [env ]eta$1  =
last xs  =
                      let _d1000000 = putStrLn _t36  ; Δ{_t36}
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
          let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat "[" _t1  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_strcat "[" _t1  ; Δ{_t1} · makes String
      let _d1000000 = rtcall axion_strcat "(" _t4  ; Δ{_t4} · makes String
  let _dd0 = band _p 1  ; Δ{}
  let _dd0 = band _p 1  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd1 = if _dd0 then
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
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
      let _t0 = callclo f y  ; Δ{}
      let _t0 = call show$Int c0  ; Δ{} · makes String
          let _t0 = call show$Int y  ; Δ{} · makes String
  let _t0 = call showListElems$Int xs  ; Δ{} · makes String
  let _t0 = call showListElems$Int xs  ; Δ{} · makes String
          let _t0 = con Cons z zs  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = rtcall axion_strcat "Just" " "  ; Δ{} · makes String
      let _t0 = rtcall axion_strcat "Just" " "  ; Δ{} · makes String
      let _t0 = rtcall axion_strcat "Just" " "  ; Δ{} · makes String
      let _t0 = tuple y ys  ; Δ{y ys} · moves{y ys} · makes heap
      let _t10 = call head _t9  ; Δ{_t9} · makes Maybe$Int
      let _t11 = call show$Maybe$Int _t10  ; Δ{_t10} · makes String
      let _t12 = putStrLn _t11  ; Δ{_t11}
          let _t13 = con Nil  ; Δ{} · makes List$Int
          let _t14 = con Cons 9 _t13  ; Δ{_t13} · moves{_t13} · makes List$Int
          let _t15 = con Cons 8 _t14  ; Δ{_t14} · moves{_t14} · makes List$Int
          let _t16 = con Cons 7 _t15  ; Δ{_t15} · moves{_t15} · makes List$Int
          let _t17 = call tail _t16  ; Δ{_t16} · moves{_t16} · makes Maybe$List$Int
          let _t18 = call show$Maybe$List$Int _t17  ; Δ{_t17} · makes String
          let _t19 = putStrLn _t18  ; Δ{_t18}
      let _t1 = call map f ys  ; Δ{} · makes List
      let _t1 = call show$List$Int c1  ; Δ{_t0} · makes String
      let _t1 = call showArg$Int a0  ; Δ{_t0} · makes String
      let _t1 = call showArg$(Int,List$Int) a0  ; Δ{_t0} · makes String
      let _t1 = call showArg$List$Int a0  ; Δ{_t0} · makes String
  let _t1 = con Cons 3 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
          let _t1 = con Cons z zs  ; Δ{_t0}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
  let _t1 = rtcall axion_strcat _t0 "]"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "]"  ; Δ{_t0} · makes String
              let _t20 = con Nil  ; Δ{} · makes List$Int
              let _t21 = con Cons 6 _t20  ; Δ{_t20} · moves{_t20} · makes List$Int
              let _t22 = con Cons 5 _t21  ; Δ{_t21} · moves{_t21} · makes List$Int
              let _t23 = con Cons 4 _t22  ; Δ{_t22} · moves{_t22} · makes List$Int
              let _t24 = call last _t23  ; Δ{_t23} · makes Maybe$Int
              let _t25 = call show$Maybe$Int _t24  ; Δ{_t24} · makes String
              let _t26 = putStrLn _t25  ; Δ{_t25}
                  let _t27 = call range 1 3  ; Δ{} · makes List$Int
                  let _t28 = call drop 5 _t27  ; Δ{_t27} · moves{_t27} · makes List$Int
                  let _t29 = call head _t28  ; Δ{_t28} · makes Maybe$Int
    let _t2 = + acc lo  ; Δ{}
    let _t2 = callclo c lo n  ; Δ{}
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
          let _t2 = call showListElems$Int _t1  ; Δ{_t0} · makes String
  let _t2 = con Cons 2 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
      let _t2 = rtcall axion_strcat _t1 ")"  ; Δ{_t0 _t1} · makes String
                  let _t30 = call show$Maybe$Int _t29  ; Δ{_t29} · makes String
                  let _t31 = putStrLn _t30  ; Δ{_t30}
                      let _t32 = closure lam$0  ; Δ{} · makes heap
                      let _t33 = call range 1 4  ; Δ{_t32} · makes List$Int
                      let _t34 = call map _t32 _t33  ; Δ{_t32 _t33} · makes List$Int
                      let _t35 = call last _t34  ; Δ{_t34} · makes Maybe$Int
                      let _t36 = call show$Maybe$Int _t35  ; Δ{_t35} · makes String
  let _t3 = con Cons 1 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
          let _t3 = rtcall axion_strcat ", " _t2  ; Δ{_t0 _t2} · makes String
      let _t3 = rtcall axion_strcat ", " _t2  ; Δ{_t0 _t2} · makes String
  let _t4 = call uncons$Int _t3  ; Δ{_t3} · moves{_t3} · makes Maybe$tuple$Int$List$Int
      let _t4 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _t5 = call show$Maybe$(Int,List$Int) _t4  ; Δ{_t4} · makes String
  let _t6 = putStrLn _t5  ; Δ{_t5}
      let _t7 = con Nil  ; Δ{} · makes List$Int
      let _t8 = con Cons 8 _t7  ; Δ{_t7} · moves{_t7} · makes List$Int
      let _t9 = con Cons 7 _t8  ; Δ{_t8} · moves{_t8} · makes List$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
map f xs  =
        Nil ->
        Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nothing ->
    Nothing ->
    Nothing ->
rangeFused lo hi c n  =
rangeFusedSum lo hi acc  =
range lo hi  =
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
    ret acc  ; Δ{}
  ret call double eta$1  ; Δ{}
        ret call drop _t1 ys  ; Δ{} · makes List
          ret call last _t0  ; Δ{} · makes Maybe
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
          ret call show$Int y  ; Δ{} · makes String
  ret case p of
      ret case _t12 of
          ret case _t19 of
              ret case _t26 of
                  ret case _t31 of
  ret case _t6 of
  ret case x of
  ret case x of
  ret case x of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
      ret case ys of
      ret case ys of
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
        ret con Cons y ys  ; Δ{}
      ret con Just _t0  ; Δ{_t0} · moves{_t0}
      ret con Just ys  ; Δ{}
          ret con Just y  ; Δ{}
      ret con Just y  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
    ret con Nil  ; Δ{} · makes List$Int
      ret con Nothing  ; Δ{}
      ret con Nothing  ; Δ{}
      ret con Nothing  ; Δ{}
      ret con Nothing  ; Δ{}
                      ret _d1000000  ; Δ{}
          ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
      ret "Nothing"  ; Δ{}
      ret "Nothing"  ; Δ{}
      ret "Nothing"  ; Δ{}
    ret n  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret showInt x  ; Δ{} · makes String
  ret + x x  ; Δ{}
      ret ""  ; Δ{}
show$Int x  =
show$List$Int xs  =
show$Maybe$(Int,List$Int) x  =
show$Maybe$Int x  =
show$Maybe$List$Int x  =
showArg$(Int,List$Int) p  =
showArg$Int x  =
showArg$List$Int xs  =
showListElems$Int xs  =
tail xs  =
uncons$Int xs  =
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
