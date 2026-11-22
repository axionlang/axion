




































                    ret "different"  ; Δ{}
                    ret "same"  ; Δ{}
                  drop _t49 : Point
                  drop _t50 : Point
                  else
                  let _t49 = con Point 1 2  ; Δ{} · makes Point
                  let _t50 = con Point 1 2  ; Δ{_t49} · makes Point
                  let _t51 = call samePoint _t49 _t50  ; Δ{_t49 _t50}
                  let _t52 = if _t51 then
                  ret putStrLn _t52  ; Δ{}
                _ ->
              drop _t47 : String
              let _t35 = call skipSpaces "   x" 0  ; Δ{}
              let _t36 = call countA "banana"  ; Δ{}
              let _t37 = + _t35 _t36  ; Δ{}
              let _t38 = con Nil  ; Δ{} · makes List$Int
              let _t39 = con Cons 3 _t38  ; Δ{_t38} · moves{_t38} · makes List$Int
              let _t40 = con Cons 2 _t39  ; Δ{_t39} · moves{_t39} · makes List$Int
              let _t41 = con Cons 1 _t40  ; Δ{_t40} · moves{_t40} · makes List$Int
              let _t42 = call viaPrelude _t41  ; Δ{_t41} · moves{_t41}
              let _t43 = + _t37 _t42  ; Δ{}
              let _t44 = con Nil  ; Δ{} · makes List$Int
              let _t45 = call firstOr 4 _t44  ; Δ{_t44} · moves{_t44}
              let _t46 = + _t43 _t45  ; Δ{}
              let _t47 = showInt _t46  ; Δ{} · makes String
              let _t48 = putStrLn _t47  ; Δ{_t47}
              ret case _t48 of
            _ ->
            let _t1 = call merge xs r  ; Δ{}
            let _t2 = call merge l ys  ; Δ{}
            ret + 1 _t1  ; Δ{}
            ret + 1 _t2  ; Δ{}
            ret 0  ; Δ{}
            ret call eq$Int a1 b1  ; Δ{}
          drop _t30 : Array
          drop _t33 : String
          else
          else
          let _t0 = < x y  ; Δ{}
          let _t0 = call eq$Int a0 b0  ; Δ{}
          let _t27 = call safeDiv 7 0  ; Δ{}
          let _t28 = call safeDiv 7 2  ; Δ{}
          let _t29 = + _t27 _t28  ; Δ{}
          let _t30 = newArray 2 5  ; Δ{} · makes Array
          let _t31 = call clampGet _t30 9  ; Δ{_t30}
          let _t32 = + _t29 _t31  ; Δ{}
          let _t33 = showInt _t32  ; Δ{} · makes String
          let _t34 = putStrLn _t33  ; Δ{_t33}
          ret 0  ; Δ{}
          ret case _t34 of
          ret if _t0 then
          ret if _t0 then
        LCons y ys ->
        LNil ->
        Point b0 b1 ->
        _ ->
        let _t1 = call filter$$hoflam15 ys  ; Δ{y ys} · moves{ys} · makes List$Int
        ret call filter$$hoflam15 ys  ; Δ{y ys} · moves{ys} · makes List$Int
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$Int
      drop _t0
      drop _t0
      drop _t12 : Array
      drop _t20 : Lst
      drop _t22 : Lst
      drop _t25 : String
      drop xs
      drop xs
      drop xs
      drop xs : List$Int
      drop ys : List$Int
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_Lst _dd0  ; Δ{}
      let _t0 = - m 1  ; Δ{}
      let _t0 = call hoflam11 z y  ; Δ{}
      let _t0 = call hoflam13 y  ; Δ{}
      let _t0 = call hoflam15 y  ; Δ{y ys}
      let _t0 = call len2 xs  ; Δ{}
      let _t1 = - n 1  ; Δ{}
      let _t1 = call map$$hoflam13 ys  ; Δ{} · makes List$Int
      let _t12 = newArray 4 3  ; Δ{} · makes Array
      let _t13 = call sumArr _t12 0 0  ; Δ{_t12}
      let _t14 = call ack 2 2  ; Δ{}
      let _t15 = + _t13 _t14  ; Δ{}
      let _t16 = call evenOdd 7  ; Δ{}
      let _t17 = + _t15 _t16  ; Δ{}
      let _t18 = con LNil  ; Δ{} · makes Lst
      let _t19 = con LCons 4 _t18  ; Δ{_t18} · moves{_t18} · makes Lst
      let _t2 = call ack m _t1  ; Δ{}
      let _t20 = con LCons 1 _t19  ; Δ{_t19} · moves{_t19} · makes Lst
      let _t21 = con LNil  ; Δ{_t20} · makes Lst
      let _t22 = con LCons 2 _t21  ; Δ{_t20 _t21} · moves{_t21} · makes Lst
      let _t23 = call merge _t20 _t22  ; Δ{_t20 _t22}
      let _t24 = + _t17 _t23  ; Δ{}
      let _t25 = showInt _t24  ; Δ{} · makes String
      let _t26 = putStrLn _t25  ; Δ{_t25}
      let _t3 = - m 1  ; Δ{}
      let _t3 = rtcall axion_str_at i s  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret + acc 1  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret == _t3 32  ; Δ{}
      ret acc  ; Δ{}
      ret call ack _t0 _t2  ; Δ{}
      ret call ack _t3 1  ; Δ{}
      ret call foldl$$hoflam11 _t0 ys  ; Δ{}
      ret case _t26 of
      ret case r of
      ret case y of
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
      ret con Just y  ; Δ{y} · moves{y}
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nothing  ; Δ{}
      ret d  ; Δ{}
      ret if _t0 then
      ret x  ; Δ{x} · moves{x}
      ret z  ; Δ{}
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Just x ->
    LCons _ xs ->
    LCons x xs ->
    LNil ->
    LNil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nothing ->
    Point a0 a1 ->
    _ ->
    else
    else
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
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + acc i  ; Δ{}
    let _t1 = + i 1  ; Δ{}
    let _t1 = - n 1  ; Δ{}
    let _t1 = - n 1  ; Δ{}
    let _t1 = - n 1  ; Δ{}
    let _t1 = rtcall axion_array_len a  ; Δ{}
    let _t1 = rtcall axion_array_len a  ; Δ{}
    let _t1 = rtcall axion_str_len s  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = < i _t1  ; Δ{}
    let _t2 = call fact _t1  ; Δ{}
    let _t3 = + i 1  ; Δ{}
    let _t3 = rtcall axion_str_at i s  ; Δ{}
    let _t4 = == _t3 97  ; Δ{}
    let _t4 = call <=$Int n 0  ; Δ{}
    let _t4 = rtcall axion_array_get_nobc a i  ; Δ{}
    let _t5 = + acc _t4  ; Δ{}
    let _t5 = + i 1  ; Δ{}
    let _t5 = if _t4 then
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret * n _t2  ; Δ{}
    ret + acc i  ; Δ{}
    ret + n 1  ; Δ{}
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
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret < i _t1  ; Δ{}
    ret < i _t1  ; Δ{}
    ret == x y  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret call countA$go s _t2 _t5  ; Δ{}
    ret call countUp _t1 n  ; Δ{}
    ret call isEven _t1  ; Δ{}
    ret call isOdd _t1  ; Δ{}
    ret call skipSpaces s _t5  ; Δ{}
    ret call sumArr a _t3 _t5  ; Δ{}
    ret call sumTo$go n _t1 _t2  ; Δ{}
    ret div a b  ; Δ{}
    ret i  ; Δ{}
    ret i  ; Δ{}
    ret if _t2 then
    ret if _t4 then
    ret rtcall axion_array_get_nobc a i  ; Δ{}
  ; Δ{_t0}
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
  drop _t0 : List$Int
  drop _t1 : List$Int
  drop _t10 : String
  drop _t3 : Lst
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
  else
  else
  else
  else
  let _d1000000 = call foldl$$hoflam11 0 _t1  ; Δ{_t1}
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = < i n  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == b 0  ; Δ{}
  let _t0 = call <=$Int n 0  ; Δ{}
  let _t0 = call <=$Int n 0  ; Δ{}
  let _t0 = call <=$Int n 0  ; Δ{}
  let _t0 = call >=$Int i 0  ; Δ{}
  let _t0 = call >=$Int i 0  ; Δ{}
  let _t0 = call >=$Int i 0  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call filter$$hoflam15 xs  ; Δ{} · makes List$Int
  let _t0 = call head$Int xs  ; Δ{} · makes Maybe$Int
  let _t0 = call isEven n  ; Δ{}
  let _t0 = call sumTo 10  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = < i _t0  ; Δ{}
  let _t1 = call map$$hoflam13 _t0  ; Δ{_t0} · makes List$Int
  let _t1 = con LNil  ; Δ{} · makes Lst
  let _t10 = showInt _t9  ; Δ{} · makes String
  let _t11 = putStrLn _t10  ; Δ{_t10}
  let _t2 = con LCons 2 _t1  ; Δ{_t1} · moves{_t1} · makes Lst
  let _t2 = if _t0 then
  let _t2 = if _t0 then
  let _t3 = con LCons 1 _t2  ; Δ{_t2} · moves{_t2} · makes Lst
  let _t4 = call len2 _t3  ; Δ{_t3}
  let _t4 = if _t0 then
  let _t5 = + _t0 _t4  ; Δ{}
  let _t5 = call <=$Int m 0  ; Δ{}
  let _t6 = call fact 5  ; Δ{}
  let _t7 = + _t5 _t6  ; Δ{}
  let _t8 = call countUp 0 3  ; Δ{}
  let _t9 = + _t7 _t8  ; Δ{}
  ret * x 2  ; Δ{}
  ret + acc x  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret == x y  ; Δ{}
  ret > x 1  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call countA$go s 0 0  ; Δ{}
  ret call eq$Point p q  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call sumTo$go n 0 1  ; Δ{}
  ret case _t0 of
  ret case _t11 of
  ret case l of
  ret case l of
  ret case x of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t2 then
  ret if _t2 then
  ret if _t4 then
  ret if _t5 then
  ret rtcall axion_array_free _p  ; Δ{}
<=$Int x y  =
>=$Int x y  =
ack m n  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_Lst _p  =
axion_drop_Maybe$Int _p  =
clampGet a i  =
countA s  =
countA$go s i acc  =
countUp i n  =
eq$Int x y  =
eq$Point x y  =
evenOdd n  =
fact n  =
filter$$hoflam15 xs  =
firstOr d xs  =
foldl$$hoflam11 z xs  =
head$Int xs  =
hoflam11 acc x  =
hoflam13 x  =
hoflam15 x  =
isEven n  =
isOdd n  =
le$Int x y  =
len2 l  =
main  =
map$$hoflam13 xs  =
merge l r  =
safeDiv a b  =
samePoint p q  =
skipSpaces s i  =
sumArr a i acc  =
sumTo n  =
sumTo$go n acc i  =
viaPrelude xs  =
