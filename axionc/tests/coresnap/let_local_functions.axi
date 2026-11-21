



























                                              drop _t35 : String
                                              let _d1000000 = putStrLn _t35  ; Δ{_t35}
                                              let _t34 = call main$main$twice$let0 21  ; Δ{}
                                              let _t35 = showInt _t34  ; Δ{} · makes String
                                              ret _d1000000  ; Δ{}
                                            _ ->
                                          drop _t32 : String
                                          let _t31 = call shadowed 4  ; Δ{}
                                          let _t32 = showInt _t31  ; Δ{} · makes String
                                          let _t33 = putStrLn _t32  ; Δ{_t32}
                                          ret case _t33 of
                                        _ ->
                                      drop _t28 : List$Int
                                      drop _t29 : String
                                      let _t28 = call passed 10  ; Δ{} · makes List$Int
                                      let _t29 = call showList _t28  ; Δ{_t28} · makes String
                                      let _t30 = putStrLn _t29  ; Δ{_t29}
                                      ret case _t30 of
                                    _ ->
                                  drop _t26 : String
                                  let _t25 = call viaWhere 3  ; Δ{}
                                  let _t26 = showInt _t25  ; Δ{} · makes String
                                  let _t27 = putStrLn _t26  ; Δ{_t26}
                                  ret case _t27 of
                                _ ->
                              drop _t23 : String
                              let _t22 = call nested 7  ; Δ{}
                              let _t23 = showInt _t22  ; Δ{} · makes String
                              let _t24 = putStrLn _t23  ; Δ{_t23}
                              ret case _t24 of
                            _ ->
                          drop _t18 : Shape
                          drop _t20 : String
                          let _t18 = con Rect 2 5  ; Δ{} · makes Shape
                          let _t19 = call area _t18  ; Δ{_t18}
                          let _t20 = showInt _t19  ; Δ{} · makes String
                          let _t21 = putStrLn _t20  ; Δ{_t20}
                          ret case _t21 of
                        _ ->
                      drop _t14 : Shape
                      drop _t16 : String
                      let _t14 = con Circle 2  ; Δ{} · makes Shape
                      let _t15 = call area _t14  ; Δ{_t14}
                      let _t16 = showInt _t15  ; Δ{} · makes String
                      let _t17 = putStrLn _t16  ; Δ{_t16}
                      ret case _t17 of
                    _ ->
                  drop _t12 : String
                  let _t12 = call classify 10  ; Δ{} · makes String
                  let _t13 = putStrLn _t12  ; Δ{_t12}
                  ret case _t13 of
                _ ->
              drop _t10 : String
              let _t10 = call parity "q" 4  ; Δ{} · makes String
              let _t11 = putStrLn _t10  ; Δ{_t10}
              ret case _t11 of
            _ ->
          drop _t8 : String
          let _t8 = call parity "p" 7  ; Δ{} · makes String
          let _t9 = putStrLn _t8  ; Δ{_t8}
          ret case _t9 of
        _ ->
      drop _t0 : String
      drop _t1 : String
      drop _t2 : String
      drop _t4 : List$Int
      drop _t6 : String
      let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = * 3 r  ; Δ{}
      let _t0 = showInt y  ; Δ{} · makes String
      let _t1 = * _t0 r  ; Δ{}
      let _t1 = call showList rest  ; Δ{_t0} · makes String
      let _t2 = * w h  ; Δ{}
      let _t2 = rtcall axion_strcat " " _t1  ; Δ{_t0 _t1} · makes String
      let _t3 = con Nil  ; Δ{} · makes List$Int
      let _t4 = con Cons 10 _t3  ; Δ{_t3} · moves{_t3} · makes List$Int
      let _t5 = call g _t4  ; Δ{_t4}
      let _t6 = showInt _t5  ; Δ{} · makes String
      let _t7 = putStrLn _t6  ; Δ{_t6}
      ret ""  ; Δ{}
      ret "big"  ; Δ{}
      ret "small"  ; Δ{}
      ret * _t1 k  ; Δ{}
      ret * _t2 k  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret call g$g$go$let0 h 3  ; Δ{}
      ret case _t7 of
    Circle r ->
    Cons h _ ->
    Cons y rest ->
    Nil ->
    Nil ->
    Rect w h ->
    _ ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = - k 1  ; Δ{}
    let _t1 = - k 1  ; Δ{}
    let _t1 = - k 1  ; Δ{}
    let _t1 = < _p1 _p0  ; Δ{}
    let _t2 = call g$g$go$let0 h _t1  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "zero"  ; Δ{}
    ret + _t2 1  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret call parity$parity$ev$let0 tag _t1  ; Δ{} · makes String
    ret call parity$parity$od$let1 tag _t1  ; Δ{} · makes String
    ret h  ; Δ{}
    ret if _t1 then
    ret rtcall axion_strcat tag ":even"  ; Δ{} · makes String
    ret rtcall axion_strcat tag ":odd"  ; Δ{} · makes String
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
  drop _t1 : String
  drop _t1 : String
  drop _t2 : String
  drop _t3 : String
  drop _t4 : String
  drop _t5 : String
  else
  else
  else
  else
  else
  else
  let _d1000000 = rtcall axion_strcat _t0 _t5  ; Δ{_t0 _t5} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = * a 10  ; Δ{}
  let _t0 = + k k  ; Δ{}
  let _t0 = == _p1 0  ; Δ{}
  let _t0 = == k 0  ; Δ{}
  let _t0 = == k 0  ; Δ{}
  let _t0 = == k 0  ; Δ{}
  let _t0 = call area$area$scale$let0 s 1  ; Δ{}
  let _t0 = call classify$classify$kind$let0 base 0  ; Δ{} · makes String
  let _t0 = call f 3  ; Δ{}
  let _t0 = call f$f$sq$let0 n a  ; Δ{}
  let _t0 = call passed$passed$addN$let0 n 1  ; Δ{}
  let _t0 = call shadowed$shadowed$plus$let0 n 1  ; Δ{}
  let _t1 = + _t0 b  ; Δ{}
  let _t1 = call area$area$scale$let0 s 2  ; Δ{}
  let _t1 = call classify$classify$kind$let0 base 3  ; Δ{_t0} · makes String
  let _t1 = call passed$passed$addN$let0 n 2  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = call classify$classify$kind$let0 base 40  ; Δ{_t0 _t1} · makes String
  let _t2 = con Nil  ; Δ{} · makes List$Int
  let _t2 = putStrLn _t1  ; Δ{_t1}
  let _t3 = con Cons _t1 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  let _t3 = rtcall axion_strcat "," _t2  ; Δ{_t0 _t1 _t2} · makes String
  let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t0 _t1 _t3} · makes String
  let _t5 = rtcall axion_strcat "," _t4  ; Δ{_t0 _t4} · makes String
  ret * x x  ; Δ{}
  ret + _t0 _t1  ; Δ{}
  ret + _t0 b  ; Δ{}
  ret + _t0 n  ; Δ{}
  ret + _t0 n  ; Δ{}
  ret + _t1 n  ; Δ{}
  ret + h h  ; Δ{}
  ret + k n  ; Δ{}
  ret + k n  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret call f$f$add$let1 n n 1  ; Δ{}
  ret call nested$nested$inner$let0 a n  ; Δ{}
  ret call nested$nested$outer$let1 n 4  ; Δ{}
  ret call parity$parity$ev$let0 tag n  ; Δ{} · makes String
  ret call viaWhere$helper n 5  ; Δ{}
  ret call viaWhere$viaWhere$twice$let0 n m  ; Δ{}
  ret case _t2 of
  ret case s of
  ret case xs of
  ret case xs of
  ret con Cons _t0 _t3  ; Δ{_t3} · moves{_t3} · makes List$Int
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
area s  =
area$area$scale$let0 s k  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
classify base  =
classify$classify$kind$let0 _p0 _p1  =
f n  =
f$f$add$let1 n a b  =
f$f$sq$let0 n x  =
g xs  =
g$g$go$let0 h k  =
main  =
main$main$twice$let0 h  =
nested n  =
nested$nested$inner$let0 a b  =
nested$nested$outer$let1 n a  =
parity tag n  =
parity$parity$ev$let0 tag k  =
parity$parity$od$let1 tag k  =
passed n  =
passed$passed$addN$let0 n k  =
shadowed n  =
shadowed$shadowed$plus$let0 n k  =
showList xs  =
viaWhere n  =
viaWhere$helper n m  =
viaWhere$viaWhere$twice$let0 n k  =
