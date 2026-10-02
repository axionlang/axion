





          ret x  ; Δ{}
        (x, y) ->
      drop t
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case a of
    (a, b) ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t4 : String
  else
  let _d1000000 = putStrLn _t4  ; Δ{_t4}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_tuple$String$String _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = call axion_drop_tuple$String$String _dd2  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = rtcall axion_strcat "p" ""  ; Δ{} · makes String
  let _t1 = tuple _t0 "q"  ; Δ{_t0} · moves{_t0} · makes heap
  let _t2 = tuple "r" "s"  ; Δ{_t1} · makes heap
  let _t3 = tuple _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes heap
  let _t4 = call useNT _t3  ; Δ{_t3} · moves{_t3} · makes String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case t of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_tuple$String$String _p  =
axion_drop_tuple$tuple$String$String$tuple$String$String _p  =
main  =
useNT t  =
