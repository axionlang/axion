
















                                      drop _t36 : String
                                      drop _t38 : tuple2$Maybe$String$Int
                                      drop _t39 : String
                                      drop _t40 : String
                                      drop q : tuple2$Maybe$String$Int
                                      let _d1000000 = putStrLn _t40  ; Δ{_t40}
                                      let _t36 = call pick q  ; Δ{q} · makes String
                                      let _t37 = con Just "w"  ; Δ{_t36} · makes Maybe$String
                                      let _t38 = tuple _t37 0  ; Δ{_t36 _t37} · moves{_t37} · makes heap
                                      let _t39 = call pick _t38  ; Δ{_t36 _t38} · makes String
                                      let _t40 = rtcall axion_strcat _t36 _t39  ; Δ{_t36 _t39} · makes String
                                      ret _d1000000  ; Δ{}
                                    _ ->
                                  drop _t34 : String
                                  let _t33 = con Just "q"  ; Δ{} · makes Maybe$String
                                  let _t34 = call pick q  ; Δ{q} · makes String
                                  let _t35 = putStrLn _t34  ; Δ{_t34 q}
                                  let q = tuple _t33 2  ; Δ{_t33} · moves{_t33} · makes heap
                                  ret case _t35 of
                                _ ->
                              drop _t31 : String
                              drop p : tuple2$String$Int
                              let _t30 = call fstS p  ; Δ{p}
                              let _t31 = rtcall axion_strcat _t30 "?"  ; Δ{p} · makes String
                              let _t32 = putStrLn _t31  ; Δ{_t31}
                              ret case _t32 of
                            _ ->
                          let _t28 = call fstS p  ; Δ{p}
                          let _t29 = putStrLn _t28  ; Δ{p}
                          let p = tuple "hi" 3  ; Δ{} · makes heap
                          ret case _t29 of
                        _ ->
                      drop _t26 : String
                      drop ss : List$String
                      let _t25 = call length ss  ; Δ{ss}
                      let _t26 = call show$Int _t25  ; Δ{} · makes String
                      let _t27 = putStrLn _t26  ; Δ{_t26}
                      ret case _t27 of
                    _ ->
                  drop _t22 : String
                  drop _t23 : String
                  let _t22 = call label ss  ; Δ{ss} · makes String
                  let _t23 = rtcall axion_strcat _t22 "!"  ; Δ{_t22 ss} · makes String
                  let _t24 = putStrLn _t23  ; Δ{_t23 ss}
                  ret case _t24 of
                _ ->
              drop _t20 : String
              let $fieldcopy0 = rtcall axion_strcat s ""  ; Δ{} · makes String
              let _t18 = con Nil  ; Δ{} · makes List$String
              let _t19 = con Cons "beta" _t18  ; Δ{_t18} · moves{_t18} · makes List$String
              let _t20 = call label ss  ; Δ{ss} · makes String
              let _t21 = putStrLn _t20  ; Δ{_t20 ss}
              let ss = con Cons "alpha" _t19  ; Δ{_t19} · moves{_t19} · makes List$String
              ret "e"  ; Δ{}
              ret "zero"  ; Δ{}
              ret $fieldcopy0  ; Δ{$fieldcopy0} · moves{$fieldcopy0}
              ret case _t21 of
            0 ->
            2 ->
            _ ->
            _ ->
          drop _t16 : String
          drop d : Box
          drop xs : List$Box
          let $fieldcopy0 = call axion_copy_Box b  ; Δ{} · makes Box
          let _t15 = call total xs  ; Δ{xs}
          let _t16 = call show$Int _t15  ; Δ{} · makes String
          let _t17 = putStrLn _t16  ; Δ{_t16}
          ret "e"  ; Δ{}
          ret $fieldcopy0  ; Δ{$fieldcopy0} · moves{$fieldcopy0}
          ret case $nf2 of
          ret case _t17 of
          ret d  ; Δ{}
        Cons b _ ->
        Just s ->
        _ ->
        _ ->
        _ ->
      drop _t11 : Box
      drop _t13 : String
      let $fieldcopy0 = call axion_copy_Box b  ; Δ{} · makes Box
      let $fieldcopy0 = rtcall axion_strcat s ""  ; Δ{} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Box _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_free _dd2  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call val b  ; Δ{}
      let _t1 = call total rest  ; Δ{}
      let _t10 = con Box 1  ; Δ{xs} · makes Box
      let _t11 = call secondOr _t10 xs  ; Δ{_t10 xs} · moves{_t10} · makes Box
      let _t12 = call val _t11  ; Δ{_t11 xs}
      let _t13 = call show$Int _t12  ; Δ{xs} · makes String
      let _t14 = putStrLn _t13  ; Δ{_t13 xs}
      ret "none"  ; Δ{}
      ret $fieldcopy0  ; Δ{$fieldcopy0} · moves{$fieldcopy0}
      ret $fieldcopy0  ; Δ{$fieldcopy0} · moves{$fieldcopy0}
      ret + 1 _t0  ; Δ{}
      ret + _t0 _t1  ; Δ{}
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
      ret a  ; Δ{}
      ret case $nf1 of
      ret case $nf1 of
      ret case _t14 of
      ret con Box 0  ; Δ{} · makes Box
      ret d  ; Δ{}
      ret n  ; Δ{}
    ($nf1, $nf2) ->
    (a, _) ->
    Box n ->
    Cons _ $nf1 ->
    Cons b _ ->
    Cons b rest ->
    Cons s _ ->
    Cons y ys ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    _ ->
    _ ->
    else
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
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
  ; Δ{p}
  ; Δ{q}
  ; Δ{ss}
  ; Δ{ss}
  ; Δ{xs}
  ; Δ{xs}
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
  ; Δ{}
  drop _t6 : Box
  drop _t8 : String
  else
  else
  else
  else
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd1 = call axion_drop_Maybe$String _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = con Box 5  ; Δ{} · makes Box
  let _t1 = con Box 6  ; Δ{_t0} · makes Box
  let _t2 = con Box 7  ; Δ{_t0 _t1} · makes Box
  let _t3 = con Nil  ; Δ{_t0 _t1 _t2} · makes List$Box
  let _t4 = con Cons _t2 _t3  ; Δ{_t0 _t1 _t2 _t3} · moves{_t2 _t3} · makes List$Box
  let _t5 = con Cons _t1 _t4  ; Δ{_t0 _t1 _t4} · moves{_t1 _t4} · makes List$Box
  let _t6 = call firstOr xs  ; Δ{xs} · makes Box
  let _t7 = call val _t6  ; Δ{_t6 xs}
  let _t8 = call show$Int _t7  ; Δ{xs} · makes String
  let _t9 = putStrLn _t8  ; Δ{_t8 xs}
  let xs = con Cons _t0 _t5  ; Δ{_t0 _t5} · moves{_t0 _t5} · makes List$Box
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case _t9 of
  ret case b of
  ret case ss of
  ret case t of
  ret case x of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Box _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$String _p  =
axion_drop_tuple2$Maybe$String$Int _p  =
axion_drop_tuple2$String$Int _p  =
firstOr xs  =
fstS t  =
label ss  =
length xs  =
main  =
pick x  =
secondOr d xs  =
show$Int x  =
total xs  =
val b  =
