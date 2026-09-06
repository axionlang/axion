












          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
        High ->
        Low ->
        Low ->
        Low ->
        Mid ->
        Mid ->
        _ ->
        _ ->
        _ ->
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case y of
      ret case y of
      ret case y of
    High ->
    Low ->
    Mid ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t2 = rtcall axion_str_cmp x y  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret == _t2 0  ; Δ{}
    ret == x y  ; Δ{}
    ret ==. x y  ; Δ{}
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
  else
  else
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = < x y  ; Δ{}
  let _t0 = <. x y  ; Δ{}
  let _t0 = call >=$Int 3 3  ; Δ{}
  let _t0 = rtcall axion_str_cmp x y  ; Δ{}
  let _t1 = < _t0 0  ; Δ{}
  let _t1 = call b2i _t0  ; Δ{}
  let _t10 = call b2i _t9  ; Δ{}
  let _t11 = + _t7 _t10  ; Δ{}
  let _t12 = call <=$Float 3.5f 3.5f  ; Δ{}
  let _t13 = call b2i _t12  ; Δ{}
  let _t14 = + _t11 _t13  ; Δ{}
  let _t15 = call <=$String "abc" "abd"  ; Δ{}
  let _t16 = call b2i _t15  ; Δ{}
  let _t17 = + _t14 _t16  ; Δ{}
  let _t18 = con High  ; Δ{}
  let _t19 = con Mid  ; Δ{}
  let _t2 = call <=$Int 2 5  ; Δ{}
  let _t20 = call >=$Rank _t18 _t19  ; Δ{}
  let _t21 = call b2i _t20  ; Δ{}
  let _t22 = + _t17 _t21  ; Δ{}
  let _t23 = con Low  ; Δ{}
  let _t24 = con Mid  ; Δ{}
  let _t25 = call >=$Rank _t23 _t24  ; Δ{}
  let _t26 = call b2i _t25  ; Δ{}
  let _t3 = call b2i _t2  ; Δ{}
  let _t4 = + _t1 _t3  ; Δ{}
  let _t5 = call <=$Int 5 2  ; Δ{}
  let _t6 = call b2i _t5  ; Δ{}
  let _t7 = + _t4 _t6  ; Δ{}
  let _t8 = + 1 2  ; Δ{}
  let _t9 = call >=$Int _t8 3  ; Δ{}
  ret + _t22 _t26  ; Δ{}
  ret 0  ; Δ{}
  ret call le$Float x y  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call le$Rank y x  ; Δ{}
  ret call le$String x y  ; Δ{}
  ret case x of
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if x then
  ret rtcall axion_array_free _p  ; Δ{}
<=$Float x y  =
<=$Int x y  =
<=$String x y  =
>=$Int x y  =
>=$Rank x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
b2i x  =
le$Float x y  =
le$Int x y  =
le$Rank x y  =
le$String x y  =
main  =
