









      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t5 : Closure
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = + a b  ; Δ{}
  let _t0 = call adder 10 5  ; Δ{}
  let _t0 = call dbl x  ; Δ{}
  let _t1 = call compose$$inc$$dbl 10  ; Δ{}
  let _t2 = + _t0 _t1  ; Δ{}
  let _t3 = call mk 1 2 3  ; Δ{}
  let _t4 = + _t2 _t3  ; Δ{}
  let _t5 = call main$wadd 100  ; Δ{} · makes Closure
  let _t6 = callclo _t5 8  ; Δ{_t5}
  ret + _t0 c  ; Δ{}
  ret + _t4 _t6  ; Δ{}
  ret + a b  ; Δ{}
  ret + x 1  ; Δ{}
  ret + x x  ; Δ{}
  ret + x y  ; Δ{}
  ret 0  ; Δ{}
  ret call inc _t0  ; Δ{}
  ret closure lam$0 a  ; Δ{} · makes Closure
  ret rtcall axion_array_free _p  ; Δ{}
adder x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
compose$$inc$$dbl x  =
dbl x  =
inc x  =
lam$0 [env a]b  =
main  =
main$wadd a  =
mk a b c  =
