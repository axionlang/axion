






      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = - n 1  ; Δ{}
      let _t3 = call fib _t2  ; Δ{}
      let _t4 = - n 2  ; Δ{}
      let _t5 = call fib _t4  ; Δ{}
      let n = _p0  ; Δ{}
      ret + _t3 _t5  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = - k 1  ; Δ{}
    let _t1 = == _p0 1  ; Δ{}
    let _t2 = + a b  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let a = _p1  ; Δ{}
    let a = _p1  ; Δ{}
    let b = _p2  ; Δ{}
    let k = _p0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret a  ; Δ{}
    ret call fibFast$go _t1 b _t2  ; Δ{}
    ret if _t1 then
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1 : String
  else
  else
  else
  let _d1000000 = putStrLn _t1  ; Δ{_t1}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = == _p0 0  ; Δ{}
  let _t0 = == _p0 0  ; Δ{}
  let _t0 = call fibFast 30  ; Δ{}
  let _t1 = call show$Int _t0  ; Δ{} · makes String
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call fibFast$go n 0 1  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
fib _p0  =
fibFast n  =
fibFast$go _p0 _p1 _p2  =
main  =
show$Int x  =
