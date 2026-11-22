






        drop _t10 : String
        drop _t11 : String
        drop _t5 : String
        drop _t6 : String
        drop _t7 : String
        drop _t8 : String
        drop _t9 : String
        let _d1000001 = rtcall axion_contract_fail _t11  ; Δ{_t11}
        let _t10 = rtcall axion_strcat _t8 _t9  ; Δ{_t8 _t9} · makes String
        let _t11 = rtcall axion_strcat _t10 "), called from `main`"  ; Δ{_t10} · makes String
        let _t5 = rtcall axion_strcat "axion: contract violated: `withdraw` requires `0 <= amount && amount <= balance`" " (balance = "  ; Δ{} · makes String
        let _t6 = showInt contract$a1  ; Δ{_t5} · makes String
        let _t7 = rtcall axion_strcat _t5 _t6  ; Δ{_t5 _t6} · makes String
        let _t8 = rtcall axion_strcat _t7 ", amount = "  ; Δ{_t7} · makes String
        let _t9 = showInt contract$a2  ; Δ{_t8} · makes String
        ret 0  ; Δ{}
        ret _d1000001  ; Δ{}
        ret call <=$Int contract$a2 contract$a1  ; Δ{}
        ret call withdraw contract$a1 contract$a2  ; Δ{}
      drop _t13 : String
      else
      else
      let _d1000000 = putStrLn _t13  ; Δ{_t13}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t12 = if _t4 then
      let _t13 = showInt _t12  ; Δ{} · makes String
      let _t3 = call <=$Int 0 contract$a2  ; Δ{}
      let _t4 = if _t3 then
      let contract$a1 = 10  ; Δ{}
      let contract$a2 = call digits "a long string"  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{}
    _ ->
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1 : String
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = < x y  ; Δ{}
  let _t0 = call withdraw 10 3  ; Δ{}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret - balance amount  ; Δ{}
  ret 0  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret case _t2 of
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_str_len s  ; Δ{}
<=$Int x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
digits s  =
le$Int x y  =
main  =
withdraw balance amount  =
