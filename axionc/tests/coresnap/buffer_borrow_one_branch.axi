



        ret _t4  ; Δ{}
      _ ->
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    drop b : Buffer
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t3 = * p 0  ; Δ{b}
    let _t4 = + _t3 got  ; Δ{b}
    let _t5 = rtcall axion_buf_free b  ; Δ{b} · moves{b}
    let _tag = loadraw _p+0  ; Δ{}
    let p = rtcall axion_buf_ptr b  ; Δ{b}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret case _t5 of
  ; Δ{b}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1 : String
  drop _t3 : String
  drop _t4 : String
  drop _t5 : String
  else
  else
  let _d1000000 = putStrLn _t5  ; Δ{_t5}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = call use 2  ; Δ{}
  let _t0 = rtcall axion_poke_u64 b 0 k  ; Δ{b}
  let _t1 = rtcall axion_peek_u64 b 0  ; Δ{b}
  let _t1 = showInt _t0  ; Δ{} · makes String
  let _t2 = < got 4  ; Δ{b}
  let _t2 = call use 9  ; Δ{_t1}
  let _t3 = showInt _t2  ; Δ{_t1} · makes String
  let _t4 = rtcall axion_strcat " " _t3  ; Δ{_t1 _t3} · makes String
  let _t5 = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
  let b = rtcall axion_buf_new 16  ; Δ{} · makes Buffer
  let got = + _t0 _t1  ; Δ{b}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret if _t2 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
use k  =
