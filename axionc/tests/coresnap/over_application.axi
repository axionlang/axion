













adder x  =
axion_drop_Array _p  =
axion_drop_List _p  =
compose f g x  =
dbl x  =
  drop _t2
  drop _t3
    else
  else
inc x  =
lam$0 [env x]y  =
lam$1 [env a b]c  =
lam$2 [env ]eta$1  =
lam$3 [env ]eta$3  =
lam$4 [env a]b  =
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = + a b  ; Δ{}
  let _t0 = call adder 10  ; Δ{}
  let _t0 = callclo g x  ; Δ{}
  let _t10 = callclo _t9 8  ; Δ{}
  let _t1 = callclo _t0 5  ; Δ{}
  let _t2 = closure lam$2  ; Δ{} · makes heap
  let _t3 = closure lam$3  ; Δ{_t2} · makes heap
  let _t4 = call compose _t2 _t3 10  ; Δ{_t2 _t3}
  let _t5 = + _t1 _t4  ; Δ{}
  let _t6 = call mk 1 2  ; Δ{}
  let _t7 = callclo _t6 3  ; Δ{}
  let _t8 = + _t5 _t7  ; Δ{}
  let _t9 = call main$wadd 100  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
main$wadd a  =
mk a b  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret + a b  ; Δ{}
  ret callclo f _t0  ; Δ{}
  ret call dbl eta$3  ; Δ{}
  ret call inc eta$1  ; Δ{}
  ret closure lam$0 x  ; Δ{} · makes heap
  ret closure lam$1 a b  ; Δ{} · makes heap
  ret closure lam$4 a  ; Δ{} · makes heap
  ret rtcall axion_array_free _p  ; Δ{}
  ret + _t0 c  ; Δ{}
  ret + _t8 _t10  ; Δ{}
  ret + x 1  ; Δ{}
  ret + x x  ; Δ{}
  ret + x y  ; Δ{}
  ; Δ{}
  ; Δ{}
