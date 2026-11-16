

















              drop _t30 : List$Int
              drop _t32 : String
              let _d1000000 = putStrLn _t32  ; Δ{_t32}
              let _t26 = con Nil  ; Δ{} · makes List$Int
              let _t27 = con Cons 5 _t26  ; Δ{_t26} · moves{_t26} · makes List$Int
              let _t28 = con Cons 3 _t27  ; Δ{_t27} · moves{_t27} · makes List$Int
              let _t29 = con Cons 1 _t28  ; Δ{_t28} · moves{_t28} · makes List$Int
              let _t30 = call delete$Int 3 _t29  ; Δ{_t29} · moves{_t29} · makes List$Int
              let _t31 = call sum _t30  ; Δ{_t30}
              let _t32 = showInt _t31  ; Δ{} · makes String
              ret _d1000000  ; Δ{}
            _ ->
          drop _t23 : List$String
          drop _t24 : String
          let _t18 = showInt 4  ; Δ{} · makes String
          let _t19 = showInt 55  ; Δ{_t18} · makes String
          let _t20 = con Nil  ; Δ{_t18 _t19} · makes List$String
          let _t21 = con Cons _t19 _t20  ; Δ{_t18 _t19 _t20} · moves{_t19 _t20} · makes List$String
          let _t22 = con Cons _t18 _t21  ; Δ{_t18 _t21} · moves{_t18 _t21} · makes List$String
          let _t23 = call dropShort _t22  ; Δ{_t22} · moves{_t22} · makes List$String
          let _t24 = call show$List$String _t23  ; Δ{_t23} · makes String
          let _t25 = putStrLn _t24  ; Δ{_t24}
          ret case _t25 of
        _ ->
        drop y : String
        drop y : String
        let _t1 = call delete$Int x ys  ; Δ{y ys} · moves{ys} · makes List$Int
        ret call dropShort ys  ; Δ{ys} · moves{ys} · makes List$String
        ret call dropWhile$$short ys  ; Δ{ys} · moves{ys} · makes List$String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y}
        ret con Cons y ys  ; Δ{y ys} · moves{y ys} · makes List$String
        ret con Cons y ys  ; Δ{y ys} · moves{y ys} · makes List$String
        ret ys  ; Δ{y ys} · moves{ys}
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t1 : String
      drop _t1 : String
      drop _t1 : String
      drop _t15 : List$String
      drop _t16 : String
      drop _t2 : String
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs : List$Int
      drop xs : List$String
      drop y : String
      else
      else
      else
      let _d1000000 = rtcall axion_strcat ", " _t2  ; Δ{_t2} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = == x y  ; Δ{y ys}
      let _t0 = call short y  ; Δ{y ys}
      let _t0 = call show$String y  ; Δ{} · makes String
      let _t0 = call show$String z  ; Δ{} · makes String
      let _t0 = call sum ys  ; Δ{}
      let _t0 = rtcall axion_str_len y  ; Δ{y ys}
      let _t0 = rtcall axion_strcat "Just" " "  ; Δ{} · makes String
      let _t1 = < _t0 2  ; Δ{y ys}
      let _t1 = call showArg$List$String a0  ; Δ{_t0} · makes String
      let _t1 = call showListRest$String ys  ; Δ{_t0} · makes String
      let _t1 = call showListRest$String zs  ; Δ{_t0} · makes String
      let _t10 = showInt 3  ; Δ{_t8 _t9} · makes String
      let _t11 = con Nil  ; Δ{_t10 _t8 _t9} · makes List$String
      let _t12 = con Cons _t10 _t11  ; Δ{_t10 _t11 _t8 _t9} · moves{_t10 _t11} · makes List$String
      let _t13 = con Cons _t9 _t12  ; Δ{_t12 _t8 _t9} · moves{_t12 _t9} · makes List$String
      let _t14 = con Cons _t8 _t13  ; Δ{_t13 _t8} · moves{_t13 _t8} · makes List$String
      let _t15 = call dropWhile$$short _t14  ; Δ{_t14} · moves{_t14} · makes List$String
      let _t16 = call show$List$String _t15  ; Δ{_t15} · makes String
      let _t17 = putStrLn _t16  ; Δ{_t16}
      let _t2 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _t8 = showInt 1  ; Δ{} · makes String
      let _t9 = showInt 22  ; Δ{_t8} · makes String
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret "Nothing"  ; Δ{}
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
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret case _t17 of
      ret con Just ys  ; Δ{ys} · moves{ys}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret con Nothing  ; Δ{}
      ret if _t0 then
      ret if _t0 then
      ret if _t1 then
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
    Just a0 ->
    Nil ->
    Nil ->
    Nil ->
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
  ; Δ{y ys}
  ; Δ{y ys}
  ; Δ{y ys}
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
  drop _t0 : String
  drop _t1 : String
  drop _t1 : String
  drop _t5 : Maybe$List$String
  drop _t6 : String
  else
  else
  else
  else
  let _d1000000 = rtcall axion_strcat "[" _t1  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_strcat "[" _t1  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_strcat "\"" _t0  ; Δ{_t0} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = call showListElems$String xs  ; Δ{} · makes String
  let _t0 = call showListElems$String xs  ; Δ{} · makes String
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_strcat s "\""  ; Δ{} · makes String
  let _t0 = showInt 1  ; Δ{} · makes String
  let _t1 = rtcall axion_strcat _t0 "]"  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "]"  ; Δ{_t0} · makes String
  let _t1 = showInt 33  ; Δ{_t0} · makes String
  let _t2 = con Nil  ; Δ{_t0 _t1} · makes List$String
  let _t3 = con Cons _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t1 _t2} · makes List$String
  let _t4 = con Cons _t0 _t3  ; Δ{_t0 _t3} · moves{_t0 _t3} · makes List$String
  let _t5 = call tail$String _t4  ; Δ{_t4} · moves{_t4} · makes Maybe$List$String
  let _t6 = call show$Maybe$List$String _t5  ; Δ{_t5} · makes String
  let _t7 = putStrLn _t6  ; Δ{_t6}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret < _t0 2  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret case _t7 of
  ret case x of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case ys of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$List$String _p  =
delete$Int x xs  =
dropShort xs  =
dropWhile$$short xs  =
main  =
short s  =
show$List$String xs  =
show$Maybe$List$String x  =
show$String s  =
showArg$List$String xs  =
showListElems$String xs  =
showListRest$String ys  =
sum xs  =
tail$String xs  =
