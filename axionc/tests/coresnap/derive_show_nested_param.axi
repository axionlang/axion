














    _ ->
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Option$Bool _p  =
axion_drop_Option$Int _p  =
axion_drop_Option$Option$Bool _p  =
axion_drop_Option$Option$Int _p  =
axion_drop_Option$Option$Option$Bool _p  =
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
      drop _t0 : String
  drop _t1 : Option$Option$Int
      drop _t1 : String
      drop _t1 : String
      drop _t1 : String
      drop _t1 : String
      drop _t1 : String
      drop _t2 : String
      drop _t2 : String
      drop _t2 : String
  drop _t2 : String
      drop _t3 : String
      drop _t3 : String
      drop _t3 : String
      drop _t7 : Option$Option$Option$Bool
      drop _t8 : String
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
      let _d1000000 = putStrLn _t8  ; Δ{_t8}
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _d1000000 = rtcall axion_strcat _t3 ")"  ; Δ{_t3} · makes String
      let _d1000000 = rtcall axion_strcat _t3 ")"  ; Δ{_t3} · makes String
      let _d1000000 = rtcall axion_strcat _t3 ")"  ; Δ{_t3} · makes String
  let _dd0 = band _p 1  ; Δ{}
  let _dd0 = band _p 1  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_Option$Bool _dd0  ; Δ{}
      let _dd1 = call axion_drop_Option$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_Option$Option$Bool _dd0  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd1 = if _dd0 then
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = con Some 3  ; Δ{} · makes Option$Int
      let _t0 = rtcall axion_strcat "Some" " "  ; Δ{} · makes String
      let _t0 = rtcall axion_strcat "Some" " "  ; Δ{} · makes String
      let _t0 = rtcall axion_strcat "Some" " "  ; Δ{} · makes String
      let _t0 = rtcall axion_strcat "Some" " "  ; Δ{} · makes String
      let _t0 = rtcall axion_strcat "Some" " "  ; Δ{} · makes String
      let _t1 = call showArg$Bool a0  ; Δ{_t0} · makes String
      let _t1 = call showArg$Int a0  ; Δ{_t0} · makes String
      let _t1 = call showArg$Option$Bool a0  ; Δ{_t0} · makes String
      let _t1 = call showArg$Option$Int a0  ; Δ{_t0} · makes String
      let _t1 = call showArg$Option$Option$Bool a0  ; Δ{_t0} · makes String
  let _t1 = con Some _t0  ; Δ{_t0} · moves{_t0} · makes Option$Option$Int
  let _t2 = call show$Option$Option$Int _t1  ; Δ{_t1} · makes String
      let _t2 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _t2 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _t2 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
  let _t3 = putStrLn _t2  ; Δ{_t2}
      let _t3 = rtcall axion_strcat "(" _t2  ; Δ{_t2} · makes String
      let _t3 = rtcall axion_strcat "(" _t2  ; Δ{_t2} · makes String
      let _t3 = rtcall axion_strcat "(" _t2  ; Δ{_t2} · makes String
      let _t4 = < 5 6  ; Δ{}
      let _t5 = con Some _t4  ; Δ{} · makes Option$Bool
      let _t6 = con Some _t5  ; Δ{_t5} · moves{_t5} · makes Option$Option$Bool
      let _t7 = con Some _t6  ; Δ{_t6} · moves{_t6} · makes Option$Option$Option$Bool
      let _t8 = call show$Option$Option$Option$Bool _t7  ; Δ{_t7} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
    None ->
    None ->
    None ->
    None ->
    None ->
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
  ret case _t3 of
  ret case x of
  ret case x of
  ret case x of
  ret case x of
  ret case x of
      ret _d1000000  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret "false"  ; Δ{}
  ret if x then
      ret "None"  ; Δ{}
      ret "None"  ; Δ{}
      ret "None"  ; Δ{}
      ret "None"  ; Δ{}
      ret "None"  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
    ret "true"  ; Δ{}
show$Option$Option$Int x  =
show$Option$Option$Option$Bool x  =
showArg$Bool x  =
showArg$Int x  =
showArg$Option$Bool x  =
showArg$Option$Int x  =
showArg$Option$Option$Bool x  =
    Some a0 ->
    Some a0 ->
    Some a0 ->
    Some a0 ->
    Some a0 ->
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
