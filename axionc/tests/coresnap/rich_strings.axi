





axion_drop_Array _p  =
axion_drop_List$String _p  =
axion_drop_List _p  =
    Cons s ss ->
    Cons s ss ->
        Cons t ts ->
          drop _t0 : String
      drop _t0 : String
          drop _t1 : String
      drop _t1 : String
  drop _t3 : String
  drop _t6 : List$String
  drop _t7 : String
  drop _t8 : String
  drop _t9 : String
      drop xs
      drop xs
    else
    else
  else
  else
  let _d1000000 = putStr _t9  ; Δ{_t9}
      let _d1000000 = rtcall axion_strcat s _t1  ; Δ{_t1} · makes String
          let _d1000000 = rtcall axion_strcat s _t1  ; Δ{_t1 s t ts} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
      let _t0 = call unlines ss  ; Δ{} · makes String
          let _t0 = call unwords ss  ; Δ{s ss t ts} · moves{ss} · makes String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t1 = con Cons "Axion" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
      let _t1 = rtcall axion_strcat "\n" _t0  ; Δ{_t0} · makes String
          let _t1 = rtcall axion_strcat " " _t0  ; Δ{_t0 s t ts} · makes String
  let _t2 = con Cons "Hello" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t3 = call unwords _t2  ; Δ{_t2} · moves{_t2} · makes String
  let _t4 = con Nil  ; Δ{_t3} · makes List$String
  let _t5 = con Cons "line 2" _t4  ; Δ{_t3 _t4} · moves{_t4} · makes List$String
  let _t6 = con Cons "line 1" _t5  ; Δ{_t3 _t5} · moves{_t5} · makes List$String
  let _t7 = call unlines _t6  ; Δ{_t3 _t6} · makes String
  let _t8 = rtcall axion_strcat "!\n" _t7  ; Δ{_t3 _t7} · makes String
  let _t9 = rtcall axion_strcat _t3 _t8  ; Δ{_t3 _t8} · makes String
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
        Nil ->
    Nil ->
    Nil ->
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
      ret case ss of
  ret case xs of
  ret case xs of
  ret _d1000000  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
          ret _d1000000  ; Δ{_d1000000 s t ts} · moves{_d1000000}
  ret rtcall axion_array_free _p  ; Δ{}
          ret s  ; Δ{s ss} · moves{s}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
unlines xs  =
unwords xs  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{s ss}
