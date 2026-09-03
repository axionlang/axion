







          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret call eq$Int a0 b0  ; Δ{}
          ret call le$Int a0 b0  ; Δ{}
        None ->
        None ->
        None ->
        Some b0 ->
        Some b0 ->
        _ ->
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
      ret case y of
    None ->
    None ->
    Some a0 ->
    Some a0 ->
    drop _t3 : Option$Int
    drop _t4 : Option$Int
    else
    let _d1000000 = call eq$Option$Int _t3 _t4  ; Δ{_t3 _t4}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t3 = con Some 5  ; Δ{} · makes Option$Int
    let _t4 = con Some 5  ; Δ{_t3} · makes Option$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret _d1000000  ; Δ{}
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
  drop _t0 : Option$Int
  drop _t1 : Option$Int
  else
  else
  else
  else
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = < x y  ; Δ{}
  let _t0 = con None  ; Δ{} · makes Option$Int
  let _t1 = con Some 3  ; Δ{_t0} · makes Option$Int
  let _t2 = call le$Option$Int _t0 _t1  ; Δ{_t0 _t1}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret == x y  ; Δ{}
  ret case x of
  ret case x of
  ret if _t0 then
  ret if _t2 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Option$Int _p  =
eq$Int x y  =
eq$Option$Int x y  =
le$Int x y  =
le$Option$Int x y  =
main  =
