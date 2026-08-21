






axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Tree _p  =
      drop _t0 : String
      drop _t0 : String
      drop _t1 : String
      drop _t1 : String
      drop _t2 : String
      drop _t2 : String
      drop _t3 : String
      drop _t3 : String
      drop _t4 : String
      drop _t4 : String
      drop _t5 : String
      drop _t5 : String
      drop _t6 : String
      drop _t6 : String
  drop _t6 : Tree
      drop _t7 : String
      drop _t7 : String
  drop _t7 : String
      drop _t8 : String
      drop _t9 : String
    else
    else
  else
  else
    Leaf ->
    Leaf ->
  let _d1000000 = putStrLn _t7  ; Δ{_t7}
      let _d1000000 = rtcall axion_strcat _t6 _t7  ; Δ{_t6 _t7} · makes String
      let _d1000000 = rtcall axion_strcat _t9 ")"  ; Δ{_t9} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+24  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_Tree _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
      let _dd3 = call axion_drop_Tree _dd2  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = con Leaf  ; Δ{} · makes Tree
      let _t0 = rtcall axion_strcat "Node" " "  ; Δ{} · makes String
      let _t0 = rtcall axion_strcat "Node" " "  ; Δ{} · makes String
      let _t1 = call showArg$Tree a0  ; Δ{_t0} · makes String
      let _t1 = call showArg$Tree a0  ; Δ{_t0} · makes String
  let _t1 = con Leaf  ; Δ{_t0} · makes Tree
  let _t2 = con Node _t0 1 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes Tree
      let _t2 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _t2 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
  let _t3 = con Leaf  ; Δ{_t2} · makes Tree
      let _t3 = rtcall axion_strcat _t2 " "  ; Δ{_t2} · makes String
      let _t3 = rtcall axion_strcat _t2 " "  ; Δ{_t2} · makes String
      let _t4 = call showArg$Int a1  ; Δ{_t3} · makes String
      let _t4 = call showArg$Int a1  ; Δ{_t3} · makes String
  let _t4 = con Leaf  ; Δ{_t2 _t3} · makes Tree
  let _t5 = con Node _t3 3 _t4  ; Δ{_t2 _t3 _t4} · moves{_t3 _t4} · makes Tree
      let _t5 = rtcall axion_strcat _t3 _t4  ; Δ{_t3 _t4} · makes String
      let _t5 = rtcall axion_strcat _t3 _t4  ; Δ{_t3 _t4} · makes String
  let _t6 = con Node _t2 2 _t5  ; Δ{_t2 _t5} · moves{_t2 _t5} · makes Tree
      let _t6 = rtcall axion_strcat _t5 " "  ; Δ{_t5} · makes String
      let _t6 = rtcall axion_strcat _t5 " "  ; Δ{_t5} · makes String
  let _t7 = call show$Tree _t6  ; Δ{_t6} · makes String
      let _t7 = call showArg$Tree a2  ; Δ{_t6} · makes String
      let _t7 = call showArg$Tree a2  ; Δ{_t6} · makes String
      let _t8 = rtcall axion_strcat _t6 _t7  ; Δ{_t6 _t7} · makes String
      let _t9 = rtcall axion_strcat "(" _t8  ; Δ{_t8} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
    Node a0 a1 a2 ->
    Node a0 a1 a2 ->
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
  ret case x of
  ret case x of
  ret _d1000000  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret "Leaf"  ; Δ{}
      ret "Leaf"  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
show$Tree x  =
showArg$Int x  =
showArg$Tree x  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
