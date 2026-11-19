


































            drop p : P
            let $clargcopy0 = call axion_copy_P p  ; Δ{} · makes P
            ret call goRun rest name p  ; Δ{} · makes P
            ret callclo f $clargcopy0  ; Δ{$clargcopy0} · moves{$clargcopy0}
          drop _t30 : P
          drop _t32 : String
          drop _t33 : P
          drop _t35 : String
          drop _t37 : String
          drop _t38 : String
          drop _t39 : String
          drop _t40 : String
          drop _t41 : String
          else
          let _d1000000 = putStrLn _t41  ; Δ{_t41}
          let _t0 = rtcall axion_str_cmp nm name  ; Δ{}
          let _t1 = == _t0 0  ; Δ{}
          let _t30 = call mk 9  ; Δ{} · makes P
          let _t31 = call condUpd _t30 7  ; Δ{_t30}
          let _t32 = showInt _t31  ; Δ{} · makes String
          let _t33 = call mk 2  ; Δ{_t32} · makes P
          let _t34 = call condUpd _t33 1  ; Δ{_t32 _t33}
          let _t35 = showInt _t34  ; Δ{_t32} · makes String
          let _t36 = call escapes 5  ; Δ{_t32 _t35}
          let _t37 = showInt _t36  ; Δ{_t32 _t35} · makes String
          let _t38 = rtcall axion_strcat " " _t37  ; Δ{_t32 _t35 _t37} · makes String
          let _t39 = rtcall axion_strcat _t35 _t38  ; Δ{_t32 _t35 _t38} · makes String
          let _t40 = rtcall axion_strcat " " _t39  ; Δ{_t32 _t39} · makes String
          let _t41 = rtcall axion_strcat _t32 _t40  ; Δ{_t32 _t40} · makes String
          ret _d1000000  ; Δ{}
          ret if _t1 then
        Act nm f ->
        _ ->
      drop _t16 : String
      drop _t18 : String
      drop _t20 : String
      drop _t22 : String
      drop _t23 : String
      drop _t24 : String
      drop _t25 : String
      drop _t26 : String
      drop _t27 : String
      drop _t28 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Act _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_Act _dd2  ; Δ{}
      let _t0 = call sumL r  ; Δ{}
      let _t15 = call chainA 3  ; Δ{}
      let _t16 = showInt _t15  ; Δ{} · makes String
      let _t17 = call chainB 2  ; Δ{_t16}
      let _t18 = showInt _t17  ; Δ{_t16} · makes String
      let _t19 = call chainC 4  ; Δ{_t16 _t18}
      let _t20 = showInt _t19  ; Δ{_t16 _t18} · makes String
      let _t21 = call chainD 5  ; Δ{_t16 _t18 _t20}
      let _t22 = showInt _t21  ; Δ{_t16 _t18 _t20} · makes String
      let _t23 = rtcall axion_strcat " " _t22  ; Δ{_t16 _t18 _t20 _t22} · makes String
      let _t24 = rtcall axion_strcat _t20 _t23  ; Δ{_t16 _t18 _t20 _t23} · makes String
      let _t25 = rtcall axion_strcat " " _t24  ; Δ{_t16 _t18 _t24} · makes String
      let _t26 = rtcall axion_strcat _t18 _t25  ; Δ{_t16 _t18 _t25} · makes String
      let _t27 = rtcall axion_strcat " " _t26  ; Δ{_t16 _t26} · makes String
      let _t28 = rtcall axion_strcat _t16 _t27  ; Δ{_t16 _t27} · makes String
      let _t29 = putStrLn _t28  ; Δ{_t28}
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t29 of
      ret case a of
      ret p  ; Δ{}
    Cons a rest ->
    Cons y r ->
    Nil ->
    Nil ->
    _ ->
    drop _t5 : P
    drop p : P
    drop p : P
    drop p : P
    drop v : String
    else
    else
    else
    let $updfield1 = field s p  ; Δ{}
    let $updfield1 = field xs p0  ; Δ{}
    let $updfield1c0 = call axion_copy_List$Int $updfield1  ; Δ{} · makes List$Int
    let $updfield1c0 = rtcall axion_strcat $updfield1 ""  ; Δ{} · makes String
    let $updfield2 = field t p0  ; Δ{$updfield1c0}
    let $updfield2 = field xs p  ; Δ{$updfield1c0}
    let $updfield2c1 = call axion_copy_List$Int $updfield2  ; Δ{$updfield1c0} · makes List$Int
    let $updfield2c1 = rtcall axion_strcat $updfield2 ""  ; Δ{$updfield1c0} · makes String
    let $updfield3 = field t p  ; Δ{$updfield1c0 $updfield2c1}
    let $updfield3 = field xs p  ; Δ{_t3}
    let $updfield3c0 = call axion_copy_List$Int $updfield3  ; Δ{_t3} · makes List$Int
    let $updfield3c2 = rtcall axion_strcat $updfield3 ""  ; Δ{$updfield1c0 $updfield2c1} · makes String
    let $updfield4 = field t p  ; Δ{$updfield3c0 _t3}
    let $updfield4c1 = rtcall axion_strcat $updfield4 ""  ; Δ{$updfield3c0 _t3} · makes String
    let _d1000000 = call m _t5  ; Δ{_t5}
    let _d1000000 = v  ; Δ{_t0}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _rcl2000000 = update p { n = 0 t = $updfield3c2 xs = $updfield2c1 s = $updfield1c0}  ; Δ{$updfield1c0 $updfield2c1 $updfield3c2} · moves{$updfield1c0 $updfield2c1 $updfield3c2} · makes heap
    let _rcl2000002 = call m p  ; Δ{}
    let _t3 = rtcall axion_strcat "x" "y"  ; Δ{} · makes String
    let _t4 = update p { s = _t3 t = $updfield4c1 xs = $updfield3c0}  ; Δ{$updfield3c0 $updfield4c1 _t3} · moves{$updfield3c0 $updfield4c1 _t3} · makes heap
    let _t5 = call bumpIf _t4  ; Δ{_t4} · moves{_t4} · makes P
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret _d1000000  ; Δ{_t0}
    ret _d1000000  ; Δ{}
    ret _rcl2000000  ; Δ{_rcl2000000} · moves{_rcl2000000}
    ret _rcl2000002  ; Δ{}
    ret call axion_copy_P p0  ; Δ{} · makes P
    ret p  ; Δ{}
    ret rtcall axion_strcat "" ""  ; Δ{_t0} · makes String
    ret update p0 { s = "w" t = $updfield2c1 xs = $updfield1c0}  ; Δ{$updfield1c0 $updfield2c1} · moves{$updfield1c0 $updfield2c1} · makes heap
  ; Δ{_t0}
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
  drop _t0 : List$Act
  drop _t0 : P skip{1}
  drop _t0 : P skip{1}
  drop _t0 : String
  drop _t1 : P
  drop _t10 : String
  drop _t11 : String
  drop _t12 : String
  drop _t13 : String
  drop _t2 : String
  drop _t3 : String
  drop _t4 : P
  drop _t4 : P skip{2}
  drop _t5 : P
  drop _t6 : String
  drop _t7 : P
  drop _t9 : String
  drop b0 : P
  drop b0 : P skip{1}
  drop b0 : P skip{2 3}
  drop b0 : P skip{3}
  drop b1 : P
  drop b1 : P skip{1 2 3}
  drop b1 : P skip{1 3}
  drop b1 : P skip{1}
  drop b2 : P
  drop b2 : P
  drop b2 : P
  drop b2 : P skip{2 3}
  drop p : P skip{0 1 2 3}
  else
  else
  else
  else
  else
  else
  else
  let $updfield1 = field xs p  ; Δ{_t1}
  let $updfield1c0 = call axion_copy_List$Int $updfield1  ; Δ{_t1} · makes List$Int
  let $updfield2 = field t p  ; Δ{$updfield1c0 _t1}
  let $updfield2c1 = rtcall axion_strcat $updfield2 ""  ; Δ{$updfield1c0 _t1} · makes String
  let _d1000000 = call goRun _t0 name p  ; Δ{_t0} · makes P
  let _d1000000 = call m _t5  ; Δ{_t0 _t4 _t5}
  let _d1000000 = update p { xs = _t1}  ; Δ{_t1} · moves{_t1} · makes heap
  let _dd0 = loadraw _p+16  ; Δ{}
  let _dd0 = loadraw _p+16  ; Δ{}
  let _dd0 = loadraw _p+16  ; Δ{}
  let _dd0 = loadraw _p+16  ; Δ{}
  let _dd0 = loadraw _p+24  ; Δ{}
  let _dd0 = loadraw _p+24  ; Δ{}
  let _dd0 = loadraw _p+24  ; Δ{}
  let _dd0 = loadraw _p+24  ; Δ{}
  let _dd0 = loadraw _p+24  ; Δ{}
  let _dd0 = loadraw _p+24  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = rtcall axion_closure_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd2 = loadraw _p+16  ; Δ{}
  let _dd2 = loadraw _p+16  ; Δ{}
  let _dd2 = loadraw _p+16  ; Δ{}
  let _dd2 = loadraw _p+8  ; Δ{}
  let _dd2 = loadraw _p+8  ; Δ{}
  let _dd2 = loadraw _p+8  ; Δ{}
  let _dd2 = loadraw _p+8  ; Δ{}
  let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
  let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
  let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = loadraw _p+8  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = rtcall axion_str_drop _dd4  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _rcl2000001 = rtcall axion_str_len _t2  ; Δ{_t0}
  let _t0 = > k 5  ; Δ{}
  let _t0 = call acts  ; Δ{} · makes List$Act
  let _t0 = call mk 2  ; Δ{} · makes P
  let _t0 = call mk k  ; Δ{} · makes P
  let _t0 = call setS p0  ; Δ{} · makes P
  let _t0 = closure lam$0 owning  ; Δ{} · makes Closure
  let _t0 = con Nil  ; Δ{b0 b1} · makes List$Int
  let _t0 = con Nil  ; Δ{b0} · makes List$Int
  let _t0 = con Nil  ; Δ{b0} · makes List$Int
  let _t0 = con Nil  ; Δ{b0} · makes List$Int
  let _t0 = field n p  ; Δ{}
  let _t0 = field n p  ; Δ{}
  let _t0 = field s p  ; Δ{}
  let _t0 = field xs p  ; Δ{}
  let _t0 = showInt k  ; Δ{} · makes String
  let _t1 = > _t0 3  ; Δ{}
  let _t1 = > k 0  ; Δ{_t0}
  let _t1 = call m b0  ; Δ{b0 b1 b2}
  let _t1 = call run "d" _t0  ; Δ{_t0} · moves{_t0} · makes P
  let _t1 = con Act "d" _t0  ; Δ{_t0} · moves{_t0} · makes Act
  let _t1 = con Cons 0 _t0  ; Δ{_t0 b0} · moves{_t0} · makes List$Int
  let _t1 = con Cons 1 _t0  ; Δ{_t0 b0} · moves{_t0} · makes List$Int
  let _t1 = con Cons 2 _t0  ; Δ{_t0 b0 b1} · moves{_t0} · makes List$Int
  let _t1 = con Cons 5 _t0  ; Δ{} · makes List$Int
  let _t1 = con Nil  ; Δ{_t0} · makes List$Int
  let _t1 = field n p  ; Δ{}
  let _t1 = field s p  ; Δ{}
  let _t1 = rtcall axion_strcat "s" _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "z" _t0  ; Δ{} · makes String
  let _t10 = rtcall axion_strcat " " _t9  ; Δ{_t3 _t6 _t9} · makes String
  let _t11 = rtcall axion_strcat _t6 _t10  ; Δ{_t10 _t3 _t6} · makes String
  let _t12 = rtcall axion_strcat " " _t11  ; Δ{_t11 _t3} · makes String
  let _t13 = rtcall axion_strcat _t3 _t12  ; Δ{_t12 _t3} · makes String
  let _t14 = putStrLn _t13  ; Δ{_t13}
  let _t2 = + k 1  ; Δ{_t1}
  let _t2 = > _t1 6  ; Δ{}
  let _t2 = call m _t1  ; Δ{_t1}
  let _t2 = con Cons 1 _t1  ; Δ{_t1 b0 b1} · moves{_t1} · makes List$Int
  let _t2 = con Cons 2 _t1  ; Δ{_t0 _t1} · moves{_t1} · makes List$Int
  let _t2 = con Nil  ; Δ{_t1} · makes List$Act
  let _t2 = con Nil  ; Δ{b0 b1} · makes List$Int
  let _t2 = field xs b2  ; Δ{b0 b1 b2}
  let _t2 = field xs b2  ; Δ{b1 b2}
  let _t2 = if _t1 then
  let _t2 = rtcall axion_str_len _t1  ; Δ{}
  let _t3 = + _t0 _t2  ; Δ{}
  let _t3 = call sumL _t2  ; Δ{b0 b1 b2}
  let _t3 = call sumL _t2  ; Δ{b1 b2}
  let _t3 = con Cons 1 _t2  ; Δ{_t0 _t2} · moves{_t2} · makes List$Int
  let _t3 = con Nil  ; Δ{_t1} · makes List$Int
  let _t3 = field s b1  ; Δ{b0 b1 b2}
  let _t3 = field s b1  ; Δ{b0 b1 b2}
  let _t3 = showInt _t2  ; Δ{} · makes String
  let _t4 = call m b1  ; Δ{b0 b1 b2}
  let _t4 = call mk 3  ; Δ{_t3} · makes P
  let _t4 = con Cons _t2 _t3  ; Δ{_t1 _t3} · moves{_t3} · makes List$Int
  let _t4 = field xs p  ; Δ{}
  let _t4 = rtcall axion_str_len _t3  ; Δ{b0 b1 b2}
  let _t4 = rtcall axion_str_len _t3  ; Δ{b0 b1 b2}
  let _t4 = update _t0 { t = "t2" xs = _t3}  ; Δ{_t0 _t3} · moves{_t3} · makes heap
  let _t5 = call keepS _t4 1  ; Δ{_t3 _t4}
  let _t5 = call m b0  ; Δ{b0 b1 b2}
  let _t5 = call m b1  ; Δ{b0 b1 b2}
  let _t5 = call sumL _t4  ; Δ{}
  let _t5 = con Cons k _t4  ; Δ{_t1 _t4} · moves{_t4} · makes List$Int
  let _t5 = update _t4 { s = "w" t = ""}  ; Δ{_t0 _t4} · makes heap
  let _t6 = + _t3 _t5  ; Δ{}
  let _t6 = + _t4 _t5  ; Δ{b0 b1 b2}
  let _t6 = + _t4 _t5  ; Δ{b0 b1 b2}
  let _t6 = showInt _t5  ; Δ{_t3} · makes String
  let _t7 = call mk 3  ; Δ{_t3 _t6} · makes P
  let _t7 = field t p  ; Δ{}
  let _t7 = field xs b2  ; Δ{b0 b1 b2}
  let _t7 = field xs b2  ; Δ{b0 b1 b2}
  let _t8 = call keepS _t7 0  ; Δ{_t3 _t6 _t7}
  let _t8 = call sumL _t7  ; Δ{b0 b1 b2}
  let _t8 = call sumL _t7  ; Δ{b0 b1 b2}
  let _t8 = rtcall axion_str_len _t7  ; Δ{}
  let _t9 = showInt _t8  ; Δ{_t3 _t6} · makes String
  let b0 = call mk k  ; Δ{} · makes P
  let b0 = call mk k  ; Δ{} · makes P
  let b0 = call mk k  ; Δ{} · makes P
  let b0 = call mk k  ; Δ{} · makes P
  let b1 = update b0 { s = "w" n = 4}  ; Δ{b0} · makes heap
  let b1 = update b0 { s = "w" xs = _t0}  ; Δ{_t0 b0} · moves{_t0} · makes heap
  let b1 = update b0 { xs = _t1 t = ""}  ; Δ{_t1 b0} · moves{_t1} · makes heap
  let b1 = update b0 { xs = _t1}  ; Δ{_t1 b0} · moves{_t1} · makes heap
  let b2 = update b1 { s = "w"}  ; Δ{b0 b1} · makes heap
  let b2 = update b1 { t = "t2" xs = _t2}  ; Δ{_t2 b0 b1} · moves{_t2} · makes heap
  let b2 = update b1 { t = "t2"}  ; Δ{b0 b1} · makes heap
  let b2 = update b1 { xs = _t2 s = "w"}  ; Δ{_t2 b0 b1} · moves{_t2} · makes heap
  let p = if _t0 then
  let v = field s _t0  ; Δ{_t0}
  ret + _t1 _t3  ; Δ{b1}
  ret + _t3 _t4  ; Δ{b0 b2}
  ret + _t6 _t8  ; Δ{b0 b1}
  ret + _t6 _t8  ; Δ{b0 b1}
  ret + _t6 _t8  ; Δ{}
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
  ret _d1000000  ; Δ{_d1000000 p} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_t0 _t4}
  ret _rcl2000001  ; Δ{_t0}
  ret case _t14 of
  ret case as2 of
  ret case l of
  ret con Cons _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes List$Act
  ret if _t1 then
  ret if _t2 then
  ret record P { n = k s = _t1 xs = _t5 t = "t"}  ; Δ{_t1 _t5} · moves{_t1 _t5} · makes P
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret update p { s = _t1 t = $updfield2c1 xs = $updfield1c0}  ; Δ{$updfield1c0 $updfield2c1 _t1} · moves{$updfield1c0 $updfield2c1 _t1} · makes heap
acts  =
axion_drop_Act _p  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Act _p  =
axion_drop_List$Int _p  =
axion_drop_P _p  =
axion_drop_P_skip_0_1 _p  =
axion_drop_P_skip_0_1_2 _p  =
axion_drop_P_skip_0_1_3 _p  =
axion_drop_P_skip_0_2 _p  =
axion_drop_P_skip_0_2_3 _p  =
axion_drop_P_skip_0_3 _p  =
axion_drop_P_skip_1 _p  =
axion_drop_P_skip_1_3 _p  =
axion_drop_P_skip_2 _p  =
axion_drop_P_skip_2_3 _p  =
axion_drop_P_skip_3 _p  =
axion_drop_clo$lam$0 _p  =
bumpIf p  =
chainA k  =
chainB k  =
chainC k  =
chainD k  =
condUpd p0 k  =
escapes k  =
goRun as2 name p  =
keepS p0 k  =
lam$0 [env ]p  =
m p  =
main  =
mk k  =
run name p  =
setS p  =
sumL l  =
