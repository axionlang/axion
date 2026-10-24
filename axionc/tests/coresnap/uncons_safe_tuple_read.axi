











          ret call length rest  ; Δ{}
        (h, rest) ->
      drop xs
      drop xs : List$tuple2$String$Int
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple2$String$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_tuple2$tuple2$String$Int$List$tuple2$String$Int _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_tuple2$String$Int _dd2  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = tuple y ys  ; Δ{y ys} · moves{y ys} · makes heap
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case p of
      ret con Just _t0  ; Δ{_t0} · moves{_t0}
      ret con Nothing  ; Δ{}
    Cons y ys ->
    Cons y ys ->
    Just p ->
    Nil ->
    Nil ->
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
  ; Δ{}
  drop _t5 : Maybe$tuple2$tuple2$String$Int$List$tuple2$String$Int
  drop _t7 : String
  else
  else
  else
  let _d1000000 = putStr _t7  ; Δ{_t7}
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
  let _t0 = call mkp 5  ; Δ{} · makes tuple2$String$Int
  let _t1 = call mkp 6  ; Δ{_t0} · makes tuple2$String$Int
  let _t2 = con Nil  ; Δ{_t0 _t1} · makes List$tuple2$String$Int
  let _t3 = con Cons _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t1 _t2} · makes List$tuple2$String$Int
  let _t4 = con Cons _t0 _t3  ; Δ{_t0 _t3} · moves{_t0 _t3} · makes List$tuple2$String$Int
  let _t5 = call uncons$(String,Int) _t4  ; Δ{_t4} · moves{_t4} · makes Maybe$tuple2$tuple2$String$Int$List$tuple2$String$Int
  let _t6 = call pick _t5  ; Δ{_t5}
  let _t7 = call show$Int _t6  ; Δ{} · makes String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case m of
  ret case xs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret tuple "k" n  ; Δ{} · makes heap
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$tuple2$String$Int _p  =
axion_drop_Maybe$tuple2$tuple2$String$Int$List$tuple2$String$Int _p  =
axion_drop_tuple2$String$Int _p  =
axion_drop_tuple2$tuple2$String$Int$List$tuple2$String$Int _p  =
length xs  =
main  =
mkp n  =
pick m  =
show$Int x  =
uncons$(String,Int) xs  =
