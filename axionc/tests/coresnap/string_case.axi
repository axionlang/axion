



          ret 0  ; Δ{}
          ret 9  ; Δ{}
        else
        let _t6 = rtcall axion_str_len s  ; Δ{}
        let _t7 = == _t6 0  ; Δ{}
        ret 3  ; Δ{}
        ret if _t7 then
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t4 = rtcall axion_str_cmp s "three"  ; Δ{}
      let _t5 = == _t4 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 2  ; Δ{}
      ret if _t5 then
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t2 = rtcall axion_str_cmp s "two"  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret if _t3 then
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call classify "one"  ; Δ{}
  let _t0 = rtcall axion_str_cmp s "one"  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = call classify "two"  ; Δ{}
  let _t2 = * _t1 10  ; Δ{}
  let _t3 = + _t0 _t2  ; Δ{}
  let _t4 = call classify "three"  ; Δ{}
  let _t5 = * _t4 100  ; Δ{}
  let _t6 = + _t3 _t5  ; Δ{}
  let _t7 = call classify ""  ; Δ{}
  let _t8 = * _t7 1000  ; Δ{}
  ret + _t6 _t8  ; Δ{}
  ret 0  ; Δ{}
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
classify s  =
main  =
