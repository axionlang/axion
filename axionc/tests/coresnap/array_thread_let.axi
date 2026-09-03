




      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + i 1  ; Δ{a2}
    let _t1 = + i 1  ; Δ{}
    let _t2 = rtcall axion_array_get a i  ; Δ{}
    let _t3 = + acc _t2  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let a2 = rtcall axion_array_set a i i  ; Δ{} · makes Array
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret a  ; Δ{}
    ret acc  ; Δ{}
    ret call fill a2 _t1 n  ; Δ{a2} · moves{a2} · makes Array
    ret call sumArr a _t1 n _t3  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop a$1 : Array
  else
  else
  else
  let _d1000000 = call sumArr a$1 0 100 0  ; Δ{a$1}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = == i n  ; Δ{}
  let _t0 = == i n  ; Δ{}
  let a = newArray 100 0  ; Δ{} · makes Array
  let a$1 = call fill a 0 100  ; Δ{a} · moves{a} · makes Array
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
fill a i n  =
main  =
sumArr a i n acc  =
