













                          drop _t33 : String
                          drop p : tuple2$String$Int skip{0}
                          drop s$2 : String
                          let _d1000000 = rtcall axion_strcat s$2 _t33  ; Δ{_t33 p} · makes String
                          let _t33 = showInt k  ; Δ{p} · makes String
                          ret _d1000000  ; Δ{_d1000000 p} · moves{_d1000000}
                        (s$2, k) ->
                      drop _t19 : String
                      drop _t21 : String
                      drop _t34 : String
                      let _rcl2000000 = putStrLn _t34  ; Δ{p}
                      let _t32 = call mk 8  ; Δ{} · makes String
                      let _t34 = case p of
                      let p = tuple _t32 8  ; Δ{_t32} · moves{_t32} · makes heap
                      ret _rcl2000000  ; Δ{p}
                    _ ->
                  drop _t28 : List$String
                  drop _t30 : String
                  drop m
                  drop m
                  drop s$1 : Sh
                  drop t : Maybe$List$String
                  let _d1000001 = call rSh s$1  ; Δ{s$1} · makes String
                  let _t23 = call mk 6  ; Δ{} · makes String
                  let _t24 = call mk 7  ; Δ{_t23} · makes String
                  let _t25 = con Nil  ; Δ{_t23 _t24} · makes List$String
                  let _t26 = con Cons _t24 _t25  ; Δ{_t23 _t24 _t25} · moves{_t24 _t25} · makes List$String
                  let _t27 = con Cons _t23 _t26  ; Δ{_t23 _t26} · moves{_t23 _t26} · makes List$String
                  let _t28 = call tailOf t  ; Δ{t} · makes List$String
                  let _t29 = call length _t28  ; Δ{_t28}
                  let _t30 = showInt _t29  ; Δ{} · makes String
                  let _t31 = putStrLn _t30  ; Δ{_t30}
                  let t = con Just _t27  ; Δ{_t27} · moves{_t27} · makes Maybe$List$String
                  ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
                  ret case _t31 of
                  ret rtcall axion_strcat "-" ""  ; Δ{} · makes String
                Just s$1 ->
                Nothing ->
                _ ->
              drop _t18
              drop _t18
              drop s : Sh
              let _d1000002 = call rSh s  ; Δ{m s} · makes String
              let _t21 = case m of
              let _t22 = putStrLn _t21  ; Δ{}
              ret _d1000002  ; Δ{_d1000002 m} · moves{_d1000002}
              ret case _t22 of
              ret rtcall axion_strcat "-" ""  ; Δ{m} · makes String
            Just s ->
            Nothing ->
            _ ->
          let $borrowcopy0 = call axion_copy_List$String rest  ; Δ{} · makes List$String
          let $borrowcopy0 = call axion_copy_Sh inner  ; Δ{} · makes Sh
          let $borrowcopy0 = rtcall axion_strcat s ""  ; Δ{_t0} · makes String
          let _t0 = con Nil  ; Δ{} · makes List$String
          let _t13 = call mk 4  ; Δ{} · makes String
          let _t14 = call mk 5  ; Δ{_t13} · makes String
          let _t15 = con Dot  ; Δ{_t13 _t14} · makes Sh
          let _t16 = con Tag _t14 _t15  ; Δ{_t13 _t14 _t15} · moves{_t14 _t15} · makes Sh
          let _t17 = con Tag _t13 _t16  ; Δ{_t13 _t16} · moves{_t13 _t16} · makes Sh
          let _t18 = call wrapSh m  ; Δ{m} · makes Maybe$Sh
          let _t19 = case _t18 of
          let _t20 = putStrLn _t19  ; Δ{m}
          let m = con Just _t17  ; Δ{_t17} · moves{_t17} · makes Maybe$Sh
          ret case _t20 of
          ret con Cons "k" $borrowcopy0  ; Δ{$borrowcopy0} · moves{$borrowcopy0} · makes List$String
          ret con Cons $borrowcopy0 _t0  ; Δ{$borrowcopy0 _t0} · moves{$borrowcopy0 _t0} · makes List$String
          ret con Just $borrowcopy0  ; Δ{$borrowcopy0} · moves{$borrowcopy0} · makes Maybe$Sh
          ret con Nil  ; Δ{} · makes List$String
          ret con Nil  ; Δ{} · makes List$String
          ret con Nothing  ; Δ{} · makes Maybe$Sh
        Cons _ rest ->
        Cons s _ ->
        Tag _ inner ->
        _ ->
        _ ->
        _ ->
        _ ->
      drop _t0 : String
      drop _t1 : String
      drop _t11 : String
      drop _t2 : String
      drop l : List$String
      let _d1000000 = rtcall axion_strcat t _t2  ; Δ{_t2} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = call axion_drop_Sh _dd0  ; Δ{}
      let _dd1 = call axion_drop_Sh _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call rSh inner  ; Δ{} · makes String
      let _t1 = rtcall axion_strcat _t0 ">"  ; Δ{_t0} · makes String
      let _t10 = call length l  ; Δ{l}
      let _t11 = showInt _t10  ; Δ{} · makes String
      let _t12 = putStrLn _t11  ; Δ{_t11}
      let _t2 = rtcall axion_strcat "<" _t1  ; Δ{_t1} · makes String
      ret "dot"  ; Δ{}
      ret + 1 _t0  ; Δ{}
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
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret case $nf1 of
      ret case $nf1 of
      ret case $nf1 of
      ret case _t12 of
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret con Nothing  ; Δ{} · makes Maybe$Sh
    Cons _ $nf1 ->
    Cons y ys ->
    Dot ->
    Just $nf1 ->
    Just $nf1 ->
    Nil ->
    Tag t inner ->
    _ ->
    _ ->
    _ ->
    _ ->
    else
    else
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
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
  ; Δ{_t18 m}
  ; Δ{l}
  ; Δ{m}
  ; Δ{m}
  ; Δ{p}
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  drop _t6 : List$String
  drop _t8 : String
  else
  else
  else
  else
  else
  let _d1000000 = rtcall axion_strcat "n" _t0  ; Δ{_t0} · makes String
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call mk 1  ; Δ{} · makes String
  let _t0 = showInt n  ; Δ{} · makes String
  let _t1 = call mk 2  ; Δ{_t0} · makes String
  let _t2 = call mk 3  ; Δ{_t0 _t1} · makes String
  let _t3 = con Nil  ; Δ{_t0 _t1 _t2} · makes List$String
  let _t4 = con Cons _t2 _t3  ; Δ{_t0 _t1 _t2 _t3} · moves{_t2 _t3} · makes List$String
  let _t5 = con Cons _t1 _t4  ; Δ{_t0 _t1 _t4} · moves{_t1 _t4} · makes List$String
  let _t6 = call second l  ; Δ{l} · makes List$String
  let _t7 = call length _t6  ; Δ{_t6 l}
  let _t8 = showInt _t7  ; Δ{l} · makes String
  let _t9 = putStrLn _t8  ; Δ{_t8 l}
  let l = con Cons _t0 _t5  ; Δ{_t0 _t5} · moves{_t0 _t5} · makes List$String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret case _t9 of
  ret case m of
  ret case m of
  ret case s of
  ret case xs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$List$String _p  =
axion_drop_Maybe$Sh _p  =
axion_drop_Sh _p  =
axion_drop_tuple2$String$Int _p  =
length xs  =
main  =
mk n  =
rSh s  =
second xs  =
tailOf m  =
wrapSh m  =
