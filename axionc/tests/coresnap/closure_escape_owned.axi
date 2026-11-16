





























                                  drop _t38 : String
                                  let _d1000000 = putStrLn _t38  ; Δ{_t38}
                                  let _t37 = call apply2$$mkS 9 0  ; Δ{}
                                  let _t38 = call show$Int _t37  ; Δ{} · makes String
                                  ret _d1000000  ; Δ{}
                                _ ->
                              drop _t35 : String
                              let _t34 = call apply2$$adder 3 1  ; Δ{}
                              let _t35 = call show$Int _t34  ; Δ{} · makes String
                              let _t36 = putStrLn _t35  ; Δ{_t35}
                              ret case _t36 of
                            _ ->
                          drop _t26 : Closure
                          drop _t29 : Closure
                          drop _t32 : String
                          let _t25 = 1  ; Δ{}
                          let _t26 = call pick _t25 "hey"  ; Δ{} · makes Closure
                          let _t27 = callclo _t26 1  ; Δ{_t26}
                          let _t28 = 0  ; Δ{}
                          let _t29 = call pick _t28 "no"  ; Δ{} · makes Closure
                          let _t30 = callclo _t29 4  ; Δ{_t29}
                          let _t31 = + _t27 _t30  ; Δ{}
                          let _t32 = call show$Int _t31  ; Δ{} · makes String
                          let _t33 = putStrLn _t32  ; Δ{_t32}
                          ret case _t33 of
                        _ ->
                      drop _t21 : Closure
                      drop _t23 : String
                      let _t21 = call wrap 5  ; Δ{} · makes Closure
                      let _t22 = callclo _t21 0  ; Δ{_t21}
                      let _t23 = call show$Int _t22  ; Δ{} · makes String
                      let _t24 = putStrLn _t23  ; Δ{_t23}
                      ret case _t24 of
                    _ ->
                  drop _t17 : Closure
                  drop _t19 : String
                  let _t17 = call mkT 77  ; Δ{} · makes Closure
                  let _t18 = callclo _t17 0  ; Δ{_t17}
                  let _t19 = call show$Int _t18  ; Δ{} · makes String
                  let _t20 = putStrLn _t19  ; Δ{_t19}
                  ret case _t20 of
                _ ->
              drop _t13 : Closure
              drop _t15 : String
              let _t13 = call mkP "abc" 4  ; Δ{} · makes Closure
              let _t14 = callclo _t13 1  ; Δ{_t13}
              let _t15 = call show$Int _t14  ; Δ{} · makes String
              let _t16 = putStrLn _t15  ; Δ{_t15}
              ret case _t16 of
            _ ->
          drop _t10 : Integer
          drop _t11 : String
          drop _t8 : Integer
          drop _t9 : Integer
          let _t10 = call mkI _t8 _t9  ; Δ{_t8 _t9} · makes Integer
          let _t11 = rtcall axion_bignum_to_string _t10  ; Δ{_t10} · makes String
          let _t12 = putStrLn _t11  ; Δ{_t11}
          let _t8 = rtcall axion_bignum_from_i64 40  ; Δ{} · makes Integer
          let _t9 = rtcall axion_bignum_from_i64 2  ; Δ{_t8} · makes Integer
          ret case _t12 of
        _ ->
      drop _t6 : String
      drop g
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call sumL r  ; Δ{}
      let _t0 = rtcall axion_str_len a  ; Δ{}
      let _t1 = + _t0 b  ; Δ{}
      let _t5 = callclo g 10  ; Δ{g}
      let _t6 = call show$Int _t5  ; Δ{} · makes String
      let _t7 = putStrLn _t6  ; Δ{_t6}
      let g = closure lam$5  ; Δ{} · makes Closure
      ret + _t1 z  ; Δ{}
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t7 of
      ret s  ; Δ{}
    (a, b) ->
    Cons y r ->
    Nil ->
    P s _ ->
    _ ->
    else
    else
    let $clocopy3 = rtcall axion_strcat s ""  ; Δ{} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret closure lam$3 $clocopy3 owning  ; Δ{$clocopy3} · moves{$clocopy3} · makes Closure
    ret closure lam$4 owning  ; Δ{} · makes Closure
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
  drop _c0 : String
  drop _c0 : tuple2$String$Int
  drop _c1 : P
  drop _t0 : Closure
  drop _t2 : Closure
  drop _t3 : List$Int
  drop _t3 : String
  drop f : Closure
  drop p : P
  drop s : String
  drop t : tuple2$String$Int
  else
  else
  else
  let $clocopy0 = rtcall axion_strcat s ""  ; Δ{s} · makes String
  let $clocopy1 = call axion_copy_P p  ; Δ{p} · makes P
  let $clocopy2 = call axion_copy_tuple2$String$Int t  ; Δ{t} · makes tuple2$String$Int
  let _c0 = loadraw _p+24  ; Δ{}
  let _c0 = loadraw _p+24  ; Δ{}
  let _c0 = loadraw _p+24  ; Δ{}
  let _c1 = loadraw _p+32  ; Δ{}
  let _d1000000 = call mkL _t3 eta$1  ; Δ{_t3}
  let _d1000000 = callclo _t2 _t1  ; Δ{_t2}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = * n 10  ; Δ{}
  let _t0 = call adder _cap0 x  ; Δ{}
  let _t0 = call mkS _cap0  ; Δ{} · makes Closure
  let _t0 = call nameOf p  ; Δ{}
  let _t0 = call show$Int n  ; Δ{} · makes String
  let _t0 = call sumL xs  ; Δ{}
  let _t0 = callclo f 1  ; Δ{f}
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = callclo _t0 x  ; Δ{_t0}
  let _t1 = callclo f 2  ; Δ{f}
  let _t1 = con Cons 3 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t1 = rtcall axion_str_len _t0  ; Δ{}
  let _t2 = + _t0 _t1  ; Δ{}
  let _t2 = + _t1 z  ; Δ{}
  let _t2 = call mkS _cap0  ; Δ{} · makes Closure
  let _t2 = con Cons 2 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t3 = call show$Int _t2  ; Δ{} · makes String
  let _t3 = con Cons 1 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  let _t4 = putStrLn _t3  ; Δ{_t3}
  let f = call mkS 12345  ; Δ{} · makes Closure
  let p = con P nm k  ; Δ{} · makes P
  let s = call show$Int n  ; Δ{} · makes String
  let t = tuple _t0 n  ; Δ{_t0} · moves{_t0} · makes heap
  ret * z 2  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret + _t2 k  ; Δ{}
  ret + z n  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call adder _cap0 _t0  ; Δ{}
  ret call mkS _t0  ; Δ{} · makes Closure
  ret case _t4 of
  ret case p of
  ret case t of
  ret case xs of
  ret closure lam$0 $clocopy0 owning  ; Δ{$clocopy0} · moves{$clocopy0} · makes Closure
  ret closure lam$1 k $clocopy1 owning  ; Δ{$clocopy1} · moves{$clocopy1} · makes Closure
  ret closure lam$2 $clocopy2 owning  ; Δ{$clocopy2} · moves{$clocopy2} · makes Closure
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_bignum_add b z  ; Δ{} · makes Integer
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
adder n z  =
apply2$$adder _cap0 x  =
apply2$$mkS _cap0 x  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_P _p  =
axion_drop_clo$lam$0 _p  =
axion_drop_clo$lam$1 _p  =
axion_drop_clo$lam$2 _p  =
axion_drop_clo$lam$3 _p  =
axion_drop_clo$lam$4 _p  =
axion_drop_tuple2$String$Int _p  =
lam$0 [env s]z  =
lam$1 [env k p]z  =
lam$2 [env t]z  =
lam$3 [env s]z  =
lam$4 [env ]z  =
lam$5 [env ]eta$1  =
main  =
mkI b z  =
mkL xs z  =
mkP nm k  =
mkS n  =
mkT n  =
nameOf p  =
pick b s  =
show$Int x  =
sumL xs  =
wrap n  =
