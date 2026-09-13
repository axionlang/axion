






      drop _t0 : String
      drop _t1 : String
      let _d1000000 = rtcall axion_strcat _t0 _t1  ; Δ{_t0 _t1} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call consume e  ; Δ{} · makes String
      let _t1 = call work rest  ; Δ{_t0} · makes String
      ret ""  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    Cons e rest ->
    Nil ->
    drop _t1 : String
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = showInt n  ; Δ{} · makes String
    let _t2 = rtcall axion_strcat "e" _t1  ; Δ{_t1} · makes String
    let _t3 = - n 1  ; Δ{_t2}
    let _t4 = call mk _t3  ; Δ{_t2} · makes List$String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret con Cons _t2 _t4  ; Δ{_t2 _t4} · moves{_t2 _t4} · makes List$String
    ret con Nil  ; Δ{} · makes List$String
    ret name  ; Δ{}
    ret rtcall axion_strcat "x" "y"  ; Δ{} · makes String
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : List$String
  drop _t1 : String
  else
  else
  else
  else
  let _d1000000 = putStrLn _t1  ; Δ{_t1}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = == n 0  ; Δ{}
  let _t0 = call mk 3  ; Δ{} · makes List$String
  let _t0 = rtcall axion_str_len name  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = call work _t0  ; Δ{_t0} · makes String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case xs of
  ret if _t0 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
consume name  =
main  =
mk n  =
work xs  =
