


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
  drop r : Rec
  drop r2 : Rec skip{0}
  drop t
  else
  let _d1000000 = field f r2  ; Δ{r2}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let r = record Rec { f = 3 g = 4}  ; Δ{} · makes Rec
  let r2 = update r { g = 5}  ; Δ{r} · makes heap
  let t = tuple 1 2  ; Δ{} · makes heap
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{r2}
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
main  =
