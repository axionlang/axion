













            ret call lookup$String k ps  ; Δ{} · makes Maybe
            ret con Just b  ; Δ{}
          else
          let _t0 = call eq$String a k  ; Δ{}
          ret if _t0 then
        (a, b) ->
        ret 1  ; Δ{}
        ret call elemBy$String x ys  ; Δ{}
      drop m
      drop m
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple$String$Int _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_tuple$String$Int _dd2  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call eq$String x y  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret callclo f x  ; Δ{x} · moves{x}
      ret case p of
      ret con Nothing  ; Δ{}
      ret d  ; Δ{}
      ret if _t0 then
    Cons p ps ->
    Cons y ys ->
    Just x ->
    Nil ->
    Nil ->
    Nothing ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 16  ; Δ{}
    ret 2  ; Δ{}
    ret 4  ; Δ{}
    ret 8  ; Δ{}
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0
  drop _t17 : List$String
  drop _t21 : List$tuple$String$Int
  else
  else
  else
  else
  else
  else
  else
  else
  else
  let _d1000000 = call maybe d _t0 m  ; Δ{_t0}
  let _dd0 = band _p 1  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = rtcall axion_str_cmp "abc" "abc"  ; Δ{}
  let _t0 = rtcall axion_str_cmp x y  ; Δ{}
  let _t0 = tuple "apple" 1  ; Δ{} · makes heap
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = tuple "banana" 2  ; Δ{_t0} · makes heap
  let _t10 = + _t6 _t9  ; Δ{}
  let _t11 = rtcall axion_str_cmp "zzz" "apple"  ; Δ{}
  let _t12 = > _t11 0  ; Δ{}
  let _t13 = if _t12 then
  let _t14 = + _t10 _t13  ; Δ{}
  let _t15 = con Nil  ; Δ{} · makes List$String
  let _t16 = con Cons "banana" _t15  ; Δ{_t15} · moves{_t15} · makes List$String
  let _t17 = con Cons "apple" _t16  ; Δ{_t16} · moves{_t16} · makes List$String
  let _t18 = call elemBy$String "banana" _t17  ; Δ{_t17}
  let _t19 = if _t18 then
  let _t2 = con Nil  ; Δ{_t0 _t1} · makes List$tuple$String$Int
  let _t2 = if _t1 then
  let _t20 = + _t14 _t19  ; Δ{}
  let _t21 = call tbl  ; Δ{} · makes List$tuple$String$Int
  let _t22 = call lookup$String "banana" _t21  ; Δ{_t21} · makes Maybe$Int
  let _t23 = call fromMaybe 0 _t22  ; Δ{_t22} · moves{_t22}
  let _t24 = * _t23 32  ; Δ{}
  let _t3 = con Cons _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t1 _t2} · makes List$tuple$String$Int
  let _t3 = rtcall axion_str_cmp "abc" "abd"  ; Δ{}
  let _t4 = == _t3 0  ; Δ{}
  let _t5 = if _t4 then
  let _t6 = + _t2 _t5  ; Δ{}
  let _t7 = rtcall axion_str_cmp "apple" "banana"  ; Δ{}
  let _t8 = < _t7 0  ; Δ{}
  let _t9 = if _t8 then
  ret + _t20 _t24  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case m of
  ret case xs of
  ret case xs of
  ret con Cons _t0 _t3  ; Δ{_t0 _t3} · moves{_t0 _t3} · makes List$tuple$String$Int
  ret rtcall axion_array_free _p  ; Δ{}
  ret x  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
axion_drop_List$tuple$String$Int _p  =
axion_drop_Maybe$Int _p  =
axion_drop_tuple$String$Int _p  =
elemBy$String x xs  =
eq$String x y  =
fromMaybe d m  =
lam$0 [env ]x  =
lookup$String k xs  =
main  =
maybe d f m  =
tbl  =
