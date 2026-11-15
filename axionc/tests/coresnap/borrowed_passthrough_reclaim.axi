












      drop _t0 : String
      drop _t0 : String
      drop _t2 : String
      let _d1000000 = rtcall axion_str_len _t0  ; Δ{_t0}
      let _d1000000 = rtcall axion_str_len _t2  ; Δ{_t2 v0 x}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call idG$String x  ; Δ{} · makes String
      let _t0 = call length ys  ; Δ{}
      let _t0 = call relJoin rel x  ; Δ{} · makes String
      let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
      let _t2 = call joinAll rel rest  ; Δ{}
      let _t2 = call orDefault "d" x  ; Δ{v0 x} · makes String
      ret + 1 _t0  ; Δ{}
      ret + _t1 _t2  ; Δ{}
      ret 0  ; Δ{v0}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{v0 x}
      ret _d1000000  ; Δ{}
    Cons x _ ->
    Cons x _ ->
    Cons x rest ->
    Cons y ys ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    drop _t2 : String
    drop d : String
    else
    else
    let $aliascopy0 = rtcall axion_strcat name ""  ; Δ{} · makes String
    let $aliascopy1 = rtcall axion_strcat s ""  ; Δ{} · makes String
    let _d1000000 = rtcall axion_strcat _t2 name  ; Δ{_t2} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t2 = rtcall axion_strcat rel "/"  ; Δ{} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret $aliascopy0  ; Δ{$aliascopy0} · moves{$aliascopy0}
    ret $aliascopy1  ; Δ{$aliascopy1} · moves{$aliascopy1}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret d  ; Δ{}
  ; Δ{v0}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  drop _t9 : String
  drop l : List$String
  drop v0 : List$String
  else
  else
  else
  else
  let $aliascopy2 = rtcall axion_strcat x ""  ; Δ{} · makes String
  let _d1000000 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = call relJoin "" s  ; Δ{} · makes String
  let _t0 = rtcall axion_str_len rel  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = showInt 77  ; Δ{} · makes String
  let _t0 = showInt n  ; Δ{} · makes String
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = con Nil  ; Δ{_t0} · makes List$String
  let _t1 = showInt 8  ; Δ{_t0} · makes String
  let _t10 = call viaParam _t9  ; Δ{_t9 l}
  let _t11 = + _t8 _t10  ; Δ{l}
  let _t12 = call length l  ; Δ{l}
  let _t13 = + _t11 _t12  ; Δ{}
  let _t14 = call liveCase 225  ; Δ{}
  let _t2 = con Nil  ; Δ{_t0 _t1} · makes List$String
  let _t3 = case v0 of
  let _t3 = con Cons _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t1 _t2} · makes List$String
  let _t4 = call joinAll "" l  ; Δ{l}
  let _t4 = call length v0  ; Δ{v0}
  let _t5 = call joinAll "d" l  ; Δ{l}
  let _t6 = + _t4 _t5  ; Δ{l}
  let _t7 = call firstLen l  ; Δ{l}
  let _t8 = + _t6 _t7  ; Δ{l}
  let _t9 = showInt 12345  ; Δ{l} · makes String
  let l = con Cons _t0 _t3  ; Δ{_t0 _t3} · moves{_t0 _t3} · makes List$String
  let v0 = con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$String
  ret $aliascopy2  ; Δ{$aliascopy2} · moves{$aliascopy2}
  ret + _t13 _t14  ; Δ{}
  ret + _t3 _t4  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case xs of
  ret case xs of
  ret case xs of
  ret if _t1 then
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret x  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
firstLen xs  =
idG x  =
idG$String x  =
joinAll rel xs  =
length xs  =
liveCase n  =
main  =
orDefault d s  =
relJoin rel name  =
viaParam s  =
