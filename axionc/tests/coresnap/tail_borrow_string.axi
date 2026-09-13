




          drop _t6 : String
          drop _t8 : String
          let _d1000000 = putStrLn _t8  ; Δ{_t8}
          let _t6 = rtcall axion_strcat "x" "3"  ; Δ{} · makes String
          let _t7 = rtcall axion_strcat "y" "4"  ; Δ{_t6} · makes String
          let _t8 = call joinP _t6 _t7  ; Δ{_t6 _t7} · moves{_t7} · makes String
          ret _d1000000  ; Δ{}
        _ ->
      drop _t3 : String
      drop _t4 : String
      drop b : String
      drop b : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _rcl2000000 = rtcall axion_strcat a b  ; Δ{} · makes String
      let _t3 = rtcall axion_strcat "p" "2"  ; Δ{} · makes String
      let _t4 = call joinP _t3 ""  ; Δ{_t3} · makes String
      let _t5 = putStrLn _t4  ; Δ{_t4}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _rcl2000000  ; Δ{_rcl2000000} · moves{_rcl2000000}
      ret call wrap a  ; Δ{} · makes String
      ret case _t5 of
    _ ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t2 = rtcall axion_str_len b  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret b  ; Δ{}
    ret if _t3 then
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  drop _t1 : String
  else
  else
  let _d1000000 = rtcall axion_strcat "<" _t0  ; Δ{_t0} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = rtcall axion_str_len a  ; Δ{}
  let _t0 = rtcall axion_strcat "h" "1"  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat s ">"  ; Δ{} · makes String
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = call joinP "" _t0  ; Δ{_t0} · moves{_t0} · makes String
  let _t2 = putStrLn _t1  ; Δ{_t1}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret case _t2 of
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
joinP a b  =
main  =
wrap s  =
