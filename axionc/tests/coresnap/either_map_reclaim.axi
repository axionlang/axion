










              drop _t13 : Either$String$Int
              drop _t14 : String
              let _d1000000 = putStrLn _t14  ; Δ{_t14}
              let _t12 = con Right 4  ; Δ{} · makes Either$String$Int
              let _t13 = call mapRs _t12  ; Δ{_t12} · moves{_t12} · makes Either$String$Int
              let _t14 = call showEs _t13  ; Δ{_t13} · makes String
              ret _d1000000  ; Δ{}
            _ ->
          drop _t10 : String
          drop _t9 : Either$String$Int
          let _t10 = call showEs _t9  ; Δ{_t9} · makes String
          let _t11 = putStrLn _t10  ; Δ{_t10}
          let _t8 = con Left "err"  ; Δ{} · makes Either$String$Int
          let _t9 = call mapRs _t8  ; Δ{_t8} · moves{_t8} · makes Either$String$Int
          ret case _t11 of
        _ ->
      drop _t0 : String
      drop _t0 : String
      drop _t1 : String
      drop _t5 : Either$Int$Int
      drop _t6 : String
      drop e
      drop e
      drop e
      drop e
      let _d1000000 = rtcall axion_strcat "L" _t0  ; Δ{_t0} · makes String
      let _d1000000 = rtcall axion_strcat "R" _t0  ; Δ{_t0} · makes String
      let _d1000001 = rtcall axion_strcat "R" _t1  ; Δ{_t1} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t0 = + y 1  ; Δ{y}
      let _t0 = + y 1  ; Δ{y}
      let _t0 = showInt v  ; Δ{} · makes String
      let _t0 = showInt x  ; Δ{} · makes String
      let _t1 = showInt v  ; Δ{} · makes String
      let _t4 = con Left 9  ; Δ{} · makes Either$Int$Int
      let _t5 = call mapRi _t4  ; Δ{_t4} · moves{_t4} · makes Either$Int$Int
      let _t6 = call showEi _t5  ; Δ{_t5} · makes String
      let _t7 = putStrLn _t6  ; Δ{_t6}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret case _t7 of
      ret con Left s  ; Δ{s} · moves{s} · makes Either$String$Int
      ret con Left x  ; Δ{x} · moves{x} · makes Either$Int$Int
      ret con Right _t0  ; Δ{y} · makes Either$Int$Int
      ret con Right _t0  ; Δ{y} · makes Either$String$Int
      ret rtcall axion_strcat "L" s  ; Δ{} · makes String
    Left s ->
    Left s ->
    Left x ->
    Left x ->
    Right v ->
    Right v ->
    Right y ->
    Right y ->
    _ ->
    else
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1 : Either$Int$Int
  drop _t2 : String
  else
  else
  else
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 0  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = con Right 6  ; Δ{} · makes Either$Int$Int
  let _t1 = call mapRi _t0  ; Δ{_t0} · moves{_t0} · makes Either$Int$Int
  let _t2 = call showEi _t1  ; Δ{_t1} · makes String
  let _t3 = putStrLn _t2  ; Δ{_t2}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case _t3 of
  ret case e of
  ret case e of
  ret case e of
  ret case e of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_Either$Int _p  =
axion_drop_Either$Int$Int _p  =
axion_drop_Either$String _p  =
axion_drop_Either$String$Int _p  =
axion_drop_List _p  =
main  =
mapRi e  =
mapRs e  =
showEi e  =
showEs e  =
