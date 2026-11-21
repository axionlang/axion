












                      drop _t25 : String
                      drop arr : Array
                      let _d1000000 = putStrLn _t25  ; Δ{_t25}
                      let _t21 = call pick arr 50  ; Δ{arr}
                      let _t22 = - 0 5  ; Δ{arr}
                      let _t23 = call pick arr _t22  ; Δ{arr}
                      let _t24 = + _t21 _t23  ; Δ{}
                      let _t25 = showInt _t24  ; Δ{} · makes String
                      ret _d1000000  ; Δ{}
                    _ ->
                  drop _t19 : String
                  let _t16 = call safeGet arr 4  ; Δ{arr}
                  let _t17 = call safeGet arr 12  ; Δ{arr}
                  let _t18 = + _t16 _t17  ; Δ{arr}
                  let _t19 = showInt _t18  ; Δ{arr} · makes String
                  let _t20 = putStrLn _t19  ; Δ{_t19 arr}
                  ret case _t20 of
                _ ->
              drop _t14 : String
              let _t13 = call sumFrom arr 0 0  ; Δ{arr}
              let _t14 = showInt _t13  ; Δ{arr} · makes String
              let _t15 = putStrLn _t14  ; Δ{_t14 arr}
              ret case _t15 of
            _ ->
          drop _t11 : String
          let _t10 = call search arr 100 0 _t9  ; Δ{arr}
          let _t11 = showInt _t10  ; Δ{arr} · makes String
          let _t12 = putStrLn _t11  ; Δ{_t11 arr}
          let _t9 = rtcall axion_array_len arr  ; Δ{arr}
          ret case _t12 of
        _ ->
      drop _t7 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t5 = + mid 1  ; Δ{}
      let _t5 = rtcall axion_array_len arr  ; Δ{arr}
      let _t6 = call search arr 10 0 _t5  ; Δ{arr}
      let _t7 = showInt _t6  ; Δ{arr} · makes String
      let _t8 = putStrLn _t7  ; Δ{_t7 arr}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret call search a x _t5 hi  ; Δ{}
      ret call search a x lo mid  ; Δ{}
      ret case _t8 of
      ret hi  ; Δ{}
      ret x  ; Δ{}
    _ ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t0 = > x hi  ; Δ{}
    let _t1 = - hi lo  ; Δ{}
    let _t1 = rtcall axion_array_len a  ; Δ{}
    let _t2 = * i 3  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = div _t1 2  ; Δ{}
    let _t2 = rtcall axion_array_len a  ; Δ{}
    let _t3 = - _t2 1  ; Δ{}
    let _t3 = call get a i  ; Δ{}
    let _t3 = rtcall axion_array_get_nobc a mid  ; Δ{}
    let _t3 = rtcall axion_array_set_nobc a i _t2  ; Δ{} · makes Array
    let _t4 = + acc _t3  ; Δ{}
    let _t4 = + i 1  ; Δ{_t3}
    let _t4 = < _t3 x  ; Δ{}
    let _t4 = call clamp k _t3  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let mid = + lo _t2  ; Δ{}
    ret - 0 1  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret < i _t1  ; Δ{}
    ret == x y  ; Δ{}
    ret a  ; Δ{}
    ret acc  ; Δ{}
    ret call fill _t3 _t4  ; Δ{_t3} · moves{_t3} · makes Array
    ret call get a _t4  ; Δ{}
    ret call get a i  ; Δ{}
    ret call sumFrom a _t2 _t4  ; Δ{}
    ret if _t0 then
    ret if _t4 then
    ret lo  ; Δ{}
  ; Δ{arr}
  ; Δ{arr}
  ; Δ{arr}
  ; Δ{arr}
  ; Δ{arr}
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
  else
  else
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = < x y  ; Δ{}
  let _t0 = call <=$Int 0 i  ; Δ{}
  let _t0 = call >=$Int lo hi  ; Δ{}
  let _t0 = newArray 10 0  ; Δ{} · makes Array
  let _t0 = rtcall axion_array_len a  ; Δ{}
  let _t0 = rtcall axion_array_len a  ; Δ{}
  let _t0 = rtcall axion_array_len a  ; Δ{}
  let _t1 = < i _t0  ; Δ{}
  let _t1 = < x 0  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = rtcall axion_array_len arr  ; Δ{arr}
  let _t2 = call search arr 9 0 _t1  ; Δ{arr}
  let _t2 = if _t0 then
  let _t3 = showInt _t2  ; Δ{arr} · makes String
  let _t4 = putStrLn _t3  ; Δ{_t3 arr}
  let arr = call fill _t0 0  ; Δ{_t0} · moves{_t0} · makes Array
  ret 0  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret case _t4 of
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t2 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_array_get_nobc a i  ; Δ{}
<=$Int x y  =
>=$Int x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
clamp x hi  =
fill a i  =
get a i  =
le$Int x y  =
main  =
pick a k  =
safeGet a i  =
search a x lo hi  =
sumFrom a i acc  =
