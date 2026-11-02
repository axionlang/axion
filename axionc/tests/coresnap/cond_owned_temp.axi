





            let _t10 = con Nil  ; Δ{} · makes List$String
            let _t11 = con Cons "c" _t10  ; Δ{_t10} · moves{_t10} · makes List$String
            let _t9 = con Nil  ; Δ{} · makes List$String
            ret con Cons "a" _t9  ; Δ{_t9} · moves{_t9} · makes List$String
            ret con Cons "b" _t11  ; Δ{_t11} · moves{_t11} · makes List$String
          drop _t1 : String
          drop _t12 : List$String
          drop _t14 : String
          drop _t4 : String
          else
          let _d1000000 = putStrLn _t14  ; Δ{_t14}
          let _t12 = if _t8 then
          let _t13 = call length _t12  ; Δ{}
          let _t14 = showInt _t13  ; Δ{} · makes String
          let _t8 = 1  ; Δ{}
          ret _d1000000  ; Δ{}
        _ ->
        ret rtcall axion_strcat "p" "q"  ; Δ{} · makes String
        ret rtcall axion_strcat "x" "y"  ; Δ{} · makes String
      drop _t6 : String
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t3 = 0  ; Δ{}
      let _t4 = if _t3 then
      let _t5 = call sink _t4  ; Δ{}
      let _t6 = showInt _t5  ; Δ{} · makes String
      let _t7 = putStrLn _t6  ; Δ{_t6}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t7 of
    Cons y ys ->
    Nil ->
    _ ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret rtcall axion_strcat "a" "b"  ; Δ{} · makes String
    ret rtcall axion_strcat "c" "d"  ; Δ{} · makes String
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
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = 1  ; Δ{}
  let _t1 = if _t0 then
  let _t2 = putStrLn _t1  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case _t2 of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_str_len s  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
length xs  =
main  =
sink s  =
