









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
  drop _t1
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = + a a  ; Δ{}
  let _t0 = call <+> 3 4  ; Δ{}
  let _t1 = closure lam$0  ; Δ{} · makes heap
  let s = call <+> _t0 5  ; Δ{}
  let t = call |> 10 _t1  ; Δ{_t1}
  ret * n 2  ; Δ{}
  ret + _t0 b  ; Δ{}
  ret 0  ; Δ{}
  ret call <+> _op0 _op1  ; Δ{}
  ret call applyOp$$hoflam11 s t  ; Δ{}
  ret call double eta$1  ; Δ{}
  ret call hoflam11 a b  ; Δ{}
  ret callclo f a b  ; Δ{}
  ret callclo f x  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
<+> a b  =
applyOp f a b  =
applyOp$$hoflam11 a b  =
axion_drop_Array _p  =
axion_drop_List _p  =
double n  =
hoflam11 _op0 _op1  =
lam$0 [env ]eta$1  =
main  =
|> x f  =
