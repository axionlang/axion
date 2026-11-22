























                                      drop _t73 : List$Int
                                      drop _t74 : List$Int
                                      drop _t76 : String
                                      let _d1000000 = putStrLn _t76  ; Δ{_t76}
                                      let _t70 = con Nil  ; Δ{} · makes List$Int
                                      let _t71 = con Cons 3 _t70  ; Δ{_t70} · moves{_t70} · makes List$Int
                                      let _t72 = con Cons 2 _t71  ; Δ{_t71} · moves{_t71} · makes List$Int
                                      let _t73 = con Cons 1 _t72  ; Δ{_t72} · moves{_t72} · makes List$Int
                                      let _t74 = call map$$hoflamcap0 k _t73  ; Δ{_t73} · makes List$Int
                                      let _t75 = call sumL _t74  ; Δ{_t74}
                                      let _t76 = showInt _t75  ; Δ{} · makes String
                                      ret _d1000000  ; Δ{}
                                    _ ->
                                  drop _t64
                                  drop _t66 : Array
                                  drop _t68 : String
                                  drop w : Array
                                  let _t63 = newArray 8 0  ; Δ{w} · makes Array
                                  let _t64 = closure lam$2 w  ; Δ{_t63 w} · makes Closure
                                  let _t65 = rtcall axion_par_for _t63 _t64  ; Δ{_t63 _t64 w}
                                  let _t66 = _t63  ; Δ{_t63} · moves{_t63}
                                  let _t67 = call sumA _t66 0 0  ; Δ{}
                                  let _t68 = showInt _t67  ; Δ{} · makes String
                                  let _t69 = putStrLn _t68  ; Δ{_t68}
                                  let w = rtcall axion_array_iota 8  ; Δ{} · makes Array
                                  ret case _t69 of
                                _ ->
                              drop _t61 : String
                              let _t60 = call third 30  ; Δ{}
                              let _t61 = showInt _t60  ; Δ{} · makes String
                              let _t62 = putStrLn _t61  ; Δ{_t61}
                              ret case _t62 of
                            _ ->
                          drop _t56
                          drop _t58 : String
                          let _t56 = closure lam$1  ; Δ{} · makes Closure
                          let _t57 = callclo _t56 0  ; Δ{_t56}
                          let _t58 = showInt _t57  ; Δ{} · makes String
                          let _t59 = putStrLn _t58  ; Δ{_t58}
                          ret case _t59 of
                        _ ->
                      drop _t51 : List$Int
                      drop _t52 : List$Int
                      drop _t54 : String
                      let _t48 = con Nil  ; Δ{} · makes List$Int
                      let _t49 = con Cons 3 _t48  ; Δ{_t48} · moves{_t48} · makes List$Int
                      let _t50 = con Cons 2 _t49  ; Δ{_t49} · moves{_t49} · makes List$Int
                      let _t51 = con Cons 1 _t50  ; Δ{_t50} · moves{_t50} · makes List$Int
                      let _t52 = call map$$hoflam10 _t51  ; Δ{_t51} · makes List$Int
                      let _t53 = call sumL _t52  ; Δ{_t52}
                      let _t54 = showInt _t53  ; Δ{} · makes String
                      let _t55 = putStrLn _t54  ; Δ{_t54}
                      ret case _t55 of
                    _ ->
                    drop _t38 : String
                    drop _t39 : String
                    drop _t40 : String
                    drop _t41 : String
                    drop _t42 : String
                    drop _t43 : String
                    drop _t44 : String
                    let _d1000001 = rtcall axion_contract_fail _t44  ; Δ{_t44}
                    let _t38 = rtcall axion_strcat "axion: contract violated: `withdraw` requires `0 <= amount && amount <= balance`" " (balance = "  ; Δ{} · makes String
                    let _t39 = showInt contract$a6  ; Δ{_t38} · makes String
                    let _t40 = rtcall axion_strcat _t38 _t39  ; Δ{_t38 _t39} · makes String
                    let _t41 = rtcall axion_strcat _t40 ", amount = "  ; Δ{_t40} · makes String
                    let _t42 = showInt k  ; Δ{_t41} · makes String
                    let _t43 = rtcall axion_strcat _t41 _t42  ; Δ{_t41 _t42} · makes String
                    let _t44 = rtcall axion_strcat _t43 "), called from `main`"  ; Δ{_t43} · makes String
                    ret 0  ; Δ{}
                    ret _d1000001  ; Δ{}
                    ret call <=$Int k contract$a6  ; Δ{}
                    ret call withdraw contract$a6 k  ; Δ{}
                  drop _t46 : String
                  else
                  else
                  let _t36 = call <=$Int 0 k  ; Δ{}
                  let _t37 = if _t36 then
                  let _t45 = if _t37 then
                  let _t46 = showInt _t45  ; Δ{} · makes String
                  let _t47 = putStrLn _t46  ; Δ{_t46}
                  let contract$a6 = 50  ; Δ{}
                  ret case _t47 of
                _ ->
                drop _t25 : String
                drop _t27 : String
                drop _t28 : String
                drop _t29 : String
                drop _t30 : String
                drop _t31 : String
                drop _t32 : String
                drop contract$a4 : Array
                drop contract$a4 : Array
                let _d1000002 = call at contract$a4 contract$a5  ; Δ{contract$a4}
                let _d1000003 = rtcall axion_contract_fail _t32  ; Δ{_t32}
                let _t23 = rtcall axion_array_len contract$a4  ; Δ{contract$a4}
                let _t25 = rtcall axion_strcat "axion: contract violated: `at` requires `0 <= i && i < (len a)`" " (len a = "  ; Δ{contract$a4} · makes String
                let _t26 = rtcall axion_array_len contract$a4  ; Δ{_t25 contract$a4}
                let _t27 = showInt _t26  ; Δ{_t25} · makes String
                let _t28 = rtcall axion_strcat _t25 _t27  ; Δ{_t25 _t27} · makes String
                let _t29 = rtcall axion_strcat _t28 ", i = "  ; Δ{_t28} · makes String
                let _t30 = showInt contract$a5  ; Δ{_t29} · makes String
                let _t31 = rtcall axion_strcat _t29 _t30  ; Δ{_t29 _t30} · makes String
                let _t32 = rtcall axion_strcat _t31 "), called from `main`"  ; Δ{_t31} · makes String
                ret 0  ; Δ{contract$a4}
                ret < contract$a5 _t23  ; Δ{contract$a4}
                ret _d1000002  ; Δ{}
                ret _d1000003  ; Δ{}
              drop _t34 : String
              else
              else
              let _t22 = call <=$Int 0 contract$a5  ; Δ{contract$a4}
              let _t24 = if _t22 then
              let _t33 = if _t24 then
              let _t34 = showInt _t33  ; Δ{} · makes String
              let _t35 = putStrLn _t34  ; Δ{_t34}
              let contract$a4 = rtcall axion_array_iota 20  ; Δ{} · makes Array
              let contract$a5 = + k 10  ; Δ{contract$a4}
              ret case _t35 of
            _ ->
            drop _t11 : String
            drop _t13 : String
            drop _t14 : String
            drop _t15 : String
            drop _t16 : String
            drop _t17 : String
            drop _t18 : String
            drop a : Array
            drop a : Array
            let _d1000004 = call at a k  ; Δ{a}
            let _d1000005 = rtcall axion_contract_fail _t18  ; Δ{_t18}
            let _t11 = rtcall axion_strcat "axion: contract violated: `at` requires `0 <= i && i < (len a)`" " (len a = "  ; Δ{a} · makes String
            let _t12 = rtcall axion_array_len a  ; Δ{_t11 a}
            let _t13 = showInt _t12  ; Δ{_t11} · makes String
            let _t14 = rtcall axion_strcat _t11 _t13  ; Δ{_t11 _t13} · makes String
            let _t15 = rtcall axion_strcat _t14 ", i = "  ; Δ{_t14} · makes String
            let _t16 = showInt k  ; Δ{_t15} · makes String
            let _t17 = rtcall axion_strcat _t15 _t16  ; Δ{_t15 _t16} · makes String
            let _t18 = rtcall axion_strcat _t17 "), called from `main`"  ; Δ{_t17} · makes String
            let _t9 = rtcall axion_array_len a  ; Δ{a}
            ret 0  ; Δ{a}
            ret < k _t9  ; Δ{a}
            ret _d1000004  ; Δ{}
            ret _d1000005  ; Δ{}
          drop _t20 : String
          else
          else
          let _t10 = if _t8 then
          let _t19 = if _t10 then
          let _t20 = showInt _t19  ; Δ{} · makes String
          let _t21 = putStrLn _t20  ; Δ{_t20}
          let _t8 = call <=$Int 0 k  ; Δ{a}
          let k = call digits "seven!!"  ; Δ{a}
          ret case _t21 of
        _ ->
      drop _t10 : String
      drop _t11 : String
      drop _t12 : String
      drop _t13 : String
      drop _t4 : String
      drop _t5 : String
      drop _t6 : String
      drop _t6 : String
      drop _t7 : String
      drop _t8 : String
      drop _t9 : String
      let _d1000000 = rtcall axion_contract_fail _t13  ; Δ{_t13}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call hoflam10 y  ; Δ{}
      let _t0 = call hoflamcap0 _cap0 y  ; Δ{}
      let _t0 = call sumL rest  ; Δ{}
      let _t1 = call map$$hoflam10 ys  ; Δ{} · makes List$Int
      let _t1 = call map$$hoflamcap0 _cap0 ys  ; Δ{} · makes List$Int
      let _t10 = rtcall axion_strcat _t9 ", result = "  ; Δ{_t9} · makes String
      let _t11 = showInt contract$r9  ; Δ{_t10} · makes String
      let _t12 = rtcall axion_strcat _t10 _t11  ; Δ{_t10 _t11} · makes String
      let _t13 = rtcall axion_strcat _t12 "), called from `main`"  ; Δ{_t12} · makes String
      let _t3 = call at a 3  ; Δ{a}
      let _t4 = call countdown 5  ; Δ{a}
      let _t4 = rtcall axion_strcat "axion: contract violated: `withdraw` ensures `0 <= result && result <= balance`" " (balance = "  ; Δ{} · makes String
      let _t5 = + _t3 _t4  ; Δ{a}
      let _t5 = showInt contract$a8  ; Δ{_t4} · makes String
      let _t6 = rtcall axion_strcat _t4 _t5  ; Δ{_t4 _t5} · makes String
      let _t6 = showInt _t5  ; Δ{a} · makes String
      let _t7 = putStrLn _t6  ; Δ{_t6 a}
      let _t7 = rtcall axion_strcat _t6 ", amount = "  ; Δ{_t6} · makes String
      let _t8 = showInt contract$p7  ; Δ{_t7} · makes String
      let _t9 = rtcall axion_strcat _t7 _t8  ; Δ{_t7 _t8} · makes String
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{}
      ret call <=$Int contract$r9 contract$a8  ; Δ{}
      ret case _t7 of
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret contract$r9  ; Δ{}
    Cons y rest ->
    Cons y ys ->
    Cons y ys ->
    Nil ->
    Nil ->
    Nil ->
    _ ->
    drop _t1
    drop _t1 : String
    drop _t1 : String
    drop _t1 : String
    drop _t14 : String
    drop _t15 : String
    drop _t16 : String
    drop _t17 : String
    drop _t18 : String
    drop _t19 : String
    drop _t2 : String
    drop _t2 : String
    drop _t2 : String
    drop _t20 : String
    drop _t3 : String
    drop _t3 : String
    drop _t3 : String
    drop _t4 : String
    drop _t4 : String
    drop _t4 : String
    drop _t5 : String
    drop _t5 : String
    drop _t6 : String
    drop _t6 : String
    drop _t7 : String
    drop _t7 : String
    else
    else
    else
    else
    let _d1000000 = callclo _t1 _t2  ; Δ{_t1}
    let _d1000000 = rtcall axion_contract_fail _t4  ; Δ{_t4}
    let _d1000000 = rtcall axion_contract_fail _t7  ; Δ{_t7}
    let _d1000000 = rtcall axion_contract_fail _t7  ; Δ{_t7}
    let _d1000001 = rtcall axion_contract_fail _t20  ; Δ{_t20}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = - n 1  ; Δ{}
    let _t1 = closure lam$0 contract$g1  ; Δ{} · makes Closure
    let _t1 = rtcall axion_strcat "axion: contract violated: `scale` requires `n >= 0`" " (n = "  ; Δ{} · makes String
    let _t1 = rtcall axion_strcat "axion: contract violated: `sumTo` ensures `result >= acc`" " (acc = "  ; Δ{} · makes String
    let _t1 = rtcall axion_strcat "axion: contract violated: `sumTo` ensures `result >= acc`" " (acc = "  ; Δ{} · makes String
    let _t14 = rtcall axion_strcat "axion: contract violated: `withdraw` requires `0 <= amount && amount <= balance`" " (balance = "  ; Δ{} · makes String
    let _t15 = showInt contract$a8  ; Δ{_t14} · makes String
    let _t16 = rtcall axion_strcat _t14 _t15  ; Δ{_t14 _t15} · makes String
    let _t17 = rtcall axion_strcat _t16 ", amount = "  ; Δ{_t16} · makes String
    let _t18 = showInt contract$p7  ; Δ{_t17} · makes String
    let _t19 = rtcall axion_strcat _t17 _t18  ; Δ{_t17 _t18} · makes String
    let _t2 = + acc n  ; Δ{_t1}
    let _t2 = + i 1  ; Δ{}
    let _t2 = call <=$Int 0 contract$r9  ; Δ{}
    let _t2 = showInt contract$p10  ; Δ{_t1} · makes String
    let _t2 = showInt contract$p2  ; Δ{_t1} · makes String
    let _t2 = showInt k  ; Δ{_t1} · makes String
    let _t20 = rtcall axion_strcat _t19 "), called from `main`"  ; Δ{_t19} · makes String
    let _t3 = if _t2 then
    let _t3 = rtcall axion_array_get a i  ; Δ{}
    let _t3 = rtcall axion_strcat _t1 _t2  ; Δ{_t1 _t2} · makes String
    let _t3 = rtcall axion_strcat _t1 _t2  ; Δ{_t1 _t2} · makes String
    let _t3 = rtcall axion_strcat _t1 _t2  ; Δ{_t1 _t2} · makes String
    let _t4 = + acc _t3  ; Δ{}
    let _t4 = rtcall axion_strcat _t3 "), called from `main`"  ; Δ{_t3} · makes String
    let _t4 = rtcall axion_strcat _t3 ", result = "  ; Δ{_t3} · makes String
    let _t4 = rtcall axion_strcat _t3 ", result = "  ; Δ{_t3} · makes String
    let _t5 = showInt contract$r11  ; Δ{_t4} · makes String
    let _t5 = showInt contract$r3  ; Δ{_t4} · makes String
    let _t6 = rtcall axion_strcat _t4 _t5  ; Δ{_t4 _t5} · makes String
    let _t6 = rtcall axion_strcat _t4 _t5  ; Δ{_t4 _t5} · makes String
    let _t7 = rtcall axion_strcat _t6 "), called from `main`"  ; Δ{_t6} · makes String
    let _t7 = rtcall axion_strcat _t6 "), called from `sumTo`"  ; Δ{_t6} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let contract$g1 = - n 1  ; Δ{}
    let contract$r13 = call scale k contract$p12  ; Δ{}
    let contract$r9 = call withdraw contract$a8 contract$p7  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _d1000001  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret call <=$Int contract$p7 contract$a8  ; Δ{}
    ret call countdown _t1  ; Δ{}
    ret call sumA a _t2 _t4  ; Δ{}
    ret contract$r11  ; Δ{}
    ret contract$r13  ; Δ{}
    ret contract$r3  ; Δ{}
    ret if _t3 then
  ; Δ{a}
  ; Δ{a}
  ; Δ{a}
  ; Δ{a}
  ; Δ{contract$a4}
  ; Δ{contract$a4}
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
  ; Δ{}
  ; Δ{}
  drop _t1 : String
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
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = + i 1  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = call <=$Int 0 contract$p7  ; Δ{}
  let _t0 = call <=$Int n 0  ; Δ{}
  let _t0 = call <=$Int n 0  ; Δ{}
  let _t0 = call >=$Int contract$r11 contract$p10  ; Δ{}
  let _t0 = call >=$Int contract$r3 contract$p2  ; Δ{}
  let _t0 = call >=$Int k 0  ; Δ{}
  let _t0 = call withdraw 100 30  ; Δ{a}
  let _t0 = rtcall axion_array_len a  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call safeDiv 100 _t0  ; Δ{}
  let _t1 = if _t0 then
  let _t1 = showInt _t0  ; Δ{a} · makes String
  let _t2 = call at w i  ; Δ{}
  let _t2 = putStrLn _t1  ; Δ{_t1 a}
  let a = rtcall axion_array_iota 10  ; Δ{} · makes Array
  let contract$a8 = 50  ; Δ{}
  let contract$r11 = call sumTo 1000 contract$p10  ; Δ{}
  let contract$r3 = call sumTo contract$g1 contract$p2  ; Δ{}
  ret * n x  ; Δ{}
  ret + _t1 _t2  ; Δ{}
  ret - balance amount  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call safeDiv x 3  ; Δ{}
  ret case _t2 of
  ret case xs of
  ret case xs of
  ret case xs of
  ret div x d  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_array_get_nobc a i  ; Δ{}
  ret rtcall axion_str_len s  ; Δ{}
<=$Int x y  =
>=$Int x y  =
at a i  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
countdown n  =
digits s  =
hoflam10 contract$p7  =
hoflamcap0 k contract$p12  =
lam$0 [env contract$g1]contract$p2  =
lam$1 [env ]contract$p10  =
lam$2 [env w]i _w1  =
le$Int x y  =
main  =
map$$hoflam10 xs  =
map$$hoflamcap0 _cap0 xs  =
safeDiv x d  =
scale n x  =
sumA a i acc  =
sumL xs  =
sumTo n acc  =
third x  =
withdraw balance amount  =
