











              drop _t24 : List$String
              drop _t26 : String
              let _d1000000 = putStrLn _t26  ; Δ{_t26}
              let _t20 = con Nil  ; Δ{} · makes List$String
              let _t21 = con Cons "c" _t20  ; Δ{_t20} · moves{_t20} · makes List$String
              let _t22 = con Cons "b" _t21  ; Δ{_t21} · moves{_t21} · makes List$String
              let _t23 = con Cons "a" _t22  ; Δ{_t22} · moves{_t22} · makes List$String
              let _t24 = call drop$String 2 _t23  ; Δ{_t23} · moves{_t23} · makes List$String
              let _t25 = call length _t24  ; Δ{_t24}
              let _t26 = showInt _t25  ; Δ{} · makes String
              ret _d1000000  ; Δ{}
            _ ->
          drop _t16 : List$String
          drop _t18 : String
          drop y : String
          drop ys
          drop ys : List$String
          let _t0 = con Cons z zs  ; Δ{y z zs} · moves{z zs}
          let _t12 = con Nil  ; Δ{} · makes List$String
          let _t13 = con Cons "c" _t12  ; Δ{_t12} · moves{_t12} · makes List$String
          let _t14 = con Cons "b" _t13  ; Δ{_t13} · moves{_t13} · makes List$String
          let _t15 = con Cons "a" _t14  ; Δ{_t14} · moves{_t14} · makes List$String
          let _t16 = call take$String 2 _t15  ; Δ{_t15} · moves{_t15} · makes List$String
          let _t17 = call length _t16  ; Δ{_t16}
          let _t18 = showInt _t17  ; Δ{} · makes String
          let _t19 = putStrLn _t18  ; Δ{_t18}
          ret call last$String _t0  ; Δ{} · makes Maybe$String
          ret case _t19 of
          ret con Just y  ; Δ{y} · moves{y}
        Cons z zs ->
        Nil ->
        _ ->
        drop y : String
        drop y : String
        drop ys : List$String
        let _t1 = - n 1  ; Δ{y ys}
        let _t1 = - n 1  ; Δ{y ys}
        let _t2 = call take$String _t1 ys  ; Δ{y ys} · moves{ys} · makes List$String
        ret call drop$String _t1 ys  ; Δ{ys} · moves{ys} · makes List$String
        ret con Cons y _t2  ; Δ{_t2 y} · moves{_t2 y}
        ret con Cons y ys  ; Δ{y ys} · moves{y ys}
        ret con Nil  ; Δ{}
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t10 : String
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs : List$String
      drop xs : List$String
      drop xs : List$String
      drop xs : List$String
      drop ys : List$String
      else
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = < n 1  ; Δ{y ys}
      let _t0 = < n 1  ; Δ{y ys}
      let _t0 = call length ys  ; Δ{}
      let _t10 = call lastOf _t9  ; Δ{_t9} · moves{_t9} · makes String
      let _t11 = putStrLn _t10  ; Δ{_t10}
      let _t6 = con Nil  ; Δ{} · makes List$String
      let _t7 = con Cons "c" _t6  ; Δ{_t6} · moves{_t6} · makes List$String
      let _t8 = con Cons "b" _t7  ; Δ{_t7} · moves{_t7} · makes List$String
      let _t9 = con Cons "a" _t8  ; Δ{_t8} · moves{_t8} · makes List$String
      ret "none"  ; Δ{}
      ret "none"  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t11 of
      ret case ys of
      ret con Just y  ; Δ{y} · moves{y}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nothing  ; Δ{}
      ret con Nothing  ; Δ{}
      ret if _t0 then
      ret if _t0 then
      ret x  ; Δ{x} · moves{x}
      ret x  ; Δ{x} · moves{x}
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Just x ->
    Just x ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nothing ->
    Nothing ->
    _ ->
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
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{_t0}
  ; Δ{_t0}
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
  drop _t4 : String
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = call head$String xs  ; Δ{} · makes Maybe$String
  let _t0 = call last$String xs  ; Δ{} · makes Maybe$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t1 = con Cons "c" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t2 = con Cons "b" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t3 = con Cons "a" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t4 = call firstOf _t3  ; Δ{_t3} · moves{_t3} · makes String
  let _t5 = putStrLn _t4  ; Δ{_t4}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case _t0 of
  ret case _t0 of
  ret case _t5 of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$String _p  =
drop$String n xs  =
firstOf xs  =
head$String xs  =
last$String xs  =
lastOf xs  =
length xs  =
main  =
take$String n xs  =
