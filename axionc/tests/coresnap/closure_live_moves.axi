











              drop _t17 : String
              drop cl
              drop cs
              drop f0
              let $clomv1 = rtcall axion_closure_copy cs  ; Δ{cl cs} · makes Closure
              let _d1000000 = putStrLn _t17  ; Δ{_t17}
              let _t12 = callclo f0 30  ; Δ{cl cs}
              let _t13 = callclo cs 0  ; Δ{cl cs}
              let _t14 = + _t12 _t13  ; Δ{cl}
              let _t15 = callclo cl 0  ; Δ{cl}
              let _t16 = + _t14 _t15  ; Δ{}
              let _t17 = showInt _t16  ; Δ{} · makes String
              let f0 = $clomv1  ; Δ{$clomv1 cl cs} · moves{$clomv1}
              ret _d1000000  ; Δ{}
            _ ->
          drop _t10 : String
          drop _t8 : Closure
          let _t10 = showInt _t9  ; Δ{cl cs} · makes String
          let _t11 = putStrLn _t10  ; Δ{_t10 cl cs}
          let _t8 = call idG$Closure cs  ; Δ{cl cs} · makes Closure
          let _t9 = callclo _t8 20  ; Δ{_t8 cl cs}
          ret case _t11 of
        _ ->
      drop _t0 : tuple2$Closure$Int skip{0}
      drop _t4 : Closure
      drop _t6 : String
      drop g : Closure
      let _d1000000 = callclo g n  ; Δ{_t0}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = 0  ; Δ{cl cs}
      let _t4 = call pick _t3 cs cl  ; Δ{cl cs} · makes Closure
      let _t5 = callclo _t4 10  ; Δ{_t4 cl cs}
      let _t6 = showInt _t5  ; Δ{cl cs} · makes String
      let _t7 = putStrLn _t6  ; Δ{_t6 cl cs}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_t0}
      ret case _t7 of
    (g, n) ->
    _ ->
    else
    let $aliascopy0 = rtcall axion_closure_copy f  ; Δ{} · makes Closure
    let $aliascopy1 = rtcall axion_closure_copy g  ; Δ{} · makes Closure
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret $aliascopy0  ; Δ{$aliascopy0} · moves{$aliascopy0}
    ret $aliascopy1  ; Δ{$aliascopy1} · moves{$aliascopy1}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{_t0}
  ; Δ{cl cs}
  ; Δ{cl cs}
  ; Δ{cl cs}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1 : String
  else
  else
  let $aliascopy2 = rtcall axion_closure_copy x  ; Δ{} · makes Closure
  let $clomv0 = rtcall axion_closure_copy cs  ; Δ{cl cs} · makes Closure
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd1 = rtcall axion_closure_drop _dd0  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call pairWith f k  ; Δ{} · makes tuple2$Closure$Int
  let _t0 = call usePair $clomv0 1  ; Δ{$clomv0 cl cs} · moves{$clomv0}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = showInt _t0  ; Δ{cl cs} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1 cl cs}
  let cl = closure lam$1  ; Δ{cs} · makes Closure
  let cs = closure lam$0  ; Δ{} · makes Closure
  ret $aliascopy2  ; Δ{$aliascopy2} · moves{$aliascopy2}
  ret + z _t0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call mkS "abc" eta$1  ; Δ{}
  ret call mkS "hello" eta$3  ; Δ{}
  ret case _t0 of
  ret case _t2 of
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
  ret tuple x y  ; Δ{} · makes heap
  ret x  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_tuple2$Closure$Int _p  =
idG x  =
idG$Closure x  =
lam$0 [env ]eta$1  =
lam$1 [env ]eta$3  =
main  =
mkS s z  =
pairWith x y  =
pick b f g  =
usePair f k  =
