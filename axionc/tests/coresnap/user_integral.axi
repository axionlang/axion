







              drop _t12 : M
              drop _t13 : M
              drop _t14 : M
              drop _t16 : String
              let _d1000000 = putStrLn _t16  ; Δ{_t16}
              let _t12 = con M 17  ; Δ{} · makes M
              let _t13 = con M 5  ; Δ{_t12} · makes M
              let _t14 = call mod$M _t12 _t13  ; Δ{_t12 _t13} · makes M
              let _t15 = call unM _t14  ; Δ{_t14}
              let _t16 = showInt _t15  ; Δ{} · makes String
              ret _d1000000  ; Δ{}
            _ ->
          drop _t10 : String
          drop _t6 : M
          drop _t7 : M
          drop _t8 : M
          let _t10 = showInt _t9  ; Δ{} · makes String
          let _t11 = putStrLn _t10  ; Δ{_t10}
          let _t6 = con M 17  ; Δ{} · makes M
          let _t7 = con M 5  ; Δ{_t6} · makes M
          let _t8 = call div$M _t6 _t7  ; Δ{_t6 _t7} · makes M
          let _t9 = call unM _t8  ; Δ{_t8}
          ret case _t11 of
        _ ->
      drop _t4 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = mod 17 5  ; Δ{}
      let _t4 = showInt _t3  ; Δ{} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t5 of
      ret n  ; Δ{}
    M n ->
    _ ->
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
  ; Δ{}
  ; Δ{}
  drop _t1 : String
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call unM a  ; Δ{}
  let _t0 = call unM a  ; Δ{}
  let _t0 = div 17 5  ; Δ{}
  let _t1 = call unM b  ; Δ{}
  let _t1 = call unM b  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = div _t0 _t1  ; Δ{}
  let _t2 = mod _t0 _t1  ; Δ{}
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret 0  ; Δ{}
  ret call divM a b  ; Δ{} · makes M
  ret call modM a b  ; Δ{} · makes M
  ret case _t2 of
  ret case m of
  ret con M _t2  ; Δ{} · makes M
  ret con M _t2  ; Δ{} · makes M
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
div$M a b  =
divM a b  =
main  =
mod$M a b  =
modM a b  =
unM m  =
