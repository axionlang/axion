













      drop d : String
      drop d : String
      let $fieldcopy0 = rtcall axion_strcat x ""  ; Δ{} · makes String
      let $fieldcopy0 = rtcall axion_strcat y ""  ; Δ{} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret $fieldcopy0  ; Δ{$fieldcopy0} · moves{$fieldcopy0}
      ret $fieldcopy0  ; Δ{$fieldcopy0} · moves{$fieldcopy0}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret d  ; Δ{}
      ret d  ; Δ{}
      ret d  ; Δ{}
      ret x  ; Δ{}
    Left _ ->
    Left x ->
    Left x ->
    Right _ ->
    Right _ ->
    Right y ->
    else
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd5 = rtcall axion_str_drop _dd4  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  drop _t0 : String
  drop _t1 : String
  drop _t10 : Either$String$Int
  drop _t11 : String
  drop _t16 : Either$String$String
  drop _t17 : String
  drop _t20 : Either$String$String
  drop _t21 : String
  drop _t24 : Either$Int$Int
  drop _t5 : Either$String$Int
  drop _t6 : String
  else
  else
  else
  else
  else
  let _d1000000 = + _t23 _t25  ; Δ{_t24}
  let _d1000000 = call strAppend$fn _cap0 _t0  ; Δ{_t0} · makes String
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = == _tag 0  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call strAppend$fn _cap0 s  ; Δ{} · makes String
  let _t0 = showInt 4242  ; Δ{} · makes String
  let _t0 = showInt 5  ; Δ{} · makes String
  let _t1 = call twiceS$$strAppend$fn "x" _t0  ; Δ{_t0} · makes String
  let _t10 = con Right 5  ; Δ{_t9} · makes Either$String$Int
  let _t11 = call fromLeft$String _t9 _t10  ; Δ{_t10 _t9} · moves{_t9} · makes String
  let _t12 = rtcall axion_str_len _t11  ; Δ{_t11}
  let _t13 = + _t8 _t12  ; Δ{}
  let _t14 = showInt 77  ; Δ{} · makes String
  let _t15 = showInt 9  ; Δ{_t14} · makes String
  let _t16 = con Left _t15  ; Δ{_t14 _t15} · moves{_t15} · makes Either$String$String
  let _t17 = call fromRight$String _t14 _t16  ; Δ{_t14 _t16} · moves{_t14} · makes String
  let _t18 = rtcall axion_str_len _t17  ; Δ{_t17}
  let _t19 = + _t13 _t18  ; Δ{}
  let _t2 = rtcall axion_str_len _t1  ; Δ{_t1}
  let _t20 = call pickE  ; Δ{} · makes Either$String$String
  let _t21 = call fromRight$String "lit" _t20  ; Δ{_t20} · makes String
  let _t22 = rtcall axion_str_len _t21  ; Δ{_t21}
  let _t23 = + _t19 _t22  ; Δ{}
  let _t24 = con Left 4  ; Δ{} · makes Either$Int$Int
  let _t25 = call fromLeft 3 _t24  ; Δ{_t24}
  let _t3 = showInt 1  ; Δ{} · makes String
  let _t4 = showInt 123  ; Δ{_t3} · makes String
  let _t5 = con Left _t4  ; Δ{_t3 _t4} · moves{_t4} · makes Either$String$Int
  let _t6 = call fromLeft$String _t3 _t5  ; Δ{_t3 _t5} · moves{_t3} · makes String
  let _t7 = rtcall axion_str_len _t6  ; Δ{_t6}
  let _t8 = + _t2 _t7  ; Δ{}
  let _t9 = rtcall axion_strcat "z" "z"  ; Δ{} · makes String
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{}
  ret case e of
  ret case e of
  ret case e of
  ret con Left _t0  ; Δ{_t0} · moves{_t0} · makes Either$String$String
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_strcat x0 x1  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_Either$Int _p  =
axion_drop_Either$Int$Int _p  =
axion_drop_Either$String _p  =
axion_drop_Either$String$Int _p  =
axion_drop_Either$String$String _p  =
axion_drop_List _p  =
fromLeft d e  =
fromLeft$String d e  =
fromRight$String d e  =
main  =
pickE  =
strAppend$fn x0 x1  =
twiceS$$strAppend$fn _cap0 s  =
