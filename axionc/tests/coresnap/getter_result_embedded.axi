









      let $borrowcopy0 = rtcall axion_strcat _t0 ""  ; Δ{_t1} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$P _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_P _dd2  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call lenS r  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call nameOf y  ; Δ{}
      let _t1 = call names ys  ; Δ{} · makes List$String
      ret + 1 _t0  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret a  ; Δ{}
      ret con Cons $borrowcopy0 _t1  ; Δ{$borrowcopy0 _t1} · moves{$borrowcopy0 _t1} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
    Cons _ r ->
    Cons y ys ->
    Cons y ys ->
    Nil ->
    Nil ->
    Nil ->
    P a _ ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
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
  drop _t10 : String
  drop _t6 : List$String
  drop ps : List$P
  else
  else
  else
  let _d1000000 = putStrLn _t10  ; Δ{_t10}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = rtcall axion_strcat "a" ""  ; Δ{} · makes String
  let _t1 = con P _t0 1  ; Δ{_t0} · moves{_t0} · makes P
  let _t10 = showInt _t9  ; Δ{} · makes String
  let _t2 = rtcall axion_strcat "bb" ""  ; Δ{_t1} · makes String
  let _t3 = con P _t2 2  ; Δ{_t1 _t2} · moves{_t2} · makes P
  let _t4 = con Nil  ; Δ{_t1 _t3} · makes List$P
  let _t5 = con Cons _t3 _t4  ; Δ{_t1 _t3 _t4} · moves{_t3 _t4} · makes List$P
  let _t6 = call names ps  ; Δ{ps} · makes List$String
  let _t7 = call lenS _t6  ; Δ{_t6 ps}
  let _t8 = call length ps  ; Δ{ps}
  let _t9 = + _t7 _t8  ; Δ{}
  let ps = con Cons _t1 _t5  ; Δ{_t1 _t5} · moves{_t1 _t5} · makes List$P
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case p of
  ret case xs of
  ret case xs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$P _p  =
axion_drop_List$String _p  =
axion_drop_P _p  =
lenS xs  =
length xs  =
main  =
nameOf p  =
names xs  =
