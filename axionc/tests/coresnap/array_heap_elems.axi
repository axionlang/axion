
























                                              drop _t71 : String
                                              let _d1000000 = putStrLn _t71  ; Δ{_t71}
                                              let _t69 = newArray 4 7  ; Δ{} · makes Array
                                              let _t70 = call consumeInts _t69  ; Δ{_t69} · moves{_t69}
                                              let _t71 = call show$Int _t70  ; Δ{} · makes String
                                              ret _d1000000  ; Δ{}
                                            _ ->
                                          drop _t65 : String
                                          drop _t67 : String
                                          drop big : Array$String
                                          let _t64 = call axion_arrop_new$String 2000 "z"  ; Δ{} · makes Array$String
                                          let _t65 = call joinAll big 1990 2000  ; Δ{big} · makes String
                                          let _t66 = rtcall axion_str_len _t65  ; Δ{_t65}
                                          let _t67 = call show$Int _t66  ; Δ{} · makes String
                                          let _t68 = putStrLn _t67  ; Δ{_t67}
                                          let big = call fill _t64 0 2000  ; Δ{_t64} · moves{_t64} · makes Array$String
                                          ret case _t68 of
                                        _ ->
                                      drop _t59 : List$String
                                      drop _t62 : String
                                      let _t57 = con Nil  ; Δ{} · makes List$String
                                      let _t58 = con Cons "b" _t57  ; Δ{_t57} · moves{_t57} · makes List$String
                                      let _t59 = con Cons "a" _t58  ; Δ{_t58} · moves{_t58} · makes List$String
                                      let _t60 = call axion_arrop_new$List$String 4 _t59  ; Δ{_t59} · makes Array$List$String
                                      let _t61 = call consume _t60  ; Δ{_t60} · moves{_t60}
                                      let _t62 = call show$Int _t61  ; Δ{} · makes String
                                      let _t63 = putStrLn _t62  ; Δ{_t62}
                                      ret case _t63 of
                                    _ ->
                                  drop _t48 : Maybe$Integer
                                  drop _t50 : Integer
                                  drop _t51 : Integer
                                  drop _t53 : Maybe$Integer
                                  drop _t54 : Integer
                                  drop _t55 : String
                                  drop m : Array$Maybe$Integer
                                  let _t48 = con Nothing  ; Δ{} · makes Maybe$Integer
                                  let _t49 = call axion_arrop_new$Maybe$Integer 3 _t48  ; Δ{_t48} · makes Array$Maybe$Integer
                                  let _t50 = rtcall axion_bignum_from_i64 41  ; Δ{_t49} · makes Integer
                                  let _t51 = rtcall axion_bignum_from_i64 1  ; Δ{_t49 _t50} · makes Integer
                                  let _t52 = rtcall axion_bignum_add _t50 _t51  ; Δ{_t49 _t50 _t51} · makes Integer
                                  let _t53 = con Just _t52  ; Δ{_t49 _t52} · moves{_t52} · makes Maybe$Integer
                                  let _t54 = call firstOr m  ; Δ{m} · makes Integer
                                  let _t55 = rtcall axion_bignum_to_string _t54  ; Δ{_t54} · makes String
                                  let _t56 = putStrLn _t55  ; Δ{_t55}
                                  let m = call axion_arrop_set$Maybe$Integer _t49 0 _t53  ; Δ{_t49 _t53} · moves{_t49} · makes Array$Maybe$Integer
                                  ret case _t56 of
                                _ ->
                              drop _t46 : String
                              drop s : Array$String
                              let _t46 = call joinAll s 2 4  ; Δ{s} · makes String
                              let _t47 = putStrLn _t46  ; Δ{_t46}
                              ret case _t47 of
                            _ ->
                          drop _t44 : String
                          let _t43 = call axion_arrop_new$String 5 ""  ; Δ{} · makes Array$String
                          let _t44 = call joinAll s 0 5  ; Δ{s} · makes String
                          let _t45 = putStrLn _t44  ; Δ{_t44 s}
                          let s = call fill _t43 0 5  ; Δ{_t43} · moves{_t43} · makes Array$String
                          ret case _t45 of
                        _ ->
                      drop _t38 : tuple2$String$Int
                      drop _t39 : tuple2$String$Int
                      drop _t41 : String
                      drop u : Array$tuple2$String$Int
                      let _t38 = tuple "a" 5  ; Δ{} · makes heap
                      let _t39 = tuple "b" 6  ; Δ{t} · makes heap
                      let _t40 = rtcall axion_array_len u  ; Δ{u}
                      let _t41 = call show$Int _t40  ; Δ{} · makes String
                      let _t42 = putStrLn _t41  ; Δ{_t41}
                      let t = call axion_arrop_new$tuple2$String$Int 2 _t38  ; Δ{_t38} · makes Array$tuple2$String$Int
                      let u = call axion_arrop_set$tuple2$String$Int t 1 _t39  ; Δ{_t39 t} · moves{t} · makes Array$tuple2$String$Int
                      ret case _t42 of
                    _ ->
                  drop _t30 : P
                  drop _t31 : P
                  drop _t32 : P
                  drop _t34 : P
                  drop _t36 : String
                  drop h : Array$P
                  let _t30 = con P "p" 1  ; Δ{} · makes P
                  let _t31 = con P "q" 2  ; Δ{g} · makes P
                  let _t32 = call axion_arrop_get$P h 0  ; Δ{h} · makes P
                  let _t33 = call nameOf _t32  ; Δ{_t32 h}
                  let _t34 = call axion_arrop_get$P h 1  ; Δ{_t32 h} · makes P
                  let _t35 = call nameOf _t34  ; Δ{_t32 _t34}
                  let _t36 = rtcall axion_strcat _t33 _t35  ; Δ{_t32 _t34} · makes String
                  let _t37 = putStrLn _t36  ; Δ{_t36}
                  let g = call axion_arrop_new$P 2 _t30  ; Δ{_t30} · makes Array$P
                  let h = call axion_arrop_set$P g 0 _t31  ; Δ{_t31 g} · moves{g} · makes Array$P
                  ret case _t37 of
                _ ->
              drop _t19 : List$Int
              drop _t22 : List$Int
              drop _t23 : List$Int
              drop _t25 : List$Int
              drop _t28 : String
              drop f : Array$List$Int
              let _t16 = con Nil  ; Δ{} · makes List$Int
              let _t17 = con Cons 3 _t16  ; Δ{_t16} · moves{_t16} · makes List$Int
              let _t18 = con Cons 2 _t17  ; Δ{_t17} · moves{_t17} · makes List$Int
              let _t19 = con Cons 1 _t18  ; Δ{_t18} · moves{_t18} · makes List$Int
              let _t20 = con Nil  ; Δ{e} · makes List$Int
              let _t21 = con Cons 20 _t20  ; Δ{_t20 e} · moves{_t20} · makes List$Int
              let _t22 = con Cons 10 _t21  ; Δ{_t21 e} · moves{_t21} · makes List$Int
              let _t23 = call axion_arrop_get$List$Int f 0  ; Δ{f} · makes List$Int
              let _t24 = call sumL _t23  ; Δ{_t23 f}
              let _t25 = call axion_arrop_get$List$Int f 1  ; Δ{f} · makes List$Int
              let _t26 = call sumL _t25  ; Δ{_t25}
              let _t27 = + _t24 _t26  ; Δ{}
              let _t28 = call show$Int _t27  ; Δ{} · makes String
              let _t29 = putStrLn _t28  ; Δ{_t28}
              let e = call axion_arrop_new$List$Int 2 _t19  ; Δ{_t19} · makes Array$List$Int
              let f = call axion_arrop_set$List$Int e 1 _t22  ; Δ{_t22 e} · moves{e} · makes Array$List$Int
              ret case _t29 of
            _ ->
          drop _t10 : Integer
          drop _t11 : Integer
          drop _t12 : Integer
          drop _t13 : Integer
          drop _t14 : String
          drop _t7 : Integer
          drop _t8 : Integer
          drop _t9 : Integer
          drop d : Array$Integer
          let _t10 = rtcall axion_bignum_mul _t8 _t9  ; Δ{_t8 _t9 c} · makes Integer
          let _t11 = call axion_arrop_get$Integer d 0  ; Δ{d} · makes Integer
          let _t12 = call axion_arrop_get$Integer d 1  ; Δ{_t11 d} · makes Integer
          let _t13 = rtcall axion_bignum_add _t11 _t12  ; Δ{_t11 _t12} · makes Integer
          let _t14 = rtcall axion_bignum_to_string _t13  ; Δ{_t13} · makes String
          let _t15 = putStrLn _t14  ; Δ{_t14}
          let _t7 = rtcall axion_bignum_from_i64 7  ; Δ{} · makes Integer
          let _t8 = rtcall axion_bignum_from_i64 1000  ; Δ{c} · makes Integer
          let _t9 = rtcall axion_bignum_from_i64 1000  ; Δ{_t8 c} · makes Integer
          let c = call axion_arrop_new$Integer 2 _t7  ; Δ{_t7} · makes Array$Integer
          let d = call axion_arrop_set$Integer c 0 _t10  ; Δ{_t10 c} · moves{c} · makes Array$Integer
          ret case _t15 of
        _ ->
      drop _t0
      drop _t0
      drop _t5 : String
      drop b : Array$String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = rtcall axion_bignum_free _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call sumL r  ; Δ{}
      let _t4 = rtcall axion_array_len b  ; Δ{b}
      let _t5 = call show$Int _t4  ; Δ{} · makes String
      let _t6 = putStrLn _t5  ; Δ{_t5}
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
      ret case _t6 of
      ret rtcall axion_bignum_from_i64 0  ; Δ{} · makes Integer
      ret s  ; Δ{}
      ret v  ; Δ{v} · moves{v}
    Cons y r ->
    Just v ->
    Nil ->
    Nothing ->
    P s _ ->
    _ ->
    drop _t1 : String
    drop _t2 : String
    drop _t3 : String
    else
    else
    else
    else
    let _d1000000 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = * i i  ; Δ{}
    let _t1 = call axion_arrop_get$String a i  ; Δ{} · makes String
    let _t2 = + i 1  ; Δ{_t1}
    let _t2 = showInt _t1  ; Δ{} · makes String
    let _t3 = call axion_arrop_set$String a i _t2  ; Δ{_t2} · makes Array$String
    let _t3 = call joinAll a _t2 n  ; Δ{_t1} · makes String
    let _t4 = + i 1  ; Δ{_t3}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret ""  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret a  ; Δ{}
    ret call fill _t3 _t4 n  ; Δ{_t3} · moves{_t3} · makes Array$String
  ; Δ{_t0}
  ; Δ{b}
  ; Δ{s}
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
  drop _t1 : String
  drop _t2 : String
  drop a : Array
  drop a : Array$List$String
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = rtcall axion_array_len a  ; Δ{}
  let _d1000000 = rtcall axion_array_len a  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _i = - _n 1  ; Δ{}
  let _i = - _n 1  ; Δ{}
  let _i = - _n 1  ; Δ{}
  let _i = - _n 1  ; Δ{}
  let _i = - _n 1  ; Δ{}
  let _i = - _n 1  ; Δ{}
  let _i = - _n 1  ; Δ{}
  let _n = rtcall axion_array_len _p  ; Δ{}
  let _n = rtcall axion_array_len _p  ; Δ{}
  let _n = rtcall axion_array_len _p  ; Δ{}
  let _n = rtcall axion_array_len _p  ; Δ{}
  let _n = rtcall axion_array_len _p  ; Δ{}
  let _n = rtcall axion_array_len _p  ; Δ{}
  let _n = rtcall axion_array_len _p  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call axion_arrop_get$Maybe$Integer a 0  ; Δ{} · makes Maybe$Integer
  let _t0 = call axion_arrop_get$String b 0  ; Δ{b} · makes String
  let _t1 = call axion_arrop_get$String b 1  ; Δ{_t0 b} · makes String
  let _t2 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1 b} · makes String
  let _t3 = putStrLn _t2  ; Δ{_t2 b}
  let a = call axion_arrop_new$String 3 "x"  ; Δ{} · makes Array$String
  let b = call axion_arrop_set$String a 1 "hello"  ; Δ{a} · moves{a} · makes Array$String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call axion_arrop_dropfrom$Integer _p _i  ; Δ{}
  ret call axion_arrop_dropfrom$List$Int _p _i  ; Δ{}
  ret call axion_arrop_dropfrom$List$String _p _i  ; Δ{}
  ret call axion_arrop_dropfrom$Maybe$Integer _p _i  ; Δ{}
  ret call axion_arrop_dropfrom$P _p _i  ; Δ{}
  ret call axion_arrop_dropfrom$String _p _i  ; Δ{}
  ret call axion_arrop_dropfrom$tuple2$String$Int _p _i  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret case _t0 of
  ret case _t3 of
  ret case p of
  ret case xs of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
>=$Int x y  =
axion_drop_Array _p  =
axion_drop_Array$Integer _p  =
axion_drop_Array$List$Int _p  =
axion_drop_Array$List$String _p  =
axion_drop_Array$Maybe$Integer _p  =
axion_drop_Array$P _p  =
axion_drop_Array$String _p  =
axion_drop_Array$tuple2$String$Int _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$Integer _p  =
axion_drop_P _p  =
axion_drop_tuple2$String$Int _p  =
consume a  =
consumeInts a  =
fill a i n  =
firstOr a  =
joinAll a i n  =
le$Int x y  =
main  =
nameOf p  =
show$Int x  =
sumL xs  =
