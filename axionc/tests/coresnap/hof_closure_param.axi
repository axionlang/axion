










































                              drop _t40 : Either$Int$Int
                              drop _t50 : List$Int
                              drop _t51 : List$P
                              drop _t53 : String
                              let _d1000000 = putStrLn _t53  ; Δ{_t53}
                              let _t50 = call range 1 5  ; Δ{} · makes List$Int
                              let _t51 = call mkPs _t50  ; Δ{_t50} · makes List$P
                              let _t52 = call length _t51  ; Δ{_t51}
                              let _t53 = call show$Int _t52  ; Δ{} · makes String
                              ret _d1000000  ; Δ{}
                            _ ->
                          drop _t44 : List$Int
                          drop _t45 : List$P
                          drop _t46 : List$Int
                          drop _t48 : String
                          let _t44 = call range 1 5  ; Δ{} · makes List$Int
                          let _t45 = call map$$mkP _t44  ; Δ{_t44} · makes List$P
                          let _t46 = call map$$getA _t45  ; Δ{_t45} · makes List$Int
                          let _t47 = call foldr$$hoflam23 0 _t46  ; Δ{_t46}
                          let _t48 = call show$Int _t47  ; Δ{} · makes String
                          let _t49 = putStrLn _t48  ; Δ{_t48}
                          ret case _t49 of
                        _ ->
                        ret con Left 40  ; Δ{} · makes Either$Int$Int
                        ret con Right 0  ; Δ{} · makes Either$Int$Int
                      drop _t42 : String
                      else
                      let _t39 = > k 1  ; Δ{}
                      let _t40 = if _t39 then
                      let _t41 = call either$$hoflam20$$hoflam19 _t40  ; Δ{}
                      let _t42 = call show$Int _t41  ; Δ{} · makes String
                      let _t43 = putStrLn _t42  ; Δ{_t42}
                      ret case _t43 of
                    _ ->
                  drop _t37 : String
                  drop ws : List$String
                  let _t36 = call countIf$$big ws  ; Δ{ws}
                  let _t37 = call show$Int _t36  ; Δ{} · makes String
                  let _t38 = putStrLn _t37  ; Δ{_t37}
                  ret case _t38 of
                _ ->
              drop _t34 : String
              let _t28 = con Nil  ; Δ{ws} · makes List$String
              let _t29 = con Cons "xy" _t28  ; Δ{_t28 ws} · moves{_t28} · makes List$String
              let _t30 = con Cons "abcd" _t29  ; Δ{_t29 ws} · moves{_t29} · makes List$String
              let _t31 = con Cons "abc" _t30  ; Δ{_t30 ws} · moves{_t30} · makes List$String
              let _t32 = con Cons "a" _t31  ; Δ{_t31 ws} · moves{_t31} · makes List$String
              let _t33 = call keepBoth$$hoflam15$$hoflam14 _t32  ; Δ{_t32 ws} · moves{_t32}
              let _t34 = call show$Int _t33  ; Δ{ws} · makes String
              let _t35 = putStrLn _t34  ; Δ{_t34 ws}
              ret case _t35 of
            _ ->
          drop _t26 : String
          let _t21 = con Nil  ; Δ{ws} · makes List$String
          let _t22 = con Cons "xyz" _t21  ; Δ{_t21 ws} · moves{_t21} · makes List$String
          let _t23 = con Cons "abcde" _t22  ; Δ{_t22 ws} · moves{_t22} · makes List$String
          let _t24 = con Cons "a" _t23  ; Δ{_t23 ws} · moves{_t23} · makes List$String
          let _t25 = call keepWith$$hoflam10 _t24  ; Δ{_t24 ws} · moves{_t24}
          let _t26 = call show$Int _t25  ; Δ{ws} · makes String
          let _t27 = putStrLn _t26  ; Δ{_t26 ws}
          ret case _t27 of
        _ ->
        drop y : Integer
        drop y : String
        drop y : String
        drop y : String
        drop y : String
        let _t1 = call filter$$gt2 ys  ; Δ{y ys} · moves{ys} · makes List$Integer
        let _t1 = call filter$$hoflam10 ys  ; Δ{y ys} · moves{ys} · makes List$String
        let _t1 = call filter$$hoflam14 ys  ; Δ{y ys} · moves{ys} · makes List$String
        let _t1 = call filter$$hoflam15 ys  ; Δ{y ys} · moves{ys} · makes List$String
        let _t1 = call filter$$hoflamcap0 _cap0 ys  ; Δ{y ys} · moves{ys} · makes List$String
        ret 0  ; Δ{}
        ret 1  ; Δ{}
        ret call filter$$gt2 ys  ; Δ{ys} · moves{ys} · makes List$Integer
        ret call filter$$hoflam10 ys  ; Δ{ys} · moves{ys} · makes List$String
        ret call filter$$hoflam14 ys  ; Δ{ys} · moves{ys} · makes List$String
        ret call filter$$hoflam15 ys  ; Δ{ys} · moves{ys} · makes List$String
        ret call filter$$hoflamcap0 _cap0 ys  ; Δ{ys} · moves{ys} · makes List$String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$Integer
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
      drop _t0 : Integer
      drop _t19 : String
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      else
      else
      else
      else
      else
      else
      let _d1000000 = call addI y _t0  ; Δ{_t0} · makes Integer
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Integer _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$P _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_bignum_free _dd2  ; Δ{}
      let _dd3 = rtcall axion_free _dd2  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call big y  ; Δ{}
      let _t0 = call foldr$$addI z ys  ; Δ{} · makes Integer
      let _t0 = call foldr$$hoflam23 z ys  ; Δ{}
      let _t0 = call getA y  ; Δ{}
      let _t0 = call gt2 y  ; Δ{y ys}
      let _t0 = call hoflam10 y  ; Δ{y ys}
      let _t0 = call hoflam14 y  ; Δ{y ys}
      let _t0 = call hoflam15 y  ; Δ{y ys}
      let _t0 = call hoflamcap0 _cap0 y  ; Δ{y ys}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call mkP y  ; Δ{} · makes P
      let _t0 = call mkP y  ; Δ{} · makes P
      let _t1 = call map$$getA ys  ; Δ{} · makes List$Int
      let _t1 = call map$$mkP ys  ; Δ{_t0} · makes List$P
      let _t1 = call mkPs ys  ; Δ{_t0} · makes List$P
      let _t1 = if _t0 then
      let _t14 = con Nil  ; Δ{ws} · makes List$String
      let _t15 = con Cons "abcd" _t14  ; Δ{_t14 ws} · moves{_t14} · makes List$String
      let _t16 = con Cons "abc" _t15  ; Δ{_t15 ws} · moves{_t15} · makes List$String
      let _t17 = con Cons "a" _t16  ; Δ{_t16 ws} · moves{_t16} · makes List$String
      let _t18 = call keepWith$$hoflamcap0 k _t17  ; Δ{_t17 ws} · moves{_t17}
      let _t19 = call show$Int _t18  ; Δ{ws} · makes String
      let _t2 = call countIf$$big ys  ; Δ{}
      let _t20 = putStrLn _t19  ; Δ{_t19 ws}
      ret + 1 _t0  ; Δ{}
      ret + _t1 _t2  ; Δ{}
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
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret a  ; Δ{}
      ret call hoflam19 y  ; Δ{}
      ret call hoflam20 x  ; Δ{}
      ret call hoflam23 y _t0  ; Δ{}
      ret case _t20 of
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$P
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$P
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Integer
      ret con Nil  ; Δ{} · makes List$P
      ret con Nil  ; Δ{} · makes List$P
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret z  ; Δ{}
      ret z  ; Δ{}
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Left x ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    P a ->
    Right y ->
    _ ->
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
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t2 = + acc lo  ; Δ{}
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
    let _t2 = callclo c lo n  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
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
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret acc  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
    ret con Nil  ; Δ{} · makes List$Int
    ret n  ; Δ{}
  ; Δ{ws}
  ; Δ{ws}
  ; Δ{ws}
  ; Δ{ws}
  ; Δ{y ys}
  ; Δ{y ys}
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
  drop _t0 : Integer
  drop _t0 : List$String
  drop _t0 : List$String
  drop _t1 : List$Integer
  drop _t1 : List$String
  drop _t11 : Integer
  drop _t12 : String
  else
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = call foldr$$addI _t0 _t1  ; Δ{_t0 _t1} · moves{_t0} · makes Integer
  let _d1000000 = call length _t0  ; Δ{_t0}
  let _d1000000 = call length _t0  ; Δ{_t0}
  let _d1000000 = call length _t1  ; Δ{_t1}
  let _d1000000 = rtcall axion_bignum_gt n _t0  ; Δ{_t0}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = call filter$$hoflam10 xs  ; Δ{} · makes List$String
  let _t0 = call filter$$hoflam14 xs  ; Δ{} · makes List$String
  let _t0 = call filter$$hoflamcap0 _cap0 xs  ; Δ{} · makes List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = rtcall axion_bignum_from_i64 0  ; Δ{} · makes Integer
  let _t0 = rtcall axion_bignum_from_i64 2  ; Δ{} · makes Integer
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = call filter$$gt2 xs  ; Δ{_t0} · makes List$Integer
  let _t1 = call filter$$hoflam15 _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = con Cons "xy" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t10 = con Cons _t4 _t9  ; Δ{_t4 _t9 ws} · moves{_t4 _t9} · makes List$Integer
  let _t11 = call sumWith$$gt2 _t10  ; Δ{_t10 ws} · moves{_t10} · makes Integer
  let _t12 = call show$Integer _t11  ; Δ{_t11 ws} · makes String
  let _t13 = putStrLn _t12  ; Δ{_t12 ws}
  let _t2 = con Cons "abcd" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t3 = con Cons "abc" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t4 = rtcall axion_bignum_from_i64 1  ; Δ{ws} · makes Integer
  let _t5 = rtcall axion_bignum_from_i64 5  ; Δ{_t4 ws} · makes Integer
  let _t6 = rtcall axion_bignum_from_i64 7  ; Δ{_t4 _t5 ws} · makes Integer
  let _t7 = con Nil  ; Δ{_t4 _t5 _t6 ws} · makes List$Integer
  let _t8 = con Cons _t6 _t7  ; Δ{_t4 _t5 _t6 _t7 ws} · moves{_t6 _t7} · makes List$Integer
  let _t9 = con Cons _t5 _t8  ; Δ{_t4 _t5 _t8 ws} · moves{_t5 _t8} · makes List$Integer
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let k = 2  ; Δ{ws}
  let ws = con Cons "a" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  ret + a b  ; Δ{}
  ret + r 1  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret < _t0 4  ; Δ{}
  ret < _t0 4  ; Δ{}
  ret > _t0 1  ; Δ{}
  ret > _t0 1  ; Δ{}
  ret > _t0 k  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case _t13 of
  ret case e of
  ret case p of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con P n  ; Δ{} · makes P
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret l  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_add a b  ; Δ{} · makes Integer
  ret rtcall axion_bignum_to_string x  ; Δ{} · makes String
  ret showInt x  ; Δ{} · makes String
addI a b  =
axion_drop_Array _p  =
axion_drop_Either$Int _p  =
axion_drop_Either$Int$Int _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_List$Integer _p  =
axion_drop_List$P _p  =
axion_drop_List$String _p  =
big s  =
countIf$$big xs  =
either$$hoflam20$$hoflam19 e  =
filter$$gt2 xs  =
filter$$hoflam10 xs  =
filter$$hoflam14 xs  =
filter$$hoflam15 xs  =
filter$$hoflamcap0 _cap0 xs  =
foldr$$addI z xs  =
foldr$$hoflam23 z xs  =
getA p  =
gt2 n  =
hoflam10 s  =
hoflam14 s  =
hoflam15 s  =
hoflam19 r  =
hoflam20 l  =
hoflam23 a b  =
hoflamcap0 k s  =
keepBoth$$hoflam15$$hoflam14 xs  =
keepWith$$hoflam10 xs  =
keepWith$$hoflamcap0 _cap0 xs  =
length xs  =
main  =
map$$getA xs  =
map$$mkP xs  =
mkP n  =
mkPs xs  =
range lo hi  =
rangeFused lo hi c n  =
rangeFusedSum lo hi acc  =
show$Int x  =
show$Integer x  =
sumWith$$gt2 xs  =
