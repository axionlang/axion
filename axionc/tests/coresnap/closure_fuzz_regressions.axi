
































                          drop _t31
                          drop _t37 : List$Closure
                          drop _t40 : String
                          drop f2 : Closure
                          drop satclo10
                          let $clocp0 = rtcall axion_closure_copy f2  ; Δ{_t36 f2} · makes Closure
                          let $clocp1 = rtcall axion_closure_copy f2  ; Δ{_t35 f2} · makes Closure
                          let _d1000000 = putStrLn _t40  ; Δ{_t40}
                          let _t30 = 1  ; Δ{satclo10}
                          let _t31 = closure lam$6  ; Δ{satclo10} · makes Closure
                          let _t32 = callclo f2 6  ; Δ{f2}
                          let _t33 = callclo f2 7  ; Δ{f2}
                          let _t34 = + _t32 _t33  ; Δ{f2}
                          let _t35 = con Nil  ; Δ{f2} · makes List$Closure
                          let _t36 = con Cons $clocp1 _t35  ; Δ{$clocp1 _t35 f2} · moves{$clocp1 _t35} · makes List$Closure
                          let _t37 = con Cons $clocp0 _t36  ; Δ{$clocp0 _t36} · moves{$clocp0 _t36} · makes List$Closure
                          let _t38 = call callAll _t37 1  ; Δ{_t37}
                          let _t39 = + _t34 _t38  ; Δ{}
                          let _t40 = call show$Int _t39  ; Δ{} · makes String
                          let f2 = call pick _t30 satclo10 _t31  ; Δ{_t31 satclo10} · makes Closure
                          let satclo10 = closure lam$5  ; Δ{} · makes Closure
                          ret _d1000000  ; Δ{}
                        _ ->
                      drop _t26 : List$Closure
                      drop _t28 : String
                      drop satclo8
                      drop satclo9 : Closure
                      let _t25 = call store satclo8  ; Δ{satclo8} · makes Maybe$Closure
                      let _t26 = call twice satclo9  ; Δ{satclo9} · makes List$Closure
                      let _t27 = call callAll _t26 1  ; Δ{_t26}
                      let _t28 = call show$Int _t27  ; Δ{} · makes String
                      let _t29 = putStrLn _t28  ; Δ{_t28}
                      let satclo8 = closure lam$4  ; Δ{} · makes Closure
                      let satclo9 = call getF _t25  ; Δ{_t25} · moves{_t25} · makes Closure
                      ret case _t29 of
                    _ ->
                  drop _t23 : String
                  drop satclo7 : Closure
                  let _t21 = call store$$hoflam11  ; Δ{} · makes Maybe$Closure
                  let _t22 = call useBoth satclo7  ; Δ{satclo7}
                  let _t23 = call show$Int _t22  ; Δ{} · makes String
                  let _t24 = putStrLn _t23  ; Δ{_t23}
                  let satclo7 = call getF _t21  ; Δ{_t21} · moves{_t21} · makes Closure
                  ret case _t24 of
                _ ->
              drop _t19 : String
              drop satclo5 : Closure
              drop satclo6 : Closure
              let _t16 = call show$Int 381  ; Δ{} · makes String
              let _t17 = call store satclo5  ; Δ{satclo5} · makes Maybe$Closure
              let _t18 = call useBoth satclo6  ; Δ{satclo6}
              let _t19 = call show$Int _t18  ; Δ{} · makes String
              let _t20 = putStrLn _t19  ; Δ{_t19}
              let satclo5 = call mkT _t16 9  ; Δ{_t16} · moves{_t16} · makes Closure
              let satclo6 = call getF _t17  ; Δ{_t17} · moves{_t17} · makes Closure
              ret case _t20 of
            _ ->
          drop _t12 : Closure
          drop _t14 : String
          drop satclo3 : Closure
          drop satclo4 : Closure
          let _t11 = 1  ; Δ{satclo3 satclo4}
          let _t12 = call pick _t11 satclo3 satclo4  ; Δ{satclo3 satclo4} · makes Closure
          let _t13 = callclo _t12 1  ; Δ{_t12}
          let _t14 = call show$Int _t13  ; Δ{} · makes String
          let _t15 = putStrLn _t14  ; Δ{_t14}
          let satclo3 = call mkSL 8  ; Δ{} · makes Closure
          let satclo4 = call mkSL 0  ; Δ{satclo3} · makes Closure
          ret case _t15 of
        _ ->
      drop _t0 : tuple2$Closure$Closure
      drop _t6
      drop _t7 : Closure
      drop _t9 : String
      drop m
      drop m
      drop satclo2 : Closure
      let _d1000000 = + _t1 _t2  ; Δ{_t0}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Closure _dd0  ; Δ{}
      let _dd1 = rtcall axion_closure_drop _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_closure_drop _dd2  ; Δ{}
      let _t0 = callclo f x  ; Δ{}
      let _t0 = rtcall axion_str_len a  ; Δ{}
      let _t1 = + _t0 b  ; Δ{}
      let _t1 = call callAll r x  ; Δ{}
      let _t1 = callclo g 1  ; Δ{_t0}
      let _t10 = putStrLn _t9  ; Δ{_t9}
      let _t2 = callclo h 2  ; Δ{_t0}
      let _t5 = 0  ; Δ{satclo2}
      let _t6 = closure lam$3  ; Δ{satclo2} · makes Closure
      let _t7 = call pick _t5 satclo2 _t6  ; Δ{_t6 satclo2} · makes Closure
      let _t8 = callclo _t7 6  ; Δ{_t7}
      let _t9 = call show$Int _t8  ; Δ{} · makes String
      let satclo2 = call mkSL 0  ; Δ{} · makes Closure
      ret + _t0 _t1  ; Δ{}
      ret + _t1 z  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{}
      ret case _t10 of
      ret closure lam$2  ; Δ{} · makes Closure
      ret f  ; Δ{f} · moves{f}
    (a, b) ->
    (g, h) ->
    Cons f r ->
    Just f ->
    Nil ->
    Nothing ->
    _ ->
    else
    else
    else
    let $aliascopy0 = rtcall axion_closure_copy f  ; Δ{} · makes Closure
    let $aliascopy1 = rtcall axion_closure_copy g  ; Δ{} · makes Closure
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
    ret $aliascopy0  ; Δ{$aliascopy0} · moves{$aliascopy0}
    ret $aliascopy1  ; Δ{$aliascopy1} · moves{$aliascopy1}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
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
  ; Δ{}
  drop _c0 : String
  drop _c0 : tuple2$String$Int
  drop _t0 : String
  drop _t1 : Closure
  drop _t3 : String
  drop s : String
  drop satclo0 : Closure
  drop satclo1 : Closure
  drop t : tuple2$String$Int
  else
  else
  else
  else
  let $clocopy0 = rtcall axion_strcat s ""  ; Δ{s} · makes String
  let $clocopy1 = call axion_copy_tuple2$String$Int t  ; Δ{t} · makes tuple2$String$Int
  let $clocp0 = rtcall axion_closure_copy f  ; Δ{_t1} · makes Closure
  let $clocp0 = rtcall axion_closure_copy f  ; Δ{} · makes Closure
  let $clocp0 = rtcall axion_closure_copy f  ; Δ{} · makes Closure
  let $clocp1 = rtcall axion_closure_copy f  ; Δ{$clocp0} · makes Closure
  let $clocp1 = rtcall axion_closure_copy f  ; Δ{_t0} · makes Closure
  let _c0 = loadraw _p+24  ; Δ{}
  let _c0 = loadraw _p+24  ; Δ{}
  let _d1000000 = call mkS _t0 eta$3  ; Δ{_t0}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = rtcall axion_closure_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = rtcall axion_closure_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = 1  ; Δ{satclo0 satclo1}
  let _t0 = call both f  ; Δ{} · makes tuple2$Closure$Closure
  let _t0 = call show$Int 3  ; Δ{} · makes String
  let _t0 = closure lam$7 owning  ; Δ{} · makes Closure
  let _t0 = con Nil  ; Δ{} · makes List$Closure
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = call pick _t0 satclo0 satclo1  ; Δ{satclo0 satclo1} · makes Closure
  let _t1 = con Cons $clocp1 _t0  ; Δ{$clocp1 _t0} · moves{$clocp1 _t0} · makes List$Closure
  let _t2 = callclo _t1 1  ; Δ{_t1}
  let _t3 = call show$Int _t2  ; Δ{} · makes String
  let _t4 = putStrLn _t3  ; Δ{_t3}
  let s = call show$Int n  ; Δ{} · makes String
  let satclo0 = call mkSL 8  ; Δ{} · makes Closure
  let satclo1 = call mkSL 0  ; Δ{satclo0} · makes Closure
  let t = tuple nm k  ; Δ{} · makes heap
  ret * z 2  ; Δ{}
  ret * z 2  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret + z 1  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call hoflam10 eta$1  ; Δ{}
  ret call hoflam11 eta$9  ; Δ{}
  ret call hoflam12 eta$7  ; Δ{}
  ret call mkS "bc" eta$5  ; Δ{}
  ret case _t0 of
  ret case _t4 of
  ret case fs of
  ret case m of
  ret case t of
  ret closure lam$0 $clocopy0 owning  ; Δ{$clocopy0} · moves{$clocopy0} · makes Closure
  ret closure lam$1 $clocopy1 owning  ; Δ{$clocopy1} · moves{$clocopy1} · makes Closure
  ret con Cons $clocp0 _t1  ; Δ{$clocp0 _t1} · moves{$clocp0 _t1} · makes List$Closure
  ret con Just $clocp0  ; Δ{$clocp0} · moves{$clocp0} · makes Maybe$Closure
  ret con Just _t0  ; Δ{_t0} · moves{_t0} · makes Maybe$Closure
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret tuple $clocp0 $clocp1  ; Δ{$clocp0 $clocp1} · moves{$clocp0 $clocp1} · makes heap
  ret z  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Closure _p  =
axion_drop_Maybe$Closure _p  =
axion_drop_clo$lam$0 _p  =
axion_drop_clo$lam$1 _p  =
axion_drop_clo$lam$7 _p  =
axion_drop_tuple2$Closure$Closure _p  =
axion_drop_tuple2$String$Int _p  =
both f  =
callAll fs x  =
getF m  =
hoflam10 z  =
hoflam11 z  =
hoflam12 z  =
lam$0 [env s]z  =
lam$1 [env t]z  =
lam$2 [env ]z  =
lam$3 [env ]eta$1  =
lam$4 [env ]eta$3  =
lam$5 [env ]eta$5  =
lam$6 [env ]eta$7  =
lam$7 [env ]eta$9  =
main  =
mkS s z  =
mkSL n  =
mkT nm k  =
pick b f g  =
show$Int x  =
store f  =
store$$hoflam11  =
twice f  =
useBoth f  =
