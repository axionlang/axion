




      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t4 : String
  else
  let _d1000000 = putStrLn _t4  ; Δ{_t4}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_strcat "hello " "world"  ; Δ{} · makes String
  let _t1 = - a a  ; Δ{}
  let _t1 = call give _t0  ; Δ{_t0} · moves{_t0}
  let _t2 = + _t0 _t1  ; Δ{}
  let _t2 = call borrowTwice "kept"  ; Δ{}
  let _t3 = - b b  ; Δ{}
  let _t3 = - total total  ; Δ{}
  let _t4 = showInt _t3  ; Δ{} · makes String
  let a = ffi c_read_string s  ; Δ{}
  let b = ffi c_read_string s  ; Δ{}
  let total = + _t1 _t2  ; Δ{}
  ret + _t2 _t3  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret ffi c_take_string s [o]  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
borrowTwice s  =
give s  =
main  =
