








































                                          drop _t59 : List$Btn
                                          drop _t61 : String
                                          let _d1000000 = putStrLn _t61  ; Δ{_t61}
                                          let _t54 = call wrapBtn$$hoflam10 "a"  ; Δ{} · makes Btn
                                          let _t55 = closure lam$7 owning  ; Δ{_t54} · makes Closure
                                          let _t56 = record Btn { label = "c" onClick = _t55 clicks = 1}  ; Δ{_t54 _t55} · moves{_t55} · makes Btn
                                          let _t57 = con Nil  ; Δ{_t54 _t56} · makes List$Btn
                                          let _t58 = con Cons _t56 _t57  ; Δ{_t54 _t56 _t57} · moves{_t56 _t57} · makes List$Btn
                                          let _t59 = con Cons _t54 _t58  ; Δ{_t54 _t58} · moves{_t54 _t58} · makes List$Btn
                                          let _t60 = call pressAll _t59 4  ; Δ{_t59}
                                          let _t61 = call show$Int _t60  ; Δ{} · makes String
                                          ret _d1000000  ; Δ{}
                                        _ ->
                                      drop _t52 : String
                                      drop w : Btn
                                      let _t51 = call press w 9  ; Δ{w}
                                      let _t52 = call show$Int _t51  ; Δ{} · makes String
                                      let _t53 = putStrLn _t52  ; Δ{_t52}
                                      let w = call wrapBtn$$hoflam9 "w"  ; Δ{} · makes Btn
                                      ret case _t53 of
                                    _ ->
                                  drop _t49 : String
                                  drop b2 : Btn
                                  drop b3 : Btn
                                  let _t48 = call press b3 5  ; Δ{b3}
                                  let _t49 = call show$Int _t48  ; Δ{} · makes String
                                  let _t50 = putStrLn _t49  ; Δ{_t49}
                                  let b3 = call rewire b2 3  ; Δ{b2} · makes Btn
                                  ret case _t50 of
                                _ ->
                              drop _t46 : String
                              let _t45 = call press b2 10  ; Δ{b2}
                              let _t46 = call show$Int _t45  ; Δ{b2} · makes String
                              let _t47 = putStrLn _t46  ; Δ{_t46 b2}
                              ret case _t47 of
                            _ ->
                          drop b : Btn
                          let _t43 = field label b2  ; Δ{b2}
                          let _t44 = putStrLn _t43  ; Δ{b2}
                          let b2 = call relabel b  ; Δ{b} · makes Btn
                          ret case _t44 of
                        _ ->
                      drop _t41 : String
                      drop nn : String
                      let $clocopy1 = rtcall axion_strcat nn ""  ; Δ{nn} · makes String
                      let _t37 = closure lam$6 $clocopy1 owning  ; Δ{$clocopy1} · moves{$clocopy1} · makes Closure
                      let _t38 = call press b 1  ; Δ{b}
                      let _t39 = call press b 2  ; Δ{b}
                      let _t40 = + _t38 _t39  ; Δ{b}
                      let _t41 = call show$Int _t40  ; Δ{b} · makes String
                      let _t42 = putStrLn _t41  ; Δ{_t41 b}
                      let b = record Btn { label = "ok" onClick = _t37 clicks = 2}  ; Δ{_t37} · moves{_t37} · makes Btn
                      let nn = call show$Int 1234  ; Δ{} · makes String
                      ret case _t42 of
                    _ ->
                  drop _t33 : List$Handler
                  drop _t35 : String
                  let _t29 = call mkH "x" 2  ; Δ{} · makes Handler
                  let _t30 = call mkH "yy" 3  ; Δ{_t29} · makes Handler
                  let _t31 = con Nil  ; Δ{_t29 _t30} · makes List$Handler
                  let _t32 = con Cons _t30 _t31  ; Δ{_t29 _t30 _t31} · moves{_t30 _t31} · makes List$Handler
                  let _t33 = con Cons _t29 _t32  ; Δ{_t29 _t32} · moves{_t29 _t32} · makes List$Handler
                  let _t34 = call runAll _t33 1  ; Δ{_t33}
                  let _t35 = call show$Int _t34  ; Δ{} · makes String
                  let _t36 = putStrLn _t35  ; Δ{_t35}
                  ret case _t36 of
                _ ->
              drop _t17 : Op
              drop _t20 : Op
              drop _t24 : Op
              drop _t27 : String
              let _t16 = closure lam$3 owning  ; Δ{} · makes Closure
              let _t17 = con Unary _t16  ; Δ{_t16} · moves{_t16} · makes Op
              let _t18 = call apply _t17 7  ; Δ{_t17}
              let _t19 = closure lam$4 owning  ; Δ{} · makes Closure
              let _t20 = con Binary _t19  ; Δ{_t19} · moves{_t19} · makes Op
              let _t21 = call apply _t20 3  ; Δ{_t20}
              let _t22 = + _t18 _t21  ; Δ{}
              let _t23 = closure lam$5 owning  ; Δ{} · makes Closure
              let _t24 = con Named "nm" _t23  ; Δ{_t23} · moves{_t23} · makes Op
              let _t25 = call apply _t24 4  ; Δ{_t24}
              let _t26 = + _t22 _t25  ; Δ{}
              let _t27 = call show$Int _t26  ; Δ{} · makes String
              let _t28 = putStrLn _t27  ; Δ{_t27}
              ret case _t28 of
            _ ->
          drop _t14 : String
          drop hs : List$Handler
          let _t10 = con Nil  ; Δ{_t7 _t9 h} · makes List$Handler
          let _t11 = con Cons h _t10  ; Δ{_t10 _t7 _t9 h} · moves{_t10 h} · makes List$Handler
          let _t12 = con Cons _t9 _t11  ; Δ{_t11 _t7 _t9} · moves{_t11 _t9} · makes List$Handler
          let _t13 = call runAll hs 5  ; Δ{hs}
          let _t14 = call show$Int _t13  ; Δ{} · makes String
          let _t15 = putStrLn _t14  ; Δ{_t14}
          let _t7 = call mkH "a" 1  ; Δ{h} · makes Handler
          let _t8 = closure lam$2 owning  ; Δ{_t7 h} · makes Closure
          let _t9 = con Handler "dbl" _t8  ; Δ{_t7 _t8 h} · moves{_t8} · makes Handler
          let hs = con Cons _t7 _t12  ; Δ{_t12 _t7} · moves{_t12 _t7} · makes List$Handler
          ret case _t15 of
        _ ->
      drop _t5 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Btn _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Handler _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_Btn _dd2  ; Δ{}
      let _dd3 = call axion_drop_Handler _dd2  ; Δ{}
      let _t0 = call press b x  ; Δ{}
      let _t0 = call runH h x  ; Δ{}
      let _t0 = rtcall axion_str_len s  ; Δ{}
      let _t1 = call pressAll r x  ; Δ{}
      let _t1 = call runAll r x  ; Δ{}
      let _t1 = callclo f$1 x  ; Δ{}
      let _t2 = call runH h 10  ; Δ{h}
      let _t3 = call runH h 20  ; Δ{h}
      let _t4 = + _t2 _t3  ; Δ{h}
      let _t5 = call show$Int _t4  ; Δ{h} · makes String
      let _t6 = putStrLn _t5  ; Δ{_t5 h}
      ret + _t0 _t1  ; Δ{}
      ret + _t0 _t1  ; Δ{}
      ret + _t0 _t1  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret callclo f x  ; Δ{}
      ret callclo f x  ; Δ{}
      ret callclo g x x  ; Δ{}
      ret case _t6 of
      ret n  ; Δ{}
    Binary g ->
    Cons b r ->
    Cons h r ->
    Handler _ f ->
    Handler n _ ->
    Named s f$1 ->
    Nil ->
    Nil ->
    Unary f ->
    _ ->
    else
    else
    else
    let _dd0 = loadraw _p+16  ; Δ{}
    let _dd1 = rtcall axion_closure_drop _dd0  ; Δ{}
    let _dd10 = loadraw _p+8  ; Δ{}
    let _dd11 = rtcall axion_closure_drop _dd10  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = loadraw _p+8  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dd6 = loadraw _p+8  ; Δ{}
    let _dd7 = rtcall axion_closure_drop _dd6  ; Δ{}
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
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{b2}
  ; Δ{b2}
  ; Δ{b}
  ; Δ{h}
  ; Δ{h}
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
  drop _c0 : String
  drop _c1 : String
  drop tag : String
  else
  else
  else
  else
  else
  else
  let $clocopy0 = rtcall axion_strcat tag ""  ; Δ{tag} · makes String
  let $updfield1 = field label b  ; Δ{_t0}
  let $updfield1 = field onClick b  ; Δ{_t1}
  let $updfield1c0 = rtcall axion_closure_copy $updfield1  ; Δ{_t1} · makes Closure
  let $updfield1c0 = rtcall axion_strcat $updfield1 ""  ; Δ{_t0} · makes String
  let _c0 = loadraw _p+24  ; Δ{}
  let _c1 = loadraw _p+32  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = rtcall axion_closure_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_closure_drop _dd0  ; Δ{}
  let _dd12 = == _tag 0  ; Δ{}
  let _dd13 = if _dd12 then
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = == _tag 2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dd8 = == _tag 1  ; Δ{}
  let _dd9 = if _dd8 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = + z k  ; Δ{}
  let _t0 = call hname h  ; Δ{h}
  let _t0 = closure lam$0 k $clocopy0 owning  ; Δ{$clocopy0} · moves{$clocopy0} · makes Closure
  let _t0 = closure lam$1 k  ; Δ{} · makes Closure
  let _t0 = closure lam$8 owning  ; Δ{} · makes Closure
  let _t0 = closure lam$9 owning  ; Δ{} · makes Closure
  let _t0 = field label b  ; Δ{}
  let _t0 = field onClick b  ; Δ{}
  let _t0 = rtcall axion_str_len nn  ; Δ{}
  let _t1 = callclo _t0 x  ; Δ{}
  let _t1 = putStrLn _t0  ; Δ{h}
  let _t1 = rtcall axion_str_len tag  ; Δ{}
  let _t1 = rtcall axion_strcat _t0 "*"  ; Δ{} · makes String
  let _t2 = field clicks b  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let h = call mkH "inc" 1  ; Δ{} · makes Handler
  let tag = rtcall axion_strcat n "!"  ; Δ{} · makes String
  ret * a b  ; Δ{}
  ret * z 2  ; Δ{}
  ret * z 2  ; Δ{}
  ret * z k  ; Δ{}
  ret + _t0 _t1  ; Δ{}
  ret + _t1 _t2  ; Δ{}
  ret + z _t0  ; Δ{}
  ret - z 1  ; Δ{}
  ret - z 1  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call hoflam10 eta$1  ; Δ{}
  ret call hoflam9 eta$3  ; Δ{}
  ret case _t1 of
  ret case bs of
  ret case h of
  ret case h of
  ret case hs of
  ret case op of
  ret con Handler n _t0  ; Δ{_t0} · moves{_t0} · makes Handler
  ret record Btn { label = s onClick = _t0 clicks = 0}  ; Δ{_t0} · moves{_t0} · makes Btn
  ret record Btn { label = s onClick = _t0 clicks = 0}  ; Δ{_t0} · moves{_t0} · makes Btn
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret update b { label = _t1 onClick = $updfield1c0}  ; Δ{$updfield1c0 _t1} · moves{$updfield1c0 _t1} · makes heap
  ret update b { onClick = _t0 label = $updfield1c0}  ; Δ{$updfield1c0 _t0} · moves{$updfield1c0 _t0} · makes heap
  ret z  ; Δ{}
  ret z  ; Δ{}
apply op x  =
axion_drop_Array _p  =
axion_drop_Btn _p  =
axion_drop_Handler _p  =
axion_drop_List _p  =
axion_drop_List$Btn _p  =
axion_drop_List$Handler _p  =
axion_drop_Op _p  =
axion_drop_clo$lam$0 _p  =
axion_drop_clo$lam$2 _p  =
axion_drop_clo$lam$3 _p  =
axion_drop_clo$lam$4 _p  =
axion_drop_clo$lam$5 _p  =
axion_drop_clo$lam$6 _p  =
axion_drop_clo$lam$7 _p  =
axion_drop_clo$lam$8 _p  =
axion_drop_clo$lam$9 _p  =
hname h  =
hoflam10 z  =
hoflam9 z  =
lam$0 [env k tag]z  =
lam$1 [env k]z  =
lam$2 [env ]z  =
lam$3 [env ]z  =
lam$4 [env ]a b  =
lam$5 [env ]z  =
lam$6 [env nn]z  =
lam$7 [env ]z  =
lam$8 [env ]eta$1  =
lam$9 [env ]eta$3  =
main  =
mkH n k  =
press b x  =
pressAll bs x  =
relabel b  =
rewire b k  =
runAll hs x  =
runH h x  =
show$Int x  =
wrapBtn$$hoflam10 s  =
wrapBtn$$hoflam9 s  =
