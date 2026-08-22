






















                _ ->
            _ ->
        _ ->
    _ ->
axion_drop_Array _p  =
axion_drop_List$Int _p  =
axion_drop_List _p  =
axion_drop_Pair$Bool$Int _p  =
axion_drop_Pair$Int$Bool _p  =
axion_drop_Pair$List$Int$Bool _p  =
bi  =
    Cons y ys ->
    Cons z zs ->
diff  =
  drop _t0 : Pair$Int$Bool
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
  drop _t0 : String
              drop _t10 : Pair$Int$Bool
              drop _t12 : String
                  drop _t14 : Pair$Int$Bool
                  drop _t15 : Pair$Int$Bool
                  drop _t17 : String
      drop _t1 : String
      drop _t1 : String
      drop _t1 : String
      drop _t1 : String
      drop _t1 : String
  drop _t1 : String
  drop _t1 : String
      drop _t2 : String
      drop _t2 : String
      drop _t2 : String
      drop _t2 : String
      drop _t3 : Pair$Bool$Int
      drop _t3 : String
      drop _t3 : String
      drop _t3 : String
      drop _t4 : String
      drop _t4 : String
      drop _t4 : String
      drop _t4 : String
          drop _t6 : Pair$List$Int$Bool
          drop _t7 : String
              drop _t9 : Pair$Int$Bool
          else
    else
    else
    else
  else
  else
  else
  else
eq$Bool x y  =
eq$Int x y  =
eq$Pair$Int$Bool p q  =
ib  =
                  let _d1000000 = putStrLn _t17  ; Δ{_t17}
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
  let _d1000000 = rtcall axion_strcat "[" _t1  ; Δ{_t1} · makes String
      let _d1000000 = rtcall axion_strcat ", " _t2  ; Δ{_t2} · makes String
      let _d1000000 = rtcall axion_strcat _t4 ">"  ; Δ{_t4} · makes String
      let _d1000000 = rtcall axion_strcat _t4 ">"  ; Δ{_t4} · makes String
      let _d1000000 = rtcall axion_strcat _t4 ">"  ; Δ{_t4} · makes String
  let _dd0 = loadraw _p+0  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = 0  ; Δ{}
  let _t0 = 0  ; Δ{}
  let _t0 = 1  ; Δ{}
  let _t0 = 1  ; Δ{}
          let _t0 = call eq$Int x1 x2  ; Δ{}
  let _t0 = call ib  ; Δ{} · makes Pair$Int$Bool
      let _t0 = call show$Bool x  ; Δ{} · makes String
      let _t0 = call show$Int x  ; Δ{} · makes String
      let _t0 = call show$Int y  ; Δ{} · makes String
      let _t0 = call show$Int z  ; Δ{} · makes String
      let _t0 = call show$List$Int x  ; Δ{} · makes String
  let _t0 = call showListElems$Int xs  ; Δ{} · makes String
  let _t0 = con Nil  ; Δ{} · makes List$Int
              let _t10 = call same  ; Δ{_t9} · makes Pair$Int$Bool
              let _t11 = call eq$Pair$Int$Bool _t9 _t10  ; Δ{_t10 _t9}
              let _t12 = call show$Bool _t11  ; Δ{} · makes String
              let _t13 = putStrLn _t12  ; Δ{_t12}
                  let _t14 = call ib  ; Δ{} · makes Pair$Int$Bool
                  let _t15 = call diff  ; Δ{_t14} · makes Pair$Int$Bool
                  let _t16 = call eq$Pair$Int$Bool _t14 _t15  ; Δ{_t14 _t15}
                  let _t17 = call show$Bool _t16  ; Δ{} · makes String
  let _t1 = call show$Pair$Int$Bool _t0  ; Δ{_t0} · makes String
      let _t1 = call showListRest$Int ys  ; Δ{_t0} · makes String
      let _t1 = call showListRest$Int zs  ; Δ{_t0} · makes String
  let _t1 = con Cons 2 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
      let _t1 = rtcall axion_strcat "<" _t0  ; Δ{_t0} · makes String
      let _t1 = rtcall axion_strcat "<" _t0  ; Δ{_t0} · makes String
      let _t1 = rtcall axion_strcat "<" _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "]"  ; Δ{_t0} · makes String
      let _t2 = call show$Bool y  ; Δ{_t1} · makes String
      let _t2 = call show$Bool y  ; Δ{_t1} · makes String
      let _t2 = call show$Int y  ; Δ{_t1} · makes String
  let _t2 = con Cons 1 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t2 = putStrLn _t1  ; Δ{_t1}
      let _t2 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
  let _t3 = 1  ; Δ{_t2}
      let _t3 = call bi  ; Δ{} · makes Pair$Bool$Int
      let _t3 = rtcall axion_strcat " | " _t2  ; Δ{_t1 _t2} · makes String
      let _t3 = rtcall axion_strcat " | " _t2  ; Δ{_t1 _t2} · makes String
      let _t3 = rtcall axion_strcat " | " _t2  ; Δ{_t1 _t2} · makes String
      let _t4 = call show$Pair$Bool$Int _t3  ; Δ{_t3} · makes String
      let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
      let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
      let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
          let _t6 = call withList  ; Δ{} · makes Pair$List$Int$Bool
          let _t7 = call show$Pair$List$Int$Bool _t6  ; Δ{_t6} · makes String
          let _t8 = putStrLn _t7  ; Δ{_t7}
              let _t9 = call ib  ; Δ{} · makes Pair$Int$Bool
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
    Nil ->
    Nil ->
    Pair x1 y1 ->
        Pair x2 y2 ->
    Pair x y ->
    Pair x y ->
    Pair x y ->
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
            ret call eq$Bool y1 y2  ; Δ{}
  ret case p of
  ret case p of
  ret case p of
  ret case p of
      ret case q of
              ret case _t13 of
  ret case _t2 of
      ret case _t5 of
          ret case _t8 of
  ret case xs of
  ret case ys of
  ret con Pair 7 _t0  ; Δ{} · makes Pair$Int$Bool
  ret con Pair 7 _t0  ; Δ{} · makes Pair$Int$Bool
  ret con Pair 7 _t0  ; Δ{} · makes Pair$Int$Bool
  ret con Pair _t0 42  ; Δ{} · makes Pair$Bool$Int
  ret con Pair _t2 _t3  ; Δ{_t2} · moves{_t2} · makes Pair$List$Int$Bool
                  ret _d1000000  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret "false"  ; Δ{}
          ret if _t0 then
  ret if x then
  ret if x then
    ret if y then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
    ret "true"  ; Δ{}
  ret == x y  ; Δ{}
    ret y  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
same  =
show$Bool x  =
show$Int x  =
show$List$Int xs  =
show$Pair$Bool$Int p  =
show$Pair$Int$Bool p  =
show$Pair$List$Int$Bool p  =
showListElems$Int xs  =
showListRest$Int ys  =
withList  =
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
