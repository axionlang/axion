






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
  drop g
  else
  let _d1000000 = call apply g 32  ; Δ{g}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let g = closure lam$0 n  ; Δ{} · makes heap
  ret + k n  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call addN n eta$1  ; Δ{}
  ret call mk 10  ; Δ{}
  ret callclo f x  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
addN n k  =
apply f x  =
axion_drop_Array _p  =
axion_drop_List _p  =
lam$0 [env n]eta$1  =
main  =
mk n  =
