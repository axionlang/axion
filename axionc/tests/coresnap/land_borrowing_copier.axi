










      drop p : tuple2$String$String skip{0}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t0 = call sizeT a  ; Δ{}
      let _t0 = rtcall axion_strcat s ""  ; Δ{} · makes String
      let _t1 = call copyT a  ; Δ{} · makes T
      let _t1 = call sizeT b  ; Δ{}
      let _t2 = call copyT b  ; Δ{_t1} · makes T
      ret + _t0 _t1  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret a  ; Δ{p}
      ret con B _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes T
      ret con L _t0  ; Δ{_t0} · moves{_t0} · makes T
      ret rtcall axion_str_len s  ; Δ{}
    (a, b) ->
    B a b ->
    B a b ->
    L s ->
    L s ->
    else
    let _dd0 = loadraw _p+16  ; Δ{}
    let _dd1 = call axion_drop_T _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = loadraw _p+8  ; Δ{}
    let _dd3 = call axion_drop_T _dd2  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd6 = loadraw _p+8  ; Δ{}
    let _dd7 = rtcall axion_str_drop _dd6  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : T
  drop _t1 : String
  drop _t2 : T
  drop _t4 : String
  drop _t5 : String
  else
  else
  else
  let _d1000000 = putStrLn _t5  ; Δ{_t5}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = == _tag 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd8 = == _tag 0  ; Δ{}
  let _dd9 = if _dd8 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call copyT t  ; Δ{} · makes T
  let _t0 = con L "hello"  ; Δ{} · makes T
  let _t0 = tuple "A" "B"  ; Δ{} · makes heap
  let _t1 = call fstStr _t0  ; Δ{_t0} · moves{_t0} · makes String
  let _t1 = call sizeT _t0  ; Δ{_t0}
  let _t1 = con L "wor"  ; Δ{_t0} · makes T
  let _t2 = call sample  ; Δ{_t1} · makes T
  let _t2 = call sizeT t  ; Δ{}
  let _t2 = con L "ld"  ; Δ{_t0 _t1} · makes T
  let _t3 = call dupT _t2  ; Δ{_t1 _t2}
  let _t3 = con B _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t1 _t2} · makes T
  let _t4 = showInt _t3  ; Δ{_t1} · makes String
  let _t5 = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
  let _tag = loadraw _p+0  ; Δ{}
  ret + _t1 _t2  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case p of
  ret case t of
  ret case t of
  ret con B _t0 _t3  ; Δ{_t0 _t3} · moves{_t0 _t3} · makes T
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_T _p  =
axion_drop_tuple2$String$String _p  =
axion_drop_tuple2$String$String_skip_0 _p  =
copyT t  =
dupT t  =
fstStr p  =
main  =
sample  =
sizeT t  =
