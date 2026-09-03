



      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = - n 1  ; Δ{}
    let _t2 = call fib _t1  ; Δ{}
    let _t3 = - n 2  ; Δ{}
    let _t4 = call fib _t3  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret + _t2 _t4  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret n  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = < n 2  ; Δ{}
  ret 0  ; Δ{}
  ret call fib 20  ; Δ{}
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
fib n  =
main  =
