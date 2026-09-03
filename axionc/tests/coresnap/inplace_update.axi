



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
  drop c1 : Cell
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let c0 = record Cell { val = 1}  ; Δ{} · makes Cell
  let c1 = call bump c0  ; Δ{c0} · moves{c0} · makes Cell
  let r = field val c1  ; Δ{c1}
  ret 0  ; Δ{}
  ret r  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret update! c { val = 99}  ; Δ{} · makes heap
axion_drop_Array _p  =
axion_drop_List _p  =
bump c  =
main  =
