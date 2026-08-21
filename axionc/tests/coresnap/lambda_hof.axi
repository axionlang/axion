








add  =
apply f x  =
axion_drop_Array _p  =
axion_drop_List _p  =
  drop _t0
  drop _t4 : String
    else
  else
lam$0 [env ]x  =
lam$1 [env x]y  =
lam$2 [env ]n  =
  let _d1000000 = putStrLn _t4  ; Δ{_t4}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = closure lam$2  ; Δ{} · makes heap
  let _t1 = call apply _t0 20  ; Δ{_t0}
  let _t2 = call add  ; Δ{}
  let _t3 = callclo _t2 _t1 21  ; Δ{}
  let _t4 = call show$Int _t3  ; Δ{} · makes String
    let _tag = loadraw _p+0  ; Δ{}
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret callclo f x  ; Δ{}
  ret closure lam$0  ; Δ{} · makes heap
  ret closure lam$1 x  ; Δ{} · makes heap
  ret _d1000000  ; Δ{}
  ret + n 1  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret + x y  ; Δ{}
show$Int x  =
  ; Δ{}
  ; Δ{}
