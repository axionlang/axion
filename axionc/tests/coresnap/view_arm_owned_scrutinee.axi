








          drop g : Closure
          drop g : Closure
          drop s : String
          drop w
          drop w : Maybe$String
          let _d1000000 = callclo g _t5  ; Δ{g}
          let _t5 = rtcall axion_str_len s  ; Δ{g s}
          ret 0  ; Δ{}
          ret _d1000000  ; Δ{}
        Just s ->
        Nothing ->
      drop a
      drop a
      drop b : Maybe$Closure
      drop b : Maybe$String
      drop k
      drop k : Maybe$Closure
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = rtcall axion_closure_drop _dd0  ; Δ{}
      let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
      let _t3 = con Just "hi"  ; Δ{g} · makes Maybe$String
      let _t4 = con Just "yo"  ; Δ{_t3 g} · makes Maybe$String
      let w = call keepS _t3 _t4  ; Δ{_t3 _t4 g} · moves{_t3 _t4} · makes Maybe$String
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret a  ; Δ{a f} · moves{a}
      ret a  ; Δ{a s} · moves{a}
      ret b  ; Δ{}
      ret b  ; Δ{}
      ret case w of
    Just f ->
    Just g ->
    Just s ->
    Nothing ->
    Nothing ->
    Nothing ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{g w}
  ; Δ{k}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = closure lam$0 owning  ; Δ{} · makes Closure
  let _t1 = con Just _t0  ; Δ{_t0} · moves{_t0} · makes Maybe$Closure
  let _t2 = con Nothing  ; Δ{_t1} · makes Maybe$Closure
  let k = call keepOr _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes Maybe$Closure
  ret + x 1  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case a of
  ret case a of
  ret case k of
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Maybe$Closure _p  =
axion_drop_Maybe$String _p  =
axion_drop_clo$lam$0 _p  =
keepOr a b  =
keepS a b  =
lam$0 [env ]x  =
main  =
