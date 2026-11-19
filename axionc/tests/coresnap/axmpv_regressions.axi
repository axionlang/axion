
























                      drop _t47 : List$Act
                      drop _t49 : P
                      drop _t50 : String
                      drop _t51 : P
                      drop _t53 : String
                      drop _t54 : P
                      drop _t56 : String
                      drop _t57 : String
                      drop _t58 : String
                      drop _t59 : String
                      drop _t60 : String
                      let _d1000000 = putStrLn _t60  ; Δ{_t60}
                      let _t47 = call acts2  ; Δ{} · makes List$Act
                      let _t48 = record P { v = 5 w = 7 s = "kept"}  ; Δ{_t47} · makes P
                      let _t49 = call go _t47 "zero" _t48  ; Δ{_t47 _t48} · moves{_t48} · makes P
                      let _t50 = call showP _t49  ; Δ{_t49} · makes String
                      let _t51 = record P { v = 1 w = 3 s = "x"}  ; Δ{_t50} · makes P
                      let _t52 = call pick _t51 1  ; Δ{_t50 _t51}
                      let _t53 = showInt _t52  ; Δ{_t50} · makes String
                      let _t54 = record P { v = 1 w = 3 s = "x"}  ; Δ{_t50 _t53} · makes P
                      let _t55 = call pick _t54 0  ; Δ{_t50 _t53 _t54}
                      let _t56 = showInt _t55  ; Δ{_t50 _t53} · makes String
                      let _t57 = rtcall axion_strcat " " _t56  ; Δ{_t50 _t53 _t56} · makes String
                      let _t58 = rtcall axion_strcat _t53 _t57  ; Δ{_t50 _t53 _t57} · makes String
                      let _t59 = rtcall axion_strcat " " _t58  ; Δ{_t50 _t58} · makes String
                      let _t60 = rtcall axion_strcat _t50 _t59  ; Δ{_t50 _t59} · makes String
                      ret _d1000000  ; Δ{}
                    _ ->
                  drop _t38 : P
                  drop _t40 : String
                  drop _t41 : P
                  drop _t43 : String
                  drop _t44 : String
                  drop _t45 : String
                  let _t38 = record P { v = 1 w = 2 s = "q"}  ; Δ{} · makes P
                  let _t39 = call bump _t38 0  ; Δ{_t38}
                  let _t40 = showInt _t39  ; Δ{} · makes String
                  let _t41 = record P { v = 1 w = 2 s = "q"}  ; Δ{_t40} · makes P
                  let _t42 = call bump _t41 1  ; Δ{_t40 _t41}
                  let _t43 = showInt _t42  ; Δ{_t40} · makes String
                  let _t44 = rtcall axion_strcat " " _t43  ; Δ{_t40 _t43} · makes String
                  let _t45 = rtcall axion_strcat _t40 _t44  ; Δ{_t40 _t44} · makes String
                  let _t46 = putStrLn _t45  ; Δ{_t45}
                  ret case _t46 of
                _ ->
              drop _t30 : P
              drop _t31 : String
              drop _t33 : P
              drop _t34 : String
              drop _t35 : String
              drop _t36 : String
              let _t29 = record P { v = 1 w = 2 s = "y"}  ; Δ{} · makes P
              let _t30 = call check _t29  ; Δ{_t29} · moves{_t29} · makes P
              let _t31 = call showP _t30  ; Δ{_t30} · makes String
              let _t32 = record P { v = 9 w = 2 s = "z"}  ; Δ{_t31} · makes P
              let _t33 = call check _t32  ; Δ{_t31 _t32} · moves{_t32} · makes P
              let _t34 = call showP _t33  ; Δ{_t31 _t33} · makes String
              let _t35 = rtcall axion_strcat " " _t34  ; Δ{_t31 _t34} · makes String
              let _t36 = rtcall axion_strcat _t31 _t35  ; Δ{_t31 _t35} · makes String
              let _t37 = putStrLn _t36  ; Δ{_t36}
              ret case _t37 of
            _ ->
            drop p : P
            let $clargcopy0 = call axion_copy_P p  ; Δ{} · makes P
            ret call go rest name p  ; Δ{} · makes P
            ret callclo f $clargcopy0  ; Δ{$clargcopy0} · moves{$clargcopy0}
          drop _t25 : String
          drop _t26 : String
          drop _t27 : String
          else
          let _t0 = rtcall axion_str_cmp n name  ; Δ{}
          let _t1 = == _t0 0  ; Δ{}
          let _t25 = call optionOr "abcdef" "x" "d"  ; Δ{} · makes String
          let _t26 = call optionOr "" "x" "d"  ; Δ{_t25} · makes String
          let _t27 = rtcall axion_strcat _t25 _t26  ; Δ{_t25 _t26} · makes String
          let _t28 = putStrLn _t27  ; Δ{_t27}
          ret case _t28 of
          ret if _t1 then
        Act n f ->
        _ ->
      drop _t15 : P
      drop _t16 : String
      drop _t17 : String
      drop _t18 : P
      drop _t19 : String
      drop _t20 : String
      drop _t21 : String
      drop _t22 : String
      drop _t23 : String
      drop p : P
      drop q : P
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Act _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_Act _dd2  ; Δ{}
      let _t15 = call run "dbl" p  ; Δ{p q} · makes P
      let _t16 = call showP _t15  ; Δ{_t15 p q} · makes String
      let _t17 = call showP q  ; Δ{_t16 p q} · makes String
      let _t18 = call run "none" p  ; Δ{_t16 _t17 p} · makes P
      let _t19 = call showP _t18  ; Δ{_t16 _t17 _t18} · makes String
      let _t20 = rtcall axion_strcat " " _t19  ; Δ{_t16 _t17 _t19} · makes String
      let _t21 = rtcall axion_strcat _t17 _t20  ; Δ{_t16 _t17 _t20} · makes String
      let _t22 = rtcall axion_strcat " " _t21  ; Δ{_t16 _t21} · makes String
      let _t23 = rtcall axion_strcat _t16 _t22  ; Δ{_t16 _t22} · makes String
      let _t24 = putStrLn _t23  ; Δ{_t23}
      let p = record P { v = 1 w = 3 s = "x"}  ; Δ{} · makes P
      let q = call run "inc" p  ; Δ{p} · makes P
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t24 of
      ret case a of
      ret p  ; Δ{}
    Cons a rest ->
    Nil ->
    _ ->
    drop _t1 : P
    drop p : P
    drop p1 : P skip{0 1}
    drop p1 : P skip{0 1}
    drop v : String
    else
    else
    let $updfield1 = field s p  ; Δ{}
    let $updfield1 = field s p0  ; Δ{}
    let $updfield1c0 = rtcall axion_strcat $updfield1 ""  ; Δ{} · makes String
    let $updfield1c0 = rtcall axion_strcat $updfield1 ""  ; Δ{} · makes String
    let _d1000000 = field v _t1  ; Δ{_t1 p1}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _rcl2000000 = update p { v = 7 s = $updfield1c0}  ; Δ{$updfield1c0} · moves{$updfield1c0} · makes heap
    let _t1 = call run "inc" p1  ; Δ{p1} · makes P
    let _t2 = field v p  ; Δ{}
    let _t2 = field w p1  ; Δ{p1}
    let _t3 = field s p1  ; Δ{p1}
    let _t3 = rtcall axion_str_len dflt  ; Δ{v}
    let _t4 = rtcall axion_str_len _t3  ; Δ{p1}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret ""  ; Δ{}
    ret + _t2 _t4  ; Δ{p1}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret < _t2 5  ; Δ{}
    ret _d1000000  ; Δ{p1}
    ret _rcl2000000  ; Δ{_rcl2000000} · moves{_rcl2000000}
    ret call axion_copy_P p0  ; Δ{} · makes P
    ret p  ; Δ{}
    ret rtcall axion_substr 0 1 km  ; Δ{} · makes String
    ret rtcall axion_substr 0 _t3 dflt  ; Δ{} · makes String
    ret update p0 { v = 9 s = $updfield1c0}  ; Δ{$updfield1c0} · moves{$updfield1c0} · makes heap
    ret v  ; Δ{v} · moves{v}
  ; Δ{p1}
  ; Δ{v}
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
  drop _t0 : List$Act
  drop _t0 : P
  drop _t0 : String
  drop _t0 : String
  drop _t1 : String
  drop _t1 : String
  drop _t10 : String
  drop _t11 : String
  drop _t12 : String
  drop _t13 : String
  drop _t2 : String
  drop _t3 : String
  drop _t3 : String
  drop _t4 : String
  drop _t4 : String
  drop _t5 : String
  drop _t5 : String
  drop _t6 : String
  drop _t6 : String
  drop _t7 : String
  drop _t7 : String
  drop _t7 : String
  drop _t8 : String
  drop _t8 : String
  drop _t9 : String
  drop p : P skip{2}
  drop p : P skip{2}
  drop p : P skip{2}
  drop p : P skip{2}
  else
  else
  else
  else
  else
  else
  else
  else
  let $aliascopy0 = call axion_copy_P p  ; Δ{_t0} · makes P
  let $updfield1 = field s p  ; Δ{}
  let $updfield1c0 = rtcall axion_strcat $updfield1 ""  ; Δ{} · makes String
  let _d1000000 = call go _t0 name $aliascopy0  ; Δ{$aliascopy0 _t0} · moves{$aliascopy0} · makes P
  let _d1000000 = call tag _t0  ; Δ{_t0 p} · makes P
  let _d1000000 = rtcall axion_strcat _t1 _t7  ; Δ{_t1 _t7} · makes String
  let _d1000000 = rtcall axion_strcat _t1 _t8  ; Δ{_t1 _t8} · makes String
  let _d1000000 = update p { v = _t1}  ; Δ{} · makes heap
  let _d1000000 = update p { w = _t1}  ; Δ{} · makes heap
  let _dd0 = loadraw _p+16  ; Δ{}
  let _dd0 = loadraw _p+16  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = rtcall axion_closure_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = == k 0  ; Δ{}
  let _t0 = > k 0  ; Δ{p1}
  let _t0 = call acts  ; Δ{} · makes List$Act
  let _t0 = call divmod 7 3  ; Δ{} · makes String
  let _t0 = closure lam$0 owning  ; Δ{} · makes Closure
  let _t0 = closure lam$2 owning  ; Δ{} · makes Closure
  let _t0 = div a b  ; Δ{}
  let _t0 = field v p  ; Δ{}
  let _t0 = field v p  ; Δ{}
  let _t0 = field w p  ; Δ{}
  let _t0 = field w p  ; Δ{}
  let _t0 = rtcall axion_str_len km  ; Δ{}
  let _t0 = rtcall axion_strcat "=" name  ; Δ{} · makes String
  let _t0 = update p { v = 0}  ; Δ{} · makes heap
  let _t1 = * _t0 2  ; Δ{}
  let _t1 = + _t0 1  ; Δ{}
  let _t1 = - 0 7  ; Δ{_t0}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = con Act "inc" _t0  ; Δ{_t0} · moves{_t0} · makes Act
  let _t1 = con Act "zero" _t0  ; Δ{_t0} · moves{_t0} · makes Act
  let _t1 = field v p  ; Δ{}
  let _t1 = rtcall axion_str_len k  ; Δ{}
  let _t1 = rtcall axion_str_len v  ; Δ{v}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t10 = rtcall axion_strcat " " _t9  ; Δ{_t0 _t2 _t9} · makes String
  let _t11 = rtcall axion_strcat _t2 _t10  ; Δ{_t0 _t10 _t2} · makes String
  let _t12 = rtcall axion_strcat " " _t11  ; Δ{_t0 _t11} · makes String
  let _t13 = rtcall axion_strcat _t0 _t12  ; Δ{_t0 _t12} · makes String
  let _t14 = putStrLn _t13  ; Δ{_t13}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = > _t1 0  ; Δ{v}
  let _t2 = call divmod _t1 3  ; Δ{_t0} · makes String
  let _t2 = closure lam$1 owning  ; Δ{_t1} · makes Closure
  let _t2 = con Nil  ; Δ{_t1} · makes List$Act
  let _t2 = field w p  ; Δ{_t1}
  let _t2 = field w p  ; Δ{}
  let _t2 = mod a b  ; Δ{_t1}
  let _t3 = + _t1 _t2  ; Δ{}
  let _t3 = - 0 3  ; Δ{_t0 _t2}
  let _t3 = con Act "dbl" _t2  ; Δ{_t1 _t2} · moves{_t2} · makes Act
  let _t3 = if _t1 then
  let _t3 = showInt _t2  ; Δ{_t1} · makes String
  let _t3 = showInt _t2  ; Δ{_t1} · makes String
  let _t4 = call divmod 7 _t3  ; Δ{_t0 _t2} · makes String
  let _t4 = con Nil  ; Δ{_t1 _t3} · makes List$Act
  let _t4 = field s p  ; Δ{_t1 _t3}
  let _t4 = field s p  ; Δ{}
  let _t4 = mod a b  ; Δ{_t1 _t3}
  let _t5 = - 0 7  ; Δ{_t0 _t2 _t4}
  let _t5 = con Cons _t3 _t4  ; Δ{_t1 _t3 _t4} · moves{_t3 _t4} · makes List$Act
  let _t5 = rtcall axion_str_len _t4  ; Δ{}
  let _t5 = rtcall axion_strcat "/" _t4  ; Δ{_t1 _t3} · makes String
  let _t5 = showInt _t4  ; Δ{_t1 _t3} · makes String
  let _t6 = - 0 3  ; Δ{_t0 _t2 _t4}
  let _t6 = rtcall axion_strcat "," _t5  ; Δ{_t1 _t3 _t5} · makes String
  let _t6 = rtcall axion_strcat _t3 _t5  ; Δ{_t1 _t3 _t5} · makes String
  let _t7 = call divmod _t5 _t6  ; Δ{_t0 _t2 _t4} · makes String
  let _t7 = rtcall axion_strcat "/" _t6  ; Δ{_t1 _t6} · makes String
  let _t7 = rtcall axion_strcat _t3 _t6  ; Δ{_t1 _t3 _t6} · makes String
  let _t8 = rtcall axion_strcat " " _t7  ; Δ{_t0 _t2 _t4 _t7} · makes String
  let _t8 = rtcall axion_strcat "," _t7  ; Δ{_t1 _t7} · makes String
  let _t9 = rtcall axion_strcat _t4 _t8  ; Δ{_t0 _t2 _t4 _t8} · makes String
  let p = if _t0 then
  let p1 = update p { s = "new"}  ; Δ{} · makes heap
  let v = call look km _t0  ; Δ{_t0} · makes String
  ret + _t3 _t5  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000 p} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000 p} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000 p} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret case _t14 of
  ret case xs of
  ret con Cons _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes List$Act
  ret con Cons _t1 _t5  ; Δ{_t1 _t5} · moves{_t1 _t5} · makes List$Act
  ret if _t0 then
  ret if _t2 then
  ret if _t2 then
  ret if _t3 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret update p { w = 1 s = $updfield1c0}  ; Δ{$updfield1c0} · moves{$updfield1c0} · makes heap
acts  =
acts2  =
axion_drop_Act _p  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Act _p  =
axion_drop_P _p  =
axion_drop_P_skip_0_1 _p  =
axion_drop_clo$lam$0 _p  =
axion_drop_clo$lam$1 _p  =
axion_drop_clo$lam$2 _p  =
bump p0 k  =
check p  =
divmod a b  =
go xs name p  =
lam$0 [env ]p  =
lam$1 [env ]p  =
lam$2 [env ]p  =
look km k  =
main  =
optionOr km name dflt  =
pick p k  =
run name p  =
showP p  =
tag p  =
