



















                          drop _t19 : String
                          let _d1000000 = putStrLn _t19  ; Δ{_t19}
                          let _t18 = call shared "abc"  ; Δ{}
                          let _t19 = call show$Int _t18  ; Δ{} · makes String
                          ret _d1000000  ; Δ{}
                        _ ->
                      drop _t16 : String
                      let _t15 = call nested 12345  ; Δ{}
                      let _t16 = call show$Int _t15  ; Δ{} · makes String
                      let _t17 = putStrLn _t16  ; Δ{_t16}
                      ret case _t17 of
                    _ ->
                  drop _t13 : String
                  let _t12 = call renamed 12345  ; Δ{}
                  let _t13 = call show$Int _t12  ; Δ{} · makes String
                  let _t14 = putStrLn _t13  ; Δ{_t13}
                  ret case _t14 of
                _ ->
              drop _t10 : String
              let _t10 = call show$Int _t9  ; Δ{} · makes String
              let _t11 = putStrLn _t10  ; Δ{_t10}
              let _t9 = call singleCall 12345  ; Δ{}
              ret case _t11 of
            _ ->
          drop _t7 : String
          let _t6 = call viaString 12345  ; Δ{}
          let _t7 = call show$Int _t6  ; Δ{} · makes String
          let _t8 = putStrLn _t7  ; Δ{_t7}
          ret case _t8 of
        _ ->
      drop _t4 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = call twice 9  ; Δ{}
      let _t4 = call show$Int _t3  ; Δ{} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t5 of
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
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
  drop _t0
  drop _t1 : String
  drop _t2 : String
  drop a
  drop b
  drop f
  drop g
  drop g
  drop g
  drop h
  drop k
  drop s : String
  drop s : String
  drop s : String
  drop s : String
  else
  let _d1000000 = callclo _t0 33  ; Δ{_t0}
  let _d1000000 = callclo g 1  ; Δ{g s}
  let _d1000000 = callclo k 10  ; Δ{g k s}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call once 9  ; Δ{}
  let _t0 = callclo a 1  ; Δ{a b}
  let _t0 = callclo f 1  ; Δ{f}
  let _t0 = callclo g 1  ; Δ{g s}
  let _t0 = callclo g w  ; Δ{}
  let _t0 = callclo h 10  ; Δ{s}
  let _t0 = closure lam$0 g  ; Δ{} · makes heap
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = call show$Int _t0  ; Δ{} · makes String
  let _t1 = callclo b 1  ; Δ{b}
  let _t1 = callclo f 2  ; Δ{f}
  let _t1 = callclo g 2  ; Δ{g s}
  let _t1 = callclo g w  ; Δ{}
  let _t2 = putStrLn _t1  ; Δ{_t1}
  let _t2 = rtcall axion_strcat s "!!"  ; Δ{} · makes String
  let _t3 = rtcall axion_str_len _t2  ; Δ{_t2}
  let _t4 = + _t3 r  ; Δ{}
  let a = closure lam$7 s  ; Δ{} · makes heap
  let b = closure lam$8 s  ; Δ{a} · makes heap
  let f = closure lam$1 s  ; Δ{} · makes heap
  let g = closure lam$2 s  ; Δ{s} · makes heap
  let g = closure lam$3 s  ; Δ{s} · makes heap
  let g = closure lam$4 s  ; Δ{s} · makes heap
  let g = closure lam$5 s  ; Δ{s} · makes heap
  let h = g  ; Δ{g s} · moves{g}
  let k = closure lam$6 g  ; Δ{g s} · makes heap
  let r = + _t0 _t1  ; Δ{}
  let s = call show$Int n  ; Δ{} · makes String
  let s = call show$Int n  ; Δ{} · makes String
  let s = call show$Int n  ; Δ{} · makes String
  let s = call show$Int n  ; Δ{} · makes String
  ret * _t0 z  ; Δ{}
  ret + _t0 1  ; Δ{}
  ret + _t0 _t1  ; Δ{}
  ret + _t0 _t1  ; Δ{}
  ret + _t0 _t1  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret + _t0 z  ; Δ{}
  ret + g y  ; Δ{}
  ret + s y  ; Δ{}
  ret - _t4 6  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case _t2 of
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
lam$0 [env g]y  =
lam$1 [env s]y  =
lam$2 [env s]z  =
lam$3 [env s]z  =
lam$4 [env s]z  =
lam$5 [env s]z  =
lam$6 [env g]w  =
lam$7 [env s]z  =
lam$8 [env s]z  =
main  =
nested n  =
once g  =
renamed n  =
shared s  =
show$Int x  =
singleCall n  =
twice s  =
viaString n  =
