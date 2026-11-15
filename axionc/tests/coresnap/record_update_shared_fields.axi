









      let $updfield1 = field name r  ; Δ{}
      let $updfield1c0 = rtcall axion_strcat $updfield1 ""  ; Δ{} · makes String
      let $updfield2 = field items r  ; Δ{$updfield1c0}
      let $updfield2c1 = call axion_copy_List$String $updfield2  ; Δ{$updfield1c0} · makes List$String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = call axion_drop_Rec _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = con Nil  ; Δ{} · makes List$String
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret record Rec { name = "" items = _t0 note = ""}  ; Δ{_t0} · moves{_t0} · makes Rec
      ret update r { note = "first" items = $updfield2c1 name = $updfield1c0}  ; Δ{$updfield1c0 $updfield2c1} · moves{$updfield1c0 $updfield2c1} · makes heap
    Cons y ys ->
    Just r ->
    Nil ->
    Nothing ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
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
  drop _t10 : Rec
  drop _t12 : Rec
  drop _t13 : Rec
  drop _t18 : Rec
  drop m : Maybe$Rec
  drop v0 : Rec
  else
  else
  else
  let $updfield1 = field items r  ; Δ{}
  let $updfield1c0 = call axion_copy_List$String $updfield1  ; Δ{} · makes List$String
  let $updfield2 = field note r  ; Δ{$updfield1c0}
  let $updfield2c1 = rtcall axion_strcat $updfield2 ""  ; Δ{$updfield1c0} · makes String
  let _dd0 = loadraw _p+16  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+8  ; Δ{}
  let _dd3 = call axion_drop_List$String _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = loadraw _p+0  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = rtcall axion_str_drop _dd4  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = field name r  ; Δ{}
  let _t0 = showInt 917  ; Δ{} · makes String
  let _t1 = rtcall axion_str_len _t0  ; Δ{}
  let _t1 = rtcall axion_strcat "a" "b"  ; Δ{_t0} · makes String
  let _t10 = call rename v0 ""  ; Δ{m v0} · makes Rec
  let _t11 = call recLen _t10  ; Δ{_t10 m v0}
  let _t12 = call rename v0 "x"  ; Δ{m v0} · makes Rec
  let _t13 = call rename _t12 "yz"  ; Δ{_t12 m v0} · makes Rec
  let _t14 = call recLen _t13  ; Δ{_t13 m v0}
  let _t15 = + _t11 _t14  ; Δ{m v0}
  let _t16 = call recLen v0  ; Δ{m v0}
  let _t17 = + _t15 _t16  ; Δ{m}
  let _t18 = call renameFirst m  ; Δ{m} · makes Rec
  let _t19 = call recLen _t18  ; Δ{_t18}
  let _t2 = con Nil  ; Δ{_t0 _t1} · makes List$String
  let _t2 = field items r  ; Δ{}
  let _t3 = call length _t2  ; Δ{}
  let _t3 = con Cons _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t1 _t2} · makes List$String
  let _t4 = + _t1 _t3  ; Δ{}
  let _t4 = con Cons "s0" _t3  ; Δ{_t0 _t3} · moves{_t3} · makes List$String
  let _t5 = field note r  ; Δ{}
  let _t5 = showInt 4  ; Δ{_t0 _t4} · makes String
  let _t6 = rtcall axion_str_len _t5  ; Δ{}
  let _t6 = showInt 7  ; Δ{v0} · makes String
  let _t7 = con Nil  ; Δ{_t6 v0} · makes List$String
  let _t8 = con Cons _t6 _t7  ; Δ{_t6 _t7 v0} · moves{_t6 _t7} · makes List$String
  let _t9 = record Rec { name = "m" items = _t8 note = ""}  ; Δ{_t8 v0} · moves{_t8} · makes Rec
  let m = con Just _t9  ; Δ{_t9 v0} · moves{_t9} · makes Maybe$Rec
  let v0 = record Rec { name = _t0 items = _t4 note = _t5}  ; Δ{_t0 _t4 _t5} · moves{_t0 _t4 _t5} · makes Rec
  ret + _t17 _t19  ; Δ{}
  ret + _t4 _t6  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case m of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
  ret update r { name = n note = $updfield2c1 items = $updfield1c0}  ; Δ{$updfield1c0 $updfield2c1} · moves{$updfield1c0 $updfield2c1} · makes heap
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$Rec _p  =
axion_drop_Rec _p  =
length xs  =
main  =
recLen r  =
rename r n  =
renameFirst m  =
