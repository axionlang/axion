
















                                                          drop _t70 : tuple2$String$Int
                                                          drop _t71 : String
                                                          drop _t72 : String
                                                          let _d1000000 = putStrLn _t72  ; Δ{_t70 _t72}
                                                          let _t71 = showInt n  ; Δ{_t70} · makes String
                                                          let _t72 = rtcall axion_strcat s _t71  ; Δ{_t70 _t71} · makes String
                                                          ret _d1000000  ; Δ{}
                                                        (s, n) ->
                                                      drop _t69 : Op
                                                      let _t69 = con Sub 7  ; Δ{} · makes Op
                                                      let _t70 = call pairUp _t69  ; Δ{_t69} · makes tuple2$String$Int
                                                      ret case _t70 of
                                                    _ ->
                                                  drop _t59 : Op
                                                  drop _t61 : Op
                                                  drop _t64 : Op
                                                  drop _t67 : String
                                                  let _t59 = con Add 2  ; Δ{} · makes Op
                                                  let _t60 = call apply _t59 5  ; Δ{_t59}
                                                  let _t61 = con Sub 3  ; Δ{} · makes Op
                                                  let _t62 = call apply _t61 5  ; Δ{_t61}
                                                  let _t63 = + _t60 _t62  ; Δ{}
                                                  let _t64 = con Mul 4  ; Δ{} · makes Op
                                                  let _t65 = call apply _t64 5  ; Δ{_t64}
                                                  let _t66 = + _t63 _t65  ; Δ{}
                                                  let _t67 = showInt _t66  ; Δ{} · makes String
                                                  let _t68 = putStrLn _t67  ; Δ{_t67}
                                                  ret case _t68 of
                                                _ ->
                                              drop _t56 : tuple2$Int$Int
                                              drop _t57 : String
                                              let _t56 = tuple 2 0  ; Δ{} · makes heap
                                              let _t57 = call grid _t56  ; Δ{_t56} · makes String
                                              let _t58 = putStrLn _t57  ; Δ{_t57}
                                              ret case _t58 of
                                            _ ->
                                          drop _t53 : tuple2$Int$Int
                                          drop _t54 : String
                                          let _t53 = tuple 1 0  ; Δ{} · makes heap
                                          let _t54 = call grid _t53  ; Δ{_t53} · makes String
                                          let _t55 = putStrLn _t54  ; Δ{_t54}
                                          ret case _t55 of
                                        _ ->
                                      drop _t51 : String
                                      let _t48 = con Nothing  ; Δ{} · makes Maybe$String
                                      let _t49 = con Nothing  ; Δ{_t48} · makes Maybe$String
                                      let _t50 = tuple _t48 _t49  ; Δ{_t48 _t49} · moves{_t48 _t49} · makes heap
                                      let _t51 = call firstName _t50  ; Δ{_t50} · moves{_t50} · makes String
                                      let _t52 = putStrLn _t51  ; Δ{_t51}
                                      ret case _t52 of
                                    _ ->
                                  drop _t46 : String
                                  let _t43 = con Just "al"  ; Δ{} · makes Maybe$String
                                  let _t44 = con Just "x"  ; Δ{_t43} · makes Maybe$String
                                  let _t45 = tuple _t43 _t44  ; Δ{_t43 _t44} · moves{_t43 _t44} · makes heap
                                  let _t46 = call firstName _t45  ; Δ{_t45} · moves{_t45} · makes String
                                  let _t47 = putStrLn _t46  ; Δ{_t46}
                                  ret case _t47 of
                                _ ->
                              drop _t41 : String
                              let _t38 = con Nothing  ; Δ{} · makes Maybe$String
                              let _t39 = con Just "bo"  ; Δ{_t38} · makes Maybe$String
                              let _t40 = tuple _t38 _t39  ; Δ{_t38 _t39} · moves{_t38 _t39} · makes heap
                              let _t41 = call firstName _t40  ; Δ{_t40} · moves{_t40} · makes String
                              let _t42 = putStrLn _t41  ; Δ{_t41}
                              ret case _t42 of
                            _ ->
                          drop _t35 : Maybe$String
                          drop _t36 : String
                          let _t35 = con Just "zz"  ; Δ{} · makes Maybe$String
                          let _t36 = call label _t35  ; Δ{_t35} · makes String
                          let _t37 = putStrLn _t36  ; Δ{_t36}
                          ret case _t37 of
                        _ ->
                      drop _t32 : Maybe$String
                      drop _t33 : String
                      let _t32 = con Just "b"  ; Δ{} · makes Maybe$String
                      let _t33 = call label _t32  ; Δ{_t32} · makes String
                      let _t34 = putStrLn _t33  ; Δ{_t33}
                      ret case _t34 of
                    _ ->
                  drop _t29 : Maybe$Int
                  drop _t30 : String
                  let _t29 = con Nothing  ; Δ{} · makes Maybe$Int
                  let _t30 = call small _t29  ; Δ{_t29} · makes String
                  let _t31 = putStrLn _t30  ; Δ{_t30}
                  ret case _t31 of
                _ ->
              drop $nf2
              drop $nf2
              drop _t26 : Maybe$Int
              drop _t27 : String
              let _t26 = con Just 9  ; Δ{} · makes Maybe$Int
              let _t27 = call small _t26  ; Δ{_t26} · makes String
              let _t28 = putStrLn _t27  ; Δ{_t27}
              ret "anon"  ; Δ{p}
              ret "corner"  ; Δ{}
              ret "corner"  ; Δ{}
              ret "corner"  ; Δ{}
              ret "corner"  ; Δ{}
              ret "far"  ; Δ{}
              ret "far"  ; Δ{}
              ret case _t28 of
              ret n$1  ; Δ{p}
            0 ->
            0 ->
            1 ->
            1 ->
            Just n$1 ->
            Nothing ->
            _ ->
            _ ->
            _ ->
          drop $nf1
          drop $nf1
          drop $nf2 : Maybe$String
          drop _t23 : Maybe$Int
          drop _t24 : String
          let $fieldcopy0 = rtcall axion_strcat s ""  ; Δ{} · makes String
          let _t23 = con Just 2  ; Δ{} · makes Maybe$Int
          let _t24 = call small _t23  ; Δ{_t23} · makes String
          let _t25 = putStrLn _t24  ; Δ{_t24}
          ret "ab"  ; Δ{}
          ret "far"  ; Δ{}
          ret "other"  ; Δ{}
          ret "small"  ; Δ{}
          ret "small"  ; Δ{}
          ret "small"  ; Δ{}
          ret $fieldcopy0  ; Δ{$fieldcopy0} · moves{$fieldcopy0}
          ret case $nf2 of
          ret case $nf2 of
          ret case $nf2 of
          ret case _t25 of
          ret n  ; Δ{p}
        0 ->
        1 ->
        1 ->
        2 ->
        3 ->
        Just n ->
        Nothing ->
        _ ->
        _ ->
        _ ->
        else
        let _t2 = rtcall axion_str_cmp s "b"  ; Δ{}
        let _t3 = == _t2 0  ; Δ{}
        ret "ab"  ; Δ{}
        ret if _t3 then
      drop _t0
      drop _t1
      drop _t10 : Shape
      drop _t12 : Shape
      drop _t15 : Shape
      drop _t18 : Shape
      drop _t21 : String
      drop p : tuple2$Maybe$String$Maybe$String skip{0 1}
      else
      let _d1000000 = callclo _t0 v  ; Δ{_t0}
      let _d1000001 = callclo _t1 v  ; Δ{_t1}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
      let _t0 = closure lam$0 k  ; Δ{} · makes Closure
      let _t0 = rtcall axion_str_cmp s "a"  ; Δ{}
      let _t0 = showInt k  ; Δ{} · makes String
      let _t1 = == _t0 0  ; Δ{}
      let _t1 = closure lam$0 k$1  ; Δ{} · makes Closure
      let _t1 = showInt k$1  ; Δ{} · makes String
      let _t10 = con Circle 3  ; Δ{} · makes Shape
      let _t11 = call size _t10  ; Δ{_t10}
      let _t12 = con Square 4  ; Δ{} · makes Shape
      let _t13 = call size _t12  ; Δ{_t12}
      let _t14 = + _t11 _t13  ; Δ{}
      let _t15 = con Rect 2 5  ; Δ{} · makes Shape
      let _t16 = call size _t15  ; Δ{_t15}
      let _t17 = + _t14 _t16  ; Δ{}
      let _t18 = con Dot  ; Δ{} · makes Shape
      let _t19 = call size _t18  ; Δ{_t18}
      let _t2 = showInt k$2  ; Δ{} · makes String
      let _t20 = + _t17 _t19  ; Δ{}
      let _t21 = showInt _t20  ; Δ{} · makes String
      let _t22 = putStrLn _t21  ; Δ{_t21}
      ret "none"  ; Δ{}
      ret "other"  ; Δ{}
      ret * v k$2  ; Δ{}
      ret * w h  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret _d1000000  ; Δ{}
      ret _d1000001  ; Δ{}
      ret case $nf1 of
      ret case $nf1 of
      ret case $nf1 of
      ret case _t22 of
      ret if _t1 then
      ret n  ; Δ{}
      ret n$1  ; Δ{}
      ret tuple _t0 k  ; Δ{_t0} · moves{_t0} · makes heap
      ret tuple _t1 k$1  ; Δ{_t1} · moves{_t1} · makes heap
      ret tuple _t2 k$2  ; Δ{_t2} · moves{_t2} · makes heap
    ($nf1, $nf2) ->
    ($nf1, $nf2) ->
    Add k ->
    Add k ->
    Circle n ->
    Dot ->
    Green ->
    Just $nf1 ->
    Just s ->
    Mul k$2 ->
    Mul k$2 ->
    Nothing ->
    Nothing ->
    Rect w h ->
    Red ->
    Square n$1 ->
    Sub k$1 ->
    Sub k$1 ->
    _ ->
    _ ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
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
  ; Δ{_t70}
  ; Δ{p}
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
  drop _t8 : String
  else
  else
  else
  let _dd0 = band _p 1  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_Maybe$String _dd0  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = call axion_drop_Maybe$String _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = con Red  ; Δ{}
  let _t1 = call warm _t0  ; Δ{}
  let _t2 = con Green  ; Δ{}
  let _t3 = call warm _t2  ; Δ{}
  let _t4 = + _t1 _t3  ; Δ{}
  let _t5 = con Blue  ; Δ{}
  let _t6 = call warm _t5  ; Δ{}
  let _t7 = + _t4 _t6  ; Δ{}
  let _t8 = showInt _t7  ; Δ{} · makes String
  let _t9 = putStrLn _t8  ; Δ{_t8}
  ret + y k  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret case _t9 of
  ret case c of
  ret case m of
  ret case m of
  ret case o of
  ret case o of
  ret case p of
  ret case p of
  ret case s of
  ret rtcall axion_array_free _p  ; Δ{}
apply o v  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Maybe$Int _p  =
axion_drop_Maybe$String _p  =
axion_drop_tuple2$Int$Int _p  =
axion_drop_tuple2$Maybe$String$Maybe$String _p  =
axion_drop_tuple2$String$Int _p  =
firstName p  =
grid p  =
label m  =
lam$0 [env k]y  =
main  =
pairUp o  =
size s  =
small m  =
warm c  =
