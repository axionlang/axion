






      drop a : String
      drop b : String
      drop t : tuple$String$String skip{0 1}
      let _d1000000 = rtcall axion_strcat a b  ; Δ{t} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000 t} · moves{_d1000000}
    (a, b) ->
    else
    let $aliascopy0 = call axion_copy_tuple$String$String t  ; Δ{} · makes tuple$String$String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret $aliascopy0  ; Δ{$aliascopy0} · moves{$aliascopy0}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret tuple "x" "y"  ; Δ{} · makes heap
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1 : String
  drop _t2 : String
  drop _t3 : String
  else
  else
  let _d1000000 = putStrLn _t3  ; Δ{_t3}
  let _d1000000 = rtcall axion_strcat _t1 _t2  ; Δ{_t1 _t2} · makes String
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = > c 0  ; Δ{}
  let _t0 = call pickT 0 t  ; Δ{} · makes tuple$String$String
  let _t0 = rtcall axion_strcat "p" ""  ; Δ{} · makes String
  let _t1 = call useT _t0  ; Δ{_t0} · moves{_t0} · makes String
  let _t1 = rtcall axion_strcat "q" ""  ; Δ{_t0} · makes String
  let _t2 = call useT t  ; Δ{_t1} · makes String
  let _t2 = tuple _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes heap
  let _t3 = call go _t2  ; Δ{_t2} · moves{_t2} · makes String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{}
  ret case t of
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_tuple$String$String _p  =
go t  =
main  =
pickT c t  =
useT t  =
