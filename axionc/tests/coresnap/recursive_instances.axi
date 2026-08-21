
























            _ ->
        _ ->
    _ ->
axion_drop_Array _p  =
axion_drop_Bin$Int _p  =
axion_drop_Bin _p  =
axion_drop_List$Rose$Int _p  =
axion_drop_List _p  =
axion_drop_Rose$Int _p  =
axion_drop_Rose _p  =
axion_drop_Two$Int$Bool _p  =
axion_drop_Two _p  =
bin  =
binEq  =
    Cons y ys ->
        Cons z zs ->
  drop _t0 : Bin$Int
          drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
  drop _t0 : String
              drop _t11 : Rose$Int
              drop _t12 : String
      drop _t1 : String
      drop _t1 : String
      drop _t1 : String
  drop _t1 : String
  drop _t1 : String
          drop _t2 : String
      drop _t2 : String
      drop _t2 : String
      drop _t3 : Bin$Int
          drop _t3 : String
      drop _t3 : String
      drop _t3 : String
      drop _t4 : Bin$Int
      drop _t4 : String
      drop _t4 : String
      drop _t5 : String
      drop _t5 : String
      drop _t6 : String
          drop _t8 : Two$Int$Bool
          drop _t9 : String
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
eq$Bin$Int s t  =
eq$Int x y  =
    Fork l v r ->
    Leaf x ->
              let _d1000000 = putStrLn _t12  ; Δ{_t12}
      let _d1000000 = rtcall axion_strcat "L" _t0  ; Δ{_t0} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
          let _d1000000 = rtcall axion_strcat _t0 _t3  ; Δ{_t0 _t3} · makes String
  let _d1000000 = rtcall axion_strcat "[" _t1  ; Δ{_t1} · makes String
      let _d1000000 = rtcall axion_strcat _t5 ")"  ; Δ{_t5} · makes String
      let _d1000001 = rtcall axion_strcat _t1 _t5  ; Δ{_t1 _t5} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+24  ; Δ{}
      let _dd0 = loadraw _p+24  ; Δ{}
    let _dd0 = loadraw _p+24  ; Δ{}
    let _dd0 = loadraw _p+24  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_Bin$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_Bin _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Rose$Int _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$Rose$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd1 = call axion_drop_Two$Int$Bool _dd0  ; Δ{}
    let _dd1 = call axion_drop_Two _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
      let _dd3 = call axion_drop_Bin$Int _dd2  ; Δ{}
      let _dd3 = call axion_drop_Bin _dd2  ; Δ{}
      let _dd3 = call axion_drop_Rose$Int _dd2  ; Δ{}
    let _dd3 = call axion_drop_Two$Int$Bool _dd2  ; Δ{}
    let _dd3 = call axion_drop_Two _dd2  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
  let _dd4 = == _tag 1  ; Δ{}
  let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call bin  ; Δ{} · makes Bin$Int
          let _t0 = call eq$Int v1 v2  ; Δ{}
      let _t0 = call show$Bin$Int l  ; Δ{} · makes String
          let _t0 = call show$Rose$Int y  ; Δ{} · makes String
      let _t0 = call showArg$Int x  ; Δ{} · makes String
      let _t0 = call showArg$Int x  ; Δ{} · makes String
  let _t0 = call showListElems$Rose$Int xs  ; Δ{} · makes String
  let _t0 = con Leaf 1  ; Δ{} · makes Two$Int$Bool
  let _t0 = con Nil  ; Δ{} · makes List$Rose$Int
  let _t0 = con Tip  ; Δ{} · makes Bin$Int
  let _t0 = con Tip  ; Δ{} · makes Bin$Int
          let _t10 = putStrLn _t9  ; Δ{_t9}
              let _t11 = call rose  ; Δ{} · makes Rose$Int
  let _t1 = 1  ; Δ{_t0}
              let _t12 = call show$Rose$Int _t11  ; Δ{_t11} · makes String
            let _t1 = call eq$Bin$Int l1 l2  ; Δ{}
  let _t1 = call show$Bin$Int _t0  ; Δ{_t0} · makes String
      let _t1 = call show$List$Rose$Int kids  ; Δ{_t0} · makes String
      let _t1 = call showArg$Two$Int$Bool l  ; Δ{} · makes String
          let _t1 = con Cons z zs  ; Δ{_t0}
  let _t1 = con Rose 2 _t0  ; Δ{_t0} · moves{_t0} · makes Rose$Int
  let _t1 = con Tip  ; Δ{_t0} · makes Bin$Int
  let _t1 = con Tip  ; Δ{_t0} · makes Bin$Int
      let _t1 = rtcall axion_strcat "(" _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 "]"  ; Δ{_t0} · makes String
      let _t2 = call showArg$Bool v  ; Δ{_t1} · makes String
      let _t2 = call showArg$Int v  ; Δ{_t1} · makes String
          let _t2 = call showListElems$Rose$Int _t1  ; Δ{_t0} · makes String
  let _t2 = con Leaf 2  ; Δ{_t0} · makes Two$Int$Bool
  let _t2 = con Nil  ; Δ{_t1} · makes List$Rose$Int
  let _t2 = con Node _t0 1 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes Bin$Int
  let _t2 = con Node _t0 1 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes Bin$Int
  let _t2 = putStrLn _t1  ; Δ{_t1}
      let _t3 = call bin  ; Δ{} · makes Bin$Int
      let _t3 = call show$Bin$Int r  ; Δ{_t1 _t2} · makes String
  let _t3 = con Rose 4 _t2  ; Δ{_t1 _t2} · moves{_t2} · makes Rose$Int
  let _t3 = con Tip  ; Δ{_t2} · makes Bin$Int
  let _t3 = con Tip  ; Δ{_t2} · makes Bin$Int
          let _t3 = rtcall axion_strcat ", " _t2  ; Δ{_t0 _t2} · makes String
      let _t3 = rtcall axion_strcat "-" _t2  ; Δ{_t1 _t2} · makes String
      let _t4 = call binEq  ; Δ{_t3} · makes Bin$Int
      let _t4 = call showArg$Two$Int$Bool r  ; Δ{_t1 _t3} · makes String
  let _t4 = con Nil  ; Δ{_t1 _t3} · makes List$Rose$Int
  let _t4 = con Tip  ; Δ{_t2 _t3} · makes Bin$Int
  let _t4 = con Tip  ; Δ{_t2 _t3} · makes Bin$Int
      let _t4 = rtcall axion_strcat _t2 _t3  ; Δ{_t1 _t2 _t3} · makes String
      let _t5 = call eq$Bin$Int _t3 _t4  ; Δ{_t3 _t4}
  let _t5 = con Cons _t3 _t4  ; Δ{_t1 _t3 _t4} · moves{_t3 _t4} · makes List$Rose$Int
  let _t5 = con Node _t3 3 _t4  ; Δ{_t2 _t3 _t4} · moves{_t3 _t4} · makes Bin$Int
  let _t5 = con Node _t3 3 _t4  ; Δ{_t2 _t3 _t4} · moves{_t3 _t4} · makes Bin$Int
      let _t5 = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
      let _t5 = rtcall axion_strcat _t3 _t4  ; Δ{_t1 _t3 _t4} · makes String
      let _t6 = call show$Bool _t5  ; Δ{} · makes String
  let _t6 = con Rose 3 _t5  ; Δ{_t1 _t5} · moves{_t5} · makes Rose$Int
  let _t7 = con Nil  ; Δ{_t1 _t6} · makes List$Rose$Int
      let _t7 = putStrLn _t6  ; Δ{_t6}
          let _t8 = call two  ; Δ{} · makes Two$Int$Bool
  let _t8 = con Cons _t6 _t7  ; Δ{_t1 _t6 _t7} · moves{_t6 _t7} · makes List$Rose$Int
          let _t9 = call show$Two$Int$Bool _t8  ; Δ{_t8} · makes String
  let _t9 = con Cons _t1 _t8  ; Δ{_t1 _t8} · moves{_t1 _t8} · makes List$Rose$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
main  =
        Nil ->
    Nil ->
    Node l1 v1 r1 ->
        Node l2 v2 r2 ->
        Node l2 v2 r2 ->
    Node l v r ->
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
  ret 0  ; Δ{}
  ret 0  ; Δ{}
          ret 1  ; Δ{}
              ret call eq$Bin$Int r1 r2  ; Δ{}
          ret call show$Rose$Int y  ; Δ{} · makes String
  ret call show$Two$Int$Bool t  ; Δ{} · makes String
  ret case r of
  ret case s of
          ret case _t10 of
  ret case _t2 of
      ret case _t7 of
      ret case t of
      ret case t of
  ret case t of
  ret case t of
  ret case xs of
      ret case ys of
  ret con Fork _t0 _t1 _t2  ; Δ{_t0 _t2} · moves{_t0 _t2} · makes Two$Int$Bool
  ret con Node _t2 2 _t5  ; Δ{_t2 _t5} · moves{_t2 _t5} · makes Bin$Int
  ret con Node _t2 2 _t5  ; Δ{_t2 _t5} · moves{_t2 _t5} · makes Bin$Int
  ret con Rose 1 _t9  ; Δ{_t9} · moves{_t9} · makes Rose$Int
              ret _d1000000  ; Δ{}
          ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
    ret "false"  ; Δ{}
    ret "false"  ; Δ{}
          ret if _t0 then
            ret if _t1 then
  ret if x then
  ret if x then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
    ret "true"  ; Δ{}
    ret "true"  ; Δ{}
  ret == x y  ; Δ{}
      ret ""  ; Δ{}
      ret "."  ; Δ{}
rose  =
    Rose x kids ->
show$Bin$Int t  =
show$Bool x  =
show$List$Rose$Int xs  =
show$Rose$Int r  =
show$Two$Int$Bool t  =
showArg$Bool x  =
showArg$Int x  =
showArg$Two$Int$Bool t  =
showListElems$Rose$Int xs  =
        Tip ->
        Tip ->
    Tip ->
    Tip ->
two  =
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
