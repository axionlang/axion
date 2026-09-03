





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
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  ret + _op0 _op1  ; Δ{}
  ret 0  ; Δ{}
  ret call apply2$$hoflam11 3 4  ; Δ{}
  ret call hoflam11 x y  ; Δ{}
  ret callclo f x y  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
apply2 f x y  =
apply2$$hoflam11 x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
hoflam11 _op0 _op1  =
main  =
