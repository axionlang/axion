




      drop _t1 : tuple2$F64x4$Int
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = vec.sum.F64x4 w  ; Δ{_t1}
      let _t3 = truncate _t2  ; Δ{_t1}
      ret + _t3 k  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    (w, k) ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{_t1}
  ; Δ{}
  ; Δ{}
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = vec.splat.F64x4 1f  ; Δ{}
  let _t1 = call pair _t0  ; Δ{} · makes tuple2$F64x4$Int
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case _t1 of
  ret rtcall axion_array_free _p  ; Δ{}
  ret tuple v 1  ; Δ{} · makes heap
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_tuple2$F64x4$Int _p  =
main  =
pair v  =
