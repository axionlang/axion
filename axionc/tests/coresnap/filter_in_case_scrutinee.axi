









              drop m : tuple2$String$Int
              let _d1000000 = + b _t1  ; Δ{m}
              let _t1 = rtcall axion_str_len a  ; Δ{m}
              ret _d1000000  ; Δ{}
            (a, b) ->
          drop _t0
          drop _t0 : List$tuple2$String$Int
          drop rest : List$tuple2$String$Int
          ret 0  ; Δ{}
          ret case m of
        Cons m rest ->
        Nil ->
        drop y : tuple2$String$Int
        let _t1 = call filter$$keyIs _cap0 ys  ; Δ{y ys} · moves{ys} · makes List$tuple2$String$Int
        ret call filter$$keyIs _cap0 ys  ; Δ{ys} · moves{ys} · makes List$tuple2$String$Int
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$tuple2$String$Int
      drop v
      drop v : J
      drop xs
      drop xs
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple2$String$Int _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_tuple2$String$Int _dd2  ; Δ{}
      let _t0 = call filter$$keyIs k ms  ; Δ{ms} · moves{ms} · makes List$tuple2$String$Int
      let _t0 = call keyIs _cap0 y  ; Δ{y ys}
      let _t0 = rtcall axion_str_cmp a k  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret == _t0 0  ; Δ{}
      ret case _t0 of
      ret con Nil  ; Δ{} · makes List$tuple2$String$Int
      ret if _t0 then
    (a, b) ->
    Cons y ys ->
    JObj ms ->
    Nil ->
    else
    else
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = call axion_drop_List$tuple2$String$Int _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    other ->
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{_t0}
  ; Δ{m}
  ; Δ{y ys}
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
  else
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call show$Int 1  ; Δ{} · makes String
  let _t1 = tuple _t0 10  ; Δ{_t0} · moves{_t0} · makes heap
  let _t10 = con JObj _t9  ; Δ{_t9} · moves{_t9} · makes J
  let _t2 = call show$Int 2  ; Δ{_t1} · makes String
  let _t3 = tuple _t2 20  ; Δ{_t1 _t2} · moves{_t2} · makes heap
  let _t4 = call show$Int 3  ; Δ{_t1 _t3} · makes String
  let _t5 = tuple _t4 30  ; Δ{_t1 _t3 _t4} · moves{_t4} · makes heap
  let _t6 = con Nil  ; Δ{_t1 _t3 _t5} · makes List$tuple2$String$Int
  let _t7 = con Cons _t5 _t6  ; Δ{_t1 _t3 _t5 _t6} · moves{_t5 _t6} · makes List$tuple2$String$Int
  let _t8 = con Cons _t3 _t7  ; Δ{_t1 _t3 _t7} · moves{_t3 _t7} · makes List$tuple2$String$Int
  let _t9 = con Cons _t1 _t8  ; Δ{_t1 _t8} · moves{_t1 _t8} · makes List$tuple2$String$Int
  let _tag = loadraw _p+0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call field "2" _t10  ; Δ{_t10} · moves{_t10}
  ret case m of
  ret case v of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_J _p  =
axion_drop_List _p  =
axion_drop_List$tuple2$String$Int _p  =
axion_drop_tuple2$String$Int _p  =
field k v  =
filter$$keyIs _cap0 xs  =
keyIs k m  =
main  =
show$Int x  =
