

















                  drop _t13 : Integer
                  drop _t26 : List$R
                  drop _t27 : List$Integer
                  drop _t28 : String
                  let _d1000000 = putStrLn _t28  ; Δ{_t28 p}
                  let _t20 = rtcall axion_bignum_from_i64 1  ; Δ{p} · makes Integer
                  let _t21 = con R _t20 1  ; Δ{_t20 p} · moves{_t20} · makes R
                  let _t22 = rtcall axion_bignum_from_i64 22  ; Δ{_t21 p} · makes Integer
                  let _t23 = con R _t22 2  ; Δ{_t21 _t22 p} · moves{_t22} · makes R
                  let _t24 = con Nil  ; Δ{_t21 _t23 p} · makes List$R
                  let _t25 = con Cons _t23 _t24  ; Δ{_t21 _t23 _t24 p} · moves{_t23 _t24} · makes List$R
                  let _t26 = con Cons _t21 _t25  ; Δ{_t21 _t25 p} · moves{_t21 _t25} · makes List$R
                  let _t27 = call map$$getV _t26  ; Δ{_t26 p} · makes List$Integer
                  let _t28 = call show$List$Integer _t27  ; Δ{_t27 p} · makes String
                  ret _d1000000  ; Δ{p}
                _ ->
              drop _t18 : String
              drop q : P
              let _t16 = rtcall axion_bignum_from_i64 78  ; Δ{p} · makes Integer
              let _t17 = field age q  ; Δ{p q}
              let _t18 = showInt _t17  ; Δ{p} · makes String
              let _t19 = putStrLn _t18  ; Δ{_t18 p}
              let q = record P { name = _t16 age = 4}  ; Δ{_t16 p} · moves{_t16} · makes P
              ret case _t19 of
            _ ->
          drop _t14 : String
          drop p : P skip{0}
          let _t12 = rtcall axion_bignum_from_i64 77  ; Δ{} · makes Integer
          let _t13 = field name p  ; Δ{p}
          let _t14 = rtcall axion_bignum_to_string _t13  ; Δ{p} · makes String
          let _t15 = putStrLn _t14  ; Δ{_t14 p}
          let p = record P { name = _t12 age = 3}  ; Δ{_t12} · moves{_t12} · makes P
          ret case _t15 of
        _ ->
      drop _t0 : String
      drop _t0 : String
      drop _t1 : String
      drop _t1 : String
      drop _t10 : String
      drop _t2 : String
      drop _t8 : BoxI
      let $borrowcopy0 = rtcall axion_bignum_copy _t0  ; Δ{_t1} · makes Integer
      let _d1000000 = rtcall axion_strcat ", " _t2  ; Δ{_t2} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Integer _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$R _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_R _dd2  ; Δ{}
      let _dd3 = rtcall axion_bignum_free _dd2  ; Δ{}
      let _t0 = call getV y  ; Δ{}
      let _t0 = call show$Integer y  ; Δ{} · makes String
      let _t0 = call show$Integer z  ; Δ{} · makes String
      let _t1 = call map$$getV ys  ; Δ{} · makes List$Integer
      let _t1 = call showListRest$Integer ys  ; Δ{_t0} · makes String
      let _t1 = call showListRest$Integer zs  ; Δ{_t0} · makes String
      let _t10 = rtcall axion_bignum_to_string _t9  ; Δ{_t8} · makes String
      let _t11 = putStrLn _t10  ; Δ{_t10}
      let _t2 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _t7 = rtcall axion_bignum_from_i64 42  ; Δ{} · makes Integer
      let _t8 = con BoxI _t7  ; Δ{_t7} · moves{_t7} · makes BoxI
      let _t9 = call unbox _t8  ; Δ{_t8}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret a  ; Δ{}
      ret case _t11 of
      ret con Cons $borrowcopy0 _t1  ; Δ{$borrowcopy0 _t1} · moves{$borrowcopy0 _t1} · makes List$Integer
      ret con Nil  ; Δ{} · makes List$Integer
      ret n  ; Δ{}
      ret v  ; Δ{}
    BoxI n ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
    Nil ->
    Nil ->
    Nil ->
    Pair a b ->
    R v k ->
    _ ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{p}
  ; Δ{p}
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
  drop _t3 : Pair
  drop _t4 : Integer
  drop _t5 : String
  drop dropped : R
  else
  else
  else
  let _d1000000 = rtcall axion_strcat "[" _t1  ; Δ{_t1} · makes String
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = rtcall axion_bignum_free _dd0  ; Δ{}
  let _dd1 = rtcall axion_bignum_free _dd0  ; Δ{}
  let _dd1 = rtcall axion_bignum_free _dd0  ; Δ{}
  let _dd1 = rtcall axion_bignum_free _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = rtcall axion_bignum_free _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call getF p  ; Δ{}
  let _t0 = call showListElems$Integer xs  ; Δ{} · makes String
  let _t0 = rtcall axion_bignum_from_i64 5  ; Δ{} · makes Integer
  let _t1 = call getF p  ; Δ{}
  let _t1 = rtcall axion_bignum_from_i64 123  ; Δ{} · makes Integer
  let _t1 = rtcall axion_strcat _t0 "]"  ; Δ{_t0} · makes String
  let _t2 = rtcall axion_bignum_from_i64 4  ; Δ{_t1} · makes Integer
  let _t3 = con Pair _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes Pair
  let _t4 = call useBoth _t3  ; Δ{_t3} · makes Integer
  let _t5 = rtcall axion_bignum_to_string _t4  ; Δ{_t4} · makes String
  let _t6 = putStrLn _t5  ; Δ{_t5}
  let dropped = con R _t0 1  ; Δ{_t0} · moves{_t0} · makes R
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret case _t6 of
  ret case b of
  ret case p of
  ret case r of
  ret case xs of
  ret case xs of
  ret case ys of
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_add _t0 _t1  ; Δ{} · makes Integer
  ret rtcall axion_bignum_to_string x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_BoxI _p  =
axion_drop_List _p  =
axion_drop_List$Integer _p  =
axion_drop_List$R _p  =
axion_drop_P _p  =
axion_drop_Pair _p  =
axion_drop_R _p  =
getF p  =
getV r  =
main  =
map$$getV xs  =
show$Integer x  =
show$List$Integer xs  =
showListElems$Integer xs  =
showListRest$Integer ys  =
unbox b  =
useBoth p  =
