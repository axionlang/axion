






                      ret call loop 5  ; Δ{}
                    _ ->
                    ret "no"  ; Δ{}
                    ret "yes"  ; Δ{}
                  else
                  let _t10 = putStrLn _t9  ; Δ{}
                  let _t8 = < 3 5  ; Δ{}
                  let _t9 = if _t8 then
                  ret case _t10 of
                _ ->
              drop _t6 : String
              let _t6 = call constMsg 0  ; Δ{} · makes String
              let _t7 = putStrLn _t6  ; Δ{_t6}
              ret case _t7 of
            _ ->
          drop _t4 : String
          let _t3 = * 100 100  ; Δ{}
          let _t4 = call show$Int _t3  ; Δ{} · makes String
          let _t5 = putStrLn _t4  ; Δ{_t4}
          ret case _t5 of
        _ ->
        let _t4 = - n 1  ; Δ{}
        ret call loop _t4  ; Δ{}
      _ ->
      drop _t1 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t1 = call greet "bob"  ; Δ{} · makes String
      let _t2 = putStrLn _t1  ; Δ{_t1}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t2 of
    _ ->
    drop _t1 : String
    drop _t2 : String
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = call show$Int n  ; Δ{} · makes String
    let _t2 = call greet _t1  ; Δ{_t1} · makes String
    let _t3 = putStrLn _t2  ; Δ{_t2}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret case _t3 of
    ret putStr ""  ; Δ{}
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
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = < n 1  ; Δ{}
  let _t0 = putStrLn "literal"  ; Δ{}
  ret "const"  ; Δ{}
  ret 0  ; Δ{}
  ret case _t0 of
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_strcat "hi " name  ; Δ{} · makes String
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
constMsg x  =
greet name  =
loop n  =
main  =
show$Int x  =
