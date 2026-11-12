






                  drop _t9 : String
                  let _d1000000 = putStrLn _t9  ; Δ{_t9}
                  let _t9 = call show$Int d  ; Δ{} · makes String
                  let d = + a 2  ; Δ{}
                  ret _d1000000  ; Δ{}
                  ret putStrLn "no"  ; Δ{}
                7 ->
                _ ->
              ret case a of
            _ ->
          drop _t7 : String
          let _t6 = call letThenCase 5  ; Δ{}
          let _t7 = call show$Int _t6  ; Δ{} · makes String
          let _t8 = putStrLn _t7  ; Δ{_t7}
          ret case _t8 of
        _ ->
        ret 7  ; Δ{}
        ret 8  ; Δ{}
      Big ->
      Small ->
      drop _t4 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t4 = call show$Int b  ; Δ{} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
      let c = b  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 10  ; Δ{}
      ret 20  ; Δ{}
      ret c  ; Δ{}
      ret case _t5 of
    12 ->
    Big ->
    Small ->
    _ ->
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret case s of
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
  drop _t2 : String
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = > n 0  ; Δ{}
  let _t0 = con Small  ; Δ{}
  let _t1 = con Small  ; Δ{}
  let _t2 = call show$Int a  ; Δ{} · makes String
  let _t3 = putStrLn _t2  ; Δ{_t2}
  let a = + n 1  ; Δ{}
  let a = call pick 1 _t0  ; Δ{}
  let b = * a 2  ; Δ{}
  let b = call deepLet _t1  ; Δ{}
  let other = 20  ; Δ{}
  let total = case s of
  ret + total other  ; Δ{}
  ret 0  ; Δ{}
  ret case _t3 of
  ret case b of
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
deepLet s  =
letThenCase n  =
main  =
pick n s  =
show$Int x  =
