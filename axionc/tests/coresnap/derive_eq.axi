




            ret 0  ; Δ{}
            ret call eq$Int a1 b1  ; Δ{}
          else
          let _t0 = call eq$Int a0 b0  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret call eq$Int a0 b0  ; Δ{}
          ret if _t0 then
        Circle b0 ->
        Rect b0 b1 ->
        _ ->
        _ ->
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case y of
      ret case y of
    Circle a0 ->
    Rect a0 a1 ->
    drop _t3 : Shape
    drop _t4 : Shape
    else
    let _d1000000 = call eq$Shape _t3 _t4  ; Δ{_t3 _t4}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t3 = con Circle 1  ; Δ{} · makes Shape
    let _t4 = con Rect 0 0  ; Δ{_t3} · makes Shape
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret _d1000000  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : Shape
  drop _t1 : Shape
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = con Rect 2 3  ; Δ{} · makes Shape
  let _t1 = con Rect 2 3  ; Δ{_t0} · makes Shape
  let _t2 = call eq$Shape _t0 _t1  ; Δ{_t0 _t1}
  ret 0  ; Δ{}
  ret == x y  ; Δ{}
  ret case x of
  ret if _t2 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
eq$Int x y  =
eq$Shape x y  =
main  =
