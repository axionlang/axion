











          ret call sndof h  ; Δ{}
        (h, rest) ->
      drop t : tuple2$String$Int
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple2$String$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_tuple2$tuple2$String$Int$List$tuple2$String$Int _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_tuple2$String$Int _dd2  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret b  ; Δ{}
      ret case p of
    (a, b) ->
    Just p ->
    Nothing ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : Maybe$tuple2$tuple2$String$Int$List$tuple2$String$Int
  drop _t2 : String
  else
  else
  else
  let _d1000000 = putStr _t2  ; Δ{_t2}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_List$tuple2$String$Int _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = call axion_drop_tuple2$String$Int _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call build 5  ; Δ{} · makes Maybe$tuple2$tuple2$String$Int$List$tuple2$String$Int
  let _t0 = call mk n  ; Δ{} · makes tuple2$String$Int
  let _t1 = + n 1  ; Δ{_t0}
  let _t1 = call pick _t0  ; Δ{_t0}
  let _t2 = call mk _t1  ; Δ{_t0} · makes tuple2$String$Int
  let _t2 = call show$Int _t1  ; Δ{} · makes String
  let _t3 = con Nil  ; Δ{_t0 _t2} · makes List$tuple2$String$Int
  let _t4 = con Cons _t2 _t3  ; Δ{_t0 _t2 _t3} · moves{_t2 _t3} · makes List$tuple2$String$Int
  let _t5 = tuple _t0 _t4  ; Δ{_t0 _t4} · moves{_t0 _t4} · makes heap
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case m of
  ret case t of
  ret con Just _t5  ; Δ{_t5} · moves{_t5} · makes Maybe$tuple2$tuple2$String$Int$List$tuple2$String$Int
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret tuple "k" n  ; Δ{} · makes heap
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$tuple2$String$Int _p  =
axion_drop_Maybe$tuple2$tuple2$String$Int$List$tuple2$String$Int _p  =
axion_drop_tuple2$String$Int _p  =
axion_drop_tuple2$tuple2$String$Int$List$tuple2$String$Int _p  =
build n  =
main  =
mk n  =
pick m  =
show$Int x  =
sndof t  =
