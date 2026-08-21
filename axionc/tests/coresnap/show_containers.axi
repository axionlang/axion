























                    _ ->
                _ ->
            _ ->
        _ ->
    _ ->
axion_drop_Array _p  =
axion_drop_List$Int _p  =
axion_drop_List$List$Int _p  =
axion_drop_List$Maybe$Int _p  =
axion_drop_List _p  =
axion_drop_Maybe$Int _p  =
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
        Cons z zs ->
        Cons z zs ->
        Cons z zs ->
double x  =
  drop _t0
          drop _t0 : String
          drop _t0 : String
          drop _t0 : String
      drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
          drop _t12 : List$Maybe$Int
          drop _t13 : String
              drop _t16 : String
                  drop _t19 : String
  drop _t1 : List$Int
      drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
                      drop _t28 : List$List$Int
                      drop _t29 : String
  drop _t2 : List$Int
          drop _t2 : String
          drop _t2 : String
          drop _t2 : String
          drop _t3 : String
          drop _t3 : String
          drop _t3 : String
  drop _t3 : String
      drop _t5 : Maybe$Int
      drop _t6 : String
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
    EQ ->
    GT ->
    Just a0 ->
lam$0 [env ]eta$1  =
                      let _d1000000 = putStrLn _t29  ; Δ{_t29}
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
          let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
          let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
          let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat "[" _t1  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_strcat "[" _t1  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_strcat "[" _t1  ; Δ{_t1} · makes String
  let _dd0 = band _p 1  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Maybe$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd1 = if _dd0 then
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
      let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
      let _dd3 = call axion_drop_Maybe$Int _dd2  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = callclo f y  ; Δ{}
          let _t0 = call show$Int y  ; Δ{} · makes String
          let _t0 = call show$List$Int y  ; Δ{} · makes String
          let _t0 = call show$Maybe$Int y  ; Δ{} · makes String
  let _t0 = call showListElems$Int xs  ; Δ{} · makes String
  let _t0 = call showListElems$List$Int xs  ; Δ{} · makes String
  let _t0 = call showListElems$Maybe$Int xs  ; Δ{} · makes String
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
      let _t0 = rtcall axion_strcat "Just" " "  ; Δ{} · makes String
          let _t10 = con Nil  ; Δ{_t8 _t9} · makes List$Maybe$Int
          let _t11 = con Cons _t9 _t10  ; Δ{_t10 _t8 _t9} · moves{_t10 _t9} · makes List$Maybe$Int
          let _t12 = con Cons _t8 _t11  ; Δ{_t11 _t8} · moves{_t11 _t8} · makes List$Maybe$Int
          let _t13 = call show$List$Maybe$Int _t12  ; Δ{_t12} · makes String
          let _t14 = putStrLn _t13  ; Δ{_t13}
              let _t15 = con LT  ; Δ{}
              let _t16 = call show$Ordering _t15  ; Δ{} · makes String
              let _t17 = putStrLn _t16  ; Δ{_t16}
                  let _t18 = con TPlus  ; Δ{}
                  let _t19 = call show$Trit _t18  ; Δ{} · makes String
      let _t1 = call map f ys  ; Δ{} · makes List
  let _t1 = call range 1 5  ; Δ{_t0} · makes List$Int
      let _t1 = call showArg$Int a0  ; Δ{_t0} · makes String
          let _t1 = con Cons z zs  ; Δ{_t0}
          let _t1 = con Cons z zs  ; Δ{_t0}
          let _t1 = con Cons z zs  ; Δ{_t0}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
  let _t1 = rtcall axion_strcat _t0 "]"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "]"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "]"  ; Δ{_t0} · makes String
                  let _t20 = putStrLn _t19  ; Δ{_t19}
                      let _t21 = con Nil  ; Δ{} · makes List$Int
                      let _t22 = con Cons 1 _t21  ; Δ{_t21} · moves{_t21} · makes List$Int
                      let _t23 = con Nil  ; Δ{_t22} · makes List$Int
                      let _t24 = con Cons 3 _t23  ; Δ{_t22 _t23} · moves{_t23} · makes List$Int
                      let _t25 = con Cons 2 _t24  ; Δ{_t22 _t24} · moves{_t24} · makes List$Int
                      let _t26 = con Nil  ; Δ{_t22 _t25} · makes List$List$Int
                      let _t27 = con Cons _t25 _t26  ; Δ{_t22 _t25 _t26} · moves{_t25 _t26} · makes List$List$Int
                      let _t28 = con Cons _t22 _t27  ; Δ{_t22 _t27} · moves{_t22 _t27} · makes List$List$Int
                      let _t29 = call show$List$List$Int _t28  ; Δ{_t28} · makes String
    let _t2 = + acc lo  ; Δ{}
    let _t2 = callclo c lo n  ; Δ{}
  let _t2 = call map _t0 _t1  ; Δ{_t0 _t1} · makes List$Int
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
          let _t2 = call showListElems$Int _t1  ; Δ{_t0} · makes String
          let _t2 = call showListElems$List$Int _t1  ; Δ{_t0} · makes String
          let _t2 = call showListElems$Maybe$Int _t1  ; Δ{_t0} · makes String
  let _t3 = call show$List$Int _t2  ; Δ{_t2} · makes String
          let _t3 = rtcall axion_strcat ", " _t2  ; Δ{_t0 _t2} · makes String
          let _t3 = rtcall axion_strcat ", " _t2  ; Δ{_t0 _t2} · makes String
          let _t3 = rtcall axion_strcat ", " _t2  ; Δ{_t0 _t2} · makes String
  let _t4 = putStrLn _t3  ; Δ{_t3}
      let _t5 = con Just 3  ; Δ{} · makes Maybe$Int
      let _t6 = call show$Maybe$Int _t5  ; Δ{_t5} · makes String
      let _t7 = putStrLn _t6  ; Δ{_t6}
          let _t8 = con Just 1  ; Δ{} · makes Maybe$Int
          let _t9 = con Nothing  ; Δ{_t8} · makes Maybe$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    LT ->
main  =
map f xs  =
        Nil ->
        Nil ->
        Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
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
  ret 0  ; Δ{}
  ret 0  ; Δ{}
    ret acc  ; Δ{}
  ret call double eta$1  ; Δ{}
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
          ret call show$Int y  ; Δ{} · makes String
          ret call show$List$Int y  ; Δ{} · makes String
          ret call show$Maybe$Int y  ; Δ{} · makes String
          ret case _t14 of
              ret case _t17 of
                  ret case _t20 of
  ret case _t4 of
      ret case _t7 of
  ret case x of
  ret case x of
  ret case x of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
      ret case ys of
      ret case ys of
      ret case ys of
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
      ret con Nil  ; Δ{}
    ret con Nil  ; Δ{} · makes List$Int
                      ret _d1000000  ; Δ{}
          ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
          ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
          ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret "EQ"  ; Δ{}
      ret "GT"  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
      ret "LT"  ; Δ{}
      ret "Nothing"  ; Δ{}
    ret n  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret showInt x  ; Δ{} · makes String
      ret "TMinus"  ; Δ{}
      ret "TPlus"  ; Δ{}
      ret "TZero"  ; Δ{}
  ret + x x  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
show$Int x  =
show$List$Int xs  =
show$List$List$Int xs  =
show$List$Maybe$Int xs  =
show$Maybe$Int x  =
show$Ordering x  =
show$Trit x  =
showArg$Int x  =
showListElems$Int xs  =
showListElems$List$Int xs  =
showListElems$Maybe$Int xs  =
    TMinus ->
    TPlus ->
    TZero ->
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
