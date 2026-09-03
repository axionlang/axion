
























                  drop _t20 : Pair$Eit$Int$Bool$Int
                  drop _t21 : Pair$Eit$Int$Bool$Int
                  drop _t23 : String
                  let _d1000000 = putStrLn _t23  ; Δ{_t23}
                  let _t20 = call nested1  ; Δ{} · makes Pair$Eit$Int$Bool$Int
                  let _t21 = call nested2  ; Δ{_t20} · makes Pair$Eit$Int$Bool$Int
                  let _t22 = call eq$Pair$Eit$Int$Bool$Int _t20 _t21  ; Δ{_t20 _t21}
                  let _t23 = call show$Bool _t22  ; Δ{} · makes String
                  ret _d1000000  ; Δ{}
                _ ->
              drop _t15 : Eit$Int$Bool
              drop _t16 : Eit$Int$Bool
              drop _t18 : String
              let _t15 = call e2  ; Δ{} · makes Eit$Int$Bool
              let _t16 = call e1  ; Δ{_t15} · makes Eit$Int$Bool
              let _t17 = call le$Eit$Int$Bool _t15 _t16  ; Δ{_t15 _t16}
              let _t18 = call show$Bool _t17  ; Δ{} · makes String
              let _t19 = putStrLn _t18  ; Δ{_t18}
              ret 1  ; Δ{}
              ret call le$Bool a1 b1  ; Δ{}
              ret case _t19 of
            _ ->
            else
            let _t1 = call le$Int b0 a0  ; Δ{}
            ret 0  ; Δ{}
            ret 0  ; Δ{}
            ret 0  ; Δ{}
            ret call eq$Bool a1 b1  ; Δ{}
            ret call eq$Int a1 b1  ; Δ{}
            ret if _t1 then
          drop _t10 : Eit$Int$Bool
          drop _t11 : Eit$Int$Bool
          drop _t13 : String
          else
          else
          else
          let _t0 = call eq$Eit$Int$Bool a0 b0  ; Δ{}
          let _t0 = call eq$Int a0 b0  ; Δ{}
          let _t0 = call le$Int a0 b0  ; Δ{}
          let _t10 = call e1  ; Δ{} · makes Eit$Int$Bool
          let _t11 = call e2  ; Δ{_t10} · makes Eit$Int$Bool
          let _t12 = call eq$Eit$Int$Bool _t10 _t11  ; Δ{_t10 _t11}
          let _t13 = call show$Bool _t12  ; Δ{} · makes String
          let _t14 = putStrLn _t13  ; Δ{_t13}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret call eq$Bool a0 b0  ; Δ{}
          ret call eq$Int a0 b0  ; Δ{}
          ret call le$Bool a0 b0  ; Δ{}
          ret call le$Int a0 b0  ; Δ{}
          ret case _t14 of
          ret if _t0 then
          ret if _t0 then
          ret if _t0 then
        Lft _ ->
        Lft b0 ->
        Lft b0 ->
        Pair b0 b1 ->
        Pair b0 b1 ->
        Pair b0 b1 ->
        Rgt b0 ->
        Rgt b0 ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
      drop _t5 : Pair$Int$Bool
      drop _t6 : Pair$Int$Bool
      drop _t8 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t5 = call p2  ; Δ{} · makes Pair$Int$Bool
      let _t6 = call p1  ; Δ{_t5} · makes Pair$Int$Bool
      let _t7 = call le$Pair$Int$Bool _t5 _t6  ; Δ{_t5 _t6}
      let _t8 = call show$Bool _t7  ; Δ{} · makes String
      let _t9 = putStrLn _t8  ; Δ{_t8}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret case _t9 of
      ret case y of
      ret case y of
      ret case y of
      ret case y of
      ret case y of
      ret case y of
      ret case y of
    Lft a0 ->
    Lft a0 ->
    Pair a0 a1 ->
    Pair a0 a1 ->
    Pair a0 a1 ->
    Rgt a0 ->
    Rgt a0 ->
    _ ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "false"  ; Δ{}
    ret "true"  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret if y then
    ret y  ; Δ{}
    ret y  ; Δ{}
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
  drop _t0 : Pair$Int$Bool
  drop _t1 : Pair$Int$Bool
  drop _t3 : String
  else
  else
  else
  else
  else
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd1 = call axion_drop_Eit$Int$Bool _dd0  ; Δ{}
  let _dd1 = call axion_drop_Eit$Int$Bool _dd0  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = 0  ; Δ{}
  let _t0 = 1  ; Δ{}
  let _t0 = 1  ; Δ{}
  let _t0 = 1  ; Δ{}
  let _t0 = 1  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = call p1  ; Δ{} · makes Pair$Int$Bool
  let _t1 = call p2  ; Δ{_t0} · makes Pair$Int$Bool
  let _t1 = con Rgt _t0  ; Δ{} · makes Eit$Int$Bool
  let _t1 = con Rgt _t0  ; Δ{} · makes Eit$Int$Bool
  let _t2 = call eq$Pair$Int$Bool _t0 _t1  ; Δ{_t0 _t1}
  let _t3 = call show$Bool _t2  ; Δ{} · makes String
  let _t4 = putStrLn _t3  ; Δ{_t3}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret == x y  ; Δ{}
  ret case _t4 of
  ret case x of
  ret case x of
  ret case x of
  ret case x of
  ret case x of
  ret con Lft 9  ; Δ{} · makes Eit$Int$Bool
  ret con Pair 3 _t0  ; Δ{} · makes Pair$Int$Bool
  ret con Pair 3 _t0  ; Δ{} · makes Pair$Int$Bool
  ret con Pair _t1 5  ; Δ{_t1} · moves{_t1} · makes Pair$Eit$Int$Bool$Int
  ret con Pair _t1 5  ; Δ{_t1} · moves{_t1} · makes Pair$Eit$Int$Bool$Int
  ret con Rgt _t0  ; Δ{} · makes Eit$Int$Bool
  ret if _t0 then
  ret if x then
  ret if x then
  ret if x then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_Eit$Int _p  =
axion_drop_Eit$Int$Bool _p  =
axion_drop_List _p  =
axion_drop_Pair$Eit$Int$Bool _p  =
axion_drop_Pair$Eit$Int$Bool$Int _p  =
axion_drop_Pair$Int _p  =
axion_drop_Pair$Int$Bool _p  =
e1  =
e2  =
eq$Bool x y  =
eq$Eit$Int$Bool x y  =
eq$Int x y  =
eq$Pair$Eit$Int$Bool$Int x y  =
eq$Pair$Int$Bool x y  =
le$Bool x y  =
le$Eit$Int$Bool x y  =
le$Int x y  =
le$Pair$Int$Bool x y  =
main  =
nested1  =
nested2  =
p1  =
p2  =
show$Bool x  =
