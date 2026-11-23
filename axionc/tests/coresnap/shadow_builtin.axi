











                      drop _t19 : List$Int
                      drop _t20 : List$Int
                      drop _t22 : String
                      let _d1000000 = putStrLn _t22  ; Δ{_t22}
                      let _t16 = con Nil  ; Δ{} · makes List$Int
                      let _t17 = con Cons 3 _t16  ; Δ{_t16} · moves{_t16} · makes List$Int
                      let _t18 = con Cons 2 _t17  ; Δ{_t17} · moves{_t17} · makes List$Int
                      let _t19 = con Cons 1 _t18  ; Δ{_t18} · moves{_t18} · makes List$Int
                      let _t20 = call map$$fromInt _t19  ; Δ{_t19} · makes List$Int
                      let _t21 = call sum _t20  ; Δ{_t20}
                      let _t22 = showInt _t21  ; Δ{} · makes String
                      ret _d1000000  ; Δ{}
                    _ ->
                  drop _t14 : String
                  let _t13 = call twice 5  ; Δ{}
                  let _t14 = showInt _t13  ; Δ{} · makes String
                  let _t15 = putStrLn _t14  ; Δ{_t14}
                  ret case _t15 of
                _ ->
              drop _t11 : String
              let _t10 = call lenArray 7  ; Δ{}
              let _t11 = showInt _t10  ; Δ{} · makes String
              let _t12 = putStrLn _t11  ; Δ{_t11}
              ret case _t12 of
            _ ->
          drop _t8 : String
          let _t6 = - 0 3  ; Δ{}
          let _t7 = call abs _t6  ; Δ{}
          let _t8 = showInt _t7  ; Δ{} · makes String
          let _t9 = putStrLn _t8  ; Δ{_t8}
          ret case _t9 of
        _ ->
      drop _t4 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call fromInt y  ; Δ{}
      let _t0 = call sum ys  ; Δ{}
      let _t1 = call map$$fromInt ys  ; Δ{} · makes List$Int
      let _t3 = call toFloat 5  ; Δ{}
      let _t4 = showInt _t3  ; Δ{} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t5 of
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
    Cons y ys ->
    Cons y ys ->
    Nil ->
    Nil ->
    _ ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = * n 10  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret * n 10  ; Δ{}
    ret - 0 _t1  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
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
  drop _t1 : String
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = * n 2  ; Δ{}
  let _t0 = < n 0  ; Δ{}
  let _t0 = call fromInt 20  ; Δ{}
  let _t0 = call twice$sqrt n  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret * k 2  ; Δ{}
  ret + _t0 1  ; Δ{}
  ret + n 100  ; Δ{}
  ret - n 1  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call twice$sqrt _t0  ; Δ{}
  ret case _t2 of
  ret case xs of
  ret case xs of
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
abs n  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
fromInt n  =
lenArray n  =
main  =
map$$fromInt xs  =
sum xs  =
toFloat n  =
twice n  =
twice$sqrt k  =
