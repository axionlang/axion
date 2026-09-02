





    (a, b) ->
axion_drop_Array _p  =
axion_drop_Box _p  =
axion_drop_List _p  =
axion_drop_tuple$Box$Box _p  =
      drop t : tuple$Box$Box
    else
  else
      let _dd0 = loadraw _p+16  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd1 = rtcall axion_free _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
  let _dd3 = rtcall axion_free _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = field v a  ; Δ{t}
  let _t0 = record Box { v = 1}  ; Δ{} · makes Box
      let _t1 = field v b  ; Δ{t}
  let _t1 = record Box { v = 3}  ; Δ{_t0} · makes Box
  let _t2 = tuple _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes heap
    let _tag = loadraw _p+0  ; Δ{}
main  =
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call useTuple _t2  ; Δ{_t2} · moves{_t2}
  ret case t of
  ret rtcall axion_array_free _p  ; Δ{}
      ret + _t0 _t1  ; Δ{}
useTuple t  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
