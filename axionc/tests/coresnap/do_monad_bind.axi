











              drop _t10 : String
              drop _t9 : Either$String$Int
              let _d1000000 = putStrLn _t10  ; Δ{_t10}
              let _t10 = call showE _t9  ; Δ{_t9} · makes String
              let _t9 = call both 3 0  ; Δ{} · makes Either$String$Int
              ret _d1000000  ; Δ{}
            _ ->
          drop _t1
          drop _t1
          drop _t1
          drop _t1
          drop _t6 : Either$String$Int
          drop _t7 : String
          let _t2 = + x y  ; Δ{x y}
          let _t2 = + y 1  ; Δ{x y}
          let _t6 = call both 3 4  ; Δ{} · makes Either$String$Int
          let _t7 = call showE _t6  ; Δ{_t6} · makes String
          let _t8 = putStrLn _t7  ; Δ{_t7}
          ret case _t8 of
          ret con Just _t2  ; Δ{x y} · makes Maybe$Int
          ret con Left $bindErr  ; Δ{$bindErr x} · moves{$bindErr} · makes Either$String$Int
          ret con Nothing  ; Δ{x} · makes Maybe$Int
          ret con Right _t2  ; Δ{x y} · makes Either$String$Int
        Just y ->
        Left $bindErr ->
        Nothing ->
        Right y ->
        _ ->
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0 : String
      drop _t0 : String
      drop _t3 : Maybe$Int
      drop _t4 : String
      let _d1000000 = rtcall axion_strcat "Just " _t0  ; Δ{_t0} · makes String
      let _d1000000 = rtcall axion_strcat "Right " _t0  ; Δ{_t0} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t0 = showInt v  ; Δ{} · makes String
      let _t0 = showInt v  ; Δ{} · makes String
      let _t1 = call checkPos b  ; Δ{x} · makes Either$String$Int
      let _t1 = call safeDiv x c  ; Δ{x} · makes Maybe$Int
      let _t3 = call calc 100 0 2  ; Δ{} · makes Maybe$Int
      let _t4 = call showMb _t3  ; Δ{_t3} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
      ret "Nothing"  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret case _t1 of
      ret case _t1 of
      ret case _t5 of
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$Int
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret rtcall axion_strcat "Left " s  ; Δ{} · makes String
    Just v ->
    Just x ->
    Left $bindErr ->
    Left s ->
    Nothing ->
    Nothing ->
    Right v ->
    Right x ->
    _ ->
    else
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = div a b  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret con Just _t1  ; Δ{} · makes Maybe$Int
    ret con Left "not positive"  ; Δ{} · makes Either$String$Int
    ret con Nothing  ; Δ{} · makes Maybe$Int
    ret con Right n  ; Δ{} · makes Either$String$Int
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t1 x}
  ; Δ{_t1 x}
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
  ; Δ{}
  drop _t0 : Maybe$Int
  drop _t1 : String
  else
  else
  else
  else
  else
  else
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 0  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = == b 0  ; Δ{}
  let _t0 = > n 0  ; Δ{}
  let _t0 = call calc 100 5 2  ; Δ{} · makes Maybe$Int
  let _t0 = call checkPos a  ; Δ{} · makes Either$String$Int
  let _t0 = call safeDiv a b  ; Δ{} · makes Maybe$Int
  let _t1 = call showMb _t0  ; Δ{_t0} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case _t0 of
  ret case _t0 of
  ret case _t2 of
  ret case e of
  ret case m of
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_Either$String _p  =
axion_drop_Either$String$Int _p  =
axion_drop_List _p  =
axion_drop_Maybe$Int _p  =
both a b  =
calc a b c  =
checkPos n  =
main  =
safeDiv a b  =
showE e  =
showMb m  =
