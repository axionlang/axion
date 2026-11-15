











        drop y : String
        drop y : String
        drop y : String
        drop ys : List$String
        let _t1 = call filter$$hoflam14 ys  ; Δ{y ys} · moves{ys} · makes List$String
        let _t1 = call takeWhile$$hoflam10 ys  ; Δ{y ys} · moves{ys} · makes List$String
        ret call dropWhile$$hoflam12 ys  ; Δ{ys} · moves{ys} · makes List$String
        ret call filter$$hoflam14 ys  ; Δ{ys} · moves{ys} · makes List$String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
        ret con Cons y ys  ; Δ{y ys} · moves{y ys} · makes List$String
        ret con Nil  ; Δ{} · makes List$String
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      else
      else
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call hoflam10 y  ; Δ{y ys}
      let _t0 = call hoflam12 y  ; Δ{y ys}
      let _t0 = call hoflam14 y  ; Δ{y ys}
      let _t0 = call length ys  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
  ; Δ{y ys}
  ; Δ{y ys}
  ; Δ{y ys}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t1 : List$String
  drop _t4 : List$String
  drop _t8 : List$String
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = call names  ; Δ{} · makes List$String
  let _t0 = con Nil  ; Δ{} · makes List$String
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = call takeWhile$$hoflam10 _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t1 = con Cons "dd" _t0  ; Δ{_t0} · moves{_t0} · makes List$String
  let _t2 = call length _t1  ; Δ{_t1}
  let _t2 = con Cons "c" _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t3 = call names  ; Δ{} · makes List$String
  let _t3 = con Cons "bb" _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  let _t4 = call dropWhile$$hoflam12 _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  let _t5 = call length _t4  ; Δ{_t4}
  let _t6 = + _t2 _t5  ; Δ{}
  let _t7 = call names  ; Δ{} · makes List$String
  let _t8 = call filter$$hoflam14 _t7  ; Δ{_t7} · moves{_t7} · makes List$String
  let _t9 = call length _t8  ; Δ{_t8}
  ret + _t6 _t9  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret > _t0 1  ; Δ{}
  ret > _t0 1  ; Δ{}
  ret > _t0 1  ; Δ{}
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Cons "aa" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
dropWhile$$hoflam12 xs  =
filter$$hoflam14 xs  =
hoflam10 s  =
hoflam12 s  =
hoflam14 s  =
length xs  =
main  =
names  =
takeWhile$$hoflam10 xs  =
