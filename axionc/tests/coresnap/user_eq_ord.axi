
















                          drop _t30 : R
                          drop _t31 : R
                          drop _t33 : String
                          let _d1000000 = putStrLn _t33  ; Δ{_t33}
                          let _t30 = con R 1 3  ; Δ{} · makes R
                          let _t31 = con R 1 2  ; Δ{_t30} · makes R
                          let _t32 = call lt$R _t30 _t31  ; Δ{_t30 _t31}
                          let _t33 = call yn _t32  ; Δ{} · makes String
                          ret _d1000000  ; Δ{}
                        _ ->
                      drop _t25 : R
                      drop _t26 : R
                      drop _t28 : String
                      let _t25 = con R 1 2  ; Δ{} · makes R
                      let _t26 = con R 2 4  ; Δ{_t25} · makes R
                      let _t27 = call eq$R _t25 _t26  ; Δ{_t25 _t26}
                      let _t28 = call yn _t27  ; Δ{} · makes String
                      let _t29 = putStrLn _t28  ; Δ{_t28}
                      ret case _t29 of
                    _ ->
                  drop _t23 : String
                  let _t20 = con Green  ; Δ{}
                  let _t21 = con Green  ; Δ{}
                  let _t22 = call <=$Color _t20 _t21  ; Δ{}
                  let _t23 = call yn _t22  ; Δ{} · makes String
                  let _t24 = putStrLn _t23  ; Δ{_t23}
                  ret case _t24 of
                _ ->
              drop _t18 : String
              let _t15 = con Blue  ; Δ{}
              let _t16 = con Red  ; Δ{}
              let _t17 = call gt$Color _t15 _t16  ; Δ{}
              let _t18 = call yn _t17  ; Δ{} · makes String
              let _t19 = putStrLn _t18  ; Δ{_t18}
              ret case _t19 of
            _ ->
          drop _t13 : String
          let _t10 = con Red  ; Δ{}
          let _t11 = con Blue  ; Δ{}
          let _t12 = call lt$Color _t10 _t11  ; Δ{}
          let _t13 = call yn _t12  ; Δ{} · makes String
          let _t14 = putStrLn _t13  ; Δ{_t13}
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
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret case _t14 of
        Blue ->
        Blue ->
        Green ->
        Green ->
        Green ->
        Red ->
        Red ->
        Red ->
        Red ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
      drop _t8 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t5 = con Red  ; Δ{}
      let _t6 = con Green  ; Δ{}
      let _t7 = call eq$Color _t5 _t6  ; Δ{}
      let _t8 = call yn _t7  ; Δ{} · makes String
      let _t9 = putStrLn _t8  ; Δ{_t8}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t9 of
      ret case y of
      ret case y of
      ret case y of
      ret case y of
      ret case y of
      ret case y of
      ret d  ; Δ{}
      ret n  ; Δ{}
    Blue ->
    Blue ->
    Green ->
    Green ->
    R n d ->
    R n d ->
    Red ->
    Red ->
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "F"  ; Δ{}
    ret "T"  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
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
  drop _t3 : String
  else
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = < x y  ; Δ{}
  let _t0 = call le$Color x y  ; Δ{}
  let _t0 = call le$Color y x  ; Δ{}
  let _t0 = call le$R y x  ; Δ{}
  let _t0 = call num a  ; Δ{}
  let _t0 = call num a  ; Δ{}
  let _t0 = con Red  ; Δ{}
  let _t1 = call den b  ; Δ{}
  let _t1 = call den b  ; Δ{}
  let _t1 = con Red  ; Δ{}
  let _t2 = * _t0 _t1  ; Δ{}
  let _t2 = * _t0 _t1  ; Δ{}
  let _t2 = call eq$Color _t0 _t1  ; Δ{}
  let _t3 = call num b  ; Δ{}
  let _t3 = call num b  ; Δ{}
  let _t3 = call yn _t2  ; Δ{} · makes String
  let _t4 = call den a  ; Δ{}
  let _t4 = call den a  ; Δ{}
  let _t4 = putStrLn _t3  ; Δ{_t3}
  let _t5 = * _t3 _t4  ; Δ{}
  let _t5 = * _t3 _t4  ; Δ{}
  ret 0  ; Δ{}
  ret == _t2 _t5  ; Δ{}
  ret call <=$Int _t2 _t5  ; Δ{}
  ret call le$Color x y  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret call not _t0  ; Δ{}
  ret call not _t0  ; Δ{}
  ret call not _t0  ; Δ{}
  ret case _t4 of
  ret case r of
  ret case r of
  ret case x of
  ret case x of
  ret if _t0 then
  ret if b then
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
<=$Color x y  =
<=$Int x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
den r  =
eq$Color x y  =
eq$R a b  =
gt$Color x y  =
le$Color x y  =
le$Int x y  =
le$R a b  =
lt$Color x y  =
lt$R x y  =
main  =
not b  =
num r  =
yn b  =
