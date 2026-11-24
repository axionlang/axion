



















                                  drop _t105 : String
                                  drop l3 : Lst
                                  let _d1000000 = putStrLn _t105  ; Δ{_t105}
                                  let _t102 = call total l3  ; Δ{l3}
                                  let _t103 = call headOr l3  ; Δ{l3}
                                  let _t104 = + _t102 _t103  ; Δ{}
                                  let _t105 = showInt _t104  ; Δ{} · makes String
                                  ret _d1000000  ; Δ{}
                                _ ->
                              drop _t100 : String
                              drop _t83 : Shape
                              drop _t84 : String
                              drop _t85 : Shape
                              drop _t86 : String
                              drop _t87 : Shape
                              drop _t88 : String
                              drop _t89 : Shape
                              drop _t90 : String
                              drop _t91 : Shape
                              drop _t92 : String
                              drop _t93 : String
                              drop _t94 : String
                              drop _t95 : String
                              drop _t96 : String
                              drop _t97 : String
                              drop _t98 : String
                              drop _t99 : String
                              let _t100 = rtcall axion_strcat _t84 _t99  ; Δ{_t84 _t99 l3} · makes String
                              let _t101 = putStrLn _t100  ; Δ{_t100 l3}
                              let _t83 = con Circle 20  ; Δ{l3} · makes Shape
                              let _t84 = call classify _t83  ; Δ{_t83 l3} · makes String
                              let _t85 = con Circle 2  ; Δ{_t84 l3} · makes Shape
                              let _t86 = call classify _t85  ; Δ{_t84 _t85 l3} · makes String
                              let _t87 = con Rect 3 3  ; Δ{_t84 _t86 l3} · makes Shape
                              let _t88 = call classify _t87  ; Δ{_t84 _t86 _t87 l3} · makes String
                              let _t89 = con Rect 1 2  ; Δ{_t84 _t86 _t88 l3} · makes Shape
                              let _t90 = call classify _t89  ; Δ{_t84 _t86 _t88 _t89 l3} · makes String
                              let _t91 = con Dot  ; Δ{_t84 _t86 _t88 _t90 l3} · makes Shape
                              let _t92 = call classify _t91  ; Δ{_t84 _t86 _t88 _t90 _t91 l3} · makes String
                              let _t93 = rtcall axion_strcat "," _t92  ; Δ{_t84 _t86 _t88 _t90 _t92 l3} · makes String
                              let _t94 = rtcall axion_strcat _t90 _t93  ; Δ{_t84 _t86 _t88 _t90 _t93 l3} · makes String
                              let _t95 = rtcall axion_strcat "," _t94  ; Δ{_t84 _t86 _t88 _t94 l3} · makes String
                              let _t96 = rtcall axion_strcat _t88 _t95  ; Δ{_t84 _t86 _t88 _t95 l3} · makes String
                              let _t97 = rtcall axion_strcat "," _t96  ; Δ{_t84 _t86 _t96 l3} · makes String
                              let _t98 = rtcall axion_strcat _t86 _t97  ; Δ{_t84 _t86 _t97 l3} · makes String
                              let _t99 = rtcall axion_strcat "," _t98  ; Δ{_t84 _t98 l3} · makes String
                              ret case _t101 of
                            _ ->
                          drop _t74 : tuple2$Bool$Int
                          drop _t78 : tuple2$Bool$Int
                          drop _t81 : String
                          let _t67 = 0  ; Δ{l3}
                          let _t68 = call yes _t67  ; Δ{l3}
                          let _t69 = 1  ; Δ{l3}
                          let _t70 = call yes _t69  ; Δ{l3}
                          let _t71 = * _t70 10  ; Δ{l3}
                          let _t72 = + _t68 _t71  ; Δ{l3}
                          let _t73 = 1  ; Δ{l3}
                          let _t74 = tuple _t73 7  ; Δ{l3} · makes heap
                          let _t75 = call flags _t74  ; Δ{_t74 l3}
                          let _t76 = + _t72 _t75  ; Δ{l3}
                          let _t77 = 0  ; Δ{l3}
                          let _t78 = tuple _t77 2  ; Δ{l3} · makes heap
                          let _t79 = call flags _t78  ; Δ{_t78 l3}
                          let _t80 = + _t76 _t79  ; Δ{l3}
                          let _t81 = showInt _t80  ; Δ{l3} · makes String
                          let _t82 = putStrLn _t81  ; Δ{_t81 l3}
                          ret case _t82 of
                        _ ->
                      drop _t65 : String
                      let _t47 = 1  ; Δ{l3}
                      let _t48 = 0  ; Δ{l3}
                      let _t49 = call both _t47 _t48  ; Δ{l3}
                      let _t50 = * _t49 1000  ; Δ{l3}
                      let _t51 = 0  ; Δ{l3}
                      let _t52 = 1  ; Δ{l3}
                      let _t53 = call both _t51 _t52  ; Δ{l3}
                      let _t54 = * _t53 100  ; Δ{l3}
                      let _t55 = + _t50 _t54  ; Δ{l3}
                      let _t56 = 1  ; Δ{l3}
                      let _t57 = 1  ; Δ{l3}
                      let _t58 = call both _t56 _t57  ; Δ{l3}
                      let _t59 = * _t58 10  ; Δ{l3}
                      let _t60 = + _t55 _t59  ; Δ{l3}
                      let _t61 = 0  ; Δ{l3}
                      let _t62 = 0  ; Δ{l3}
                      let _t63 = call both _t61 _t62  ; Δ{l3}
                      let _t64 = + _t60 _t63  ; Δ{l3}
                      let _t65 = showInt _t64  ; Δ{l3} · makes String
                      let _t66 = putStrLn _t65  ; Δ{_t65 l3}
                      ret case _t66 of
                    _ ->
                  drop _t43 : tuple2$Int$tuple2$Int$Int
                  drop _t45 : String
                  let _t42 = tuple 2 3  ; Δ{l3} · makes heap
                  let _t43 = tuple 1 _t42  ; Δ{_t42 l3} · moves{_t42} · makes heap
                  let _t44 = call swapSum _t43  ; Δ{_t43 l3}
                  let _t45 = showInt _t44  ; Δ{l3} · makes String
                  let _t46 = putStrLn _t45  ; Δ{_t45 l3}
                  ret case _t46 of
                _ ->
                let _t2 = call zipLen xs ys  ; Δ{}
                ret + 1 _t2  ; Δ{}
              LCons _t3 ys ->
              drop _t32 : Maybe$Int
              drop _t34 : Maybe$Int
              drop _t37 : Maybe$Int
              drop _t40 : String
              let _t32 = con Nothing  ; Δ{l3} · makes Maybe$Int
              let _t33 = call pick 0 _t32  ; Δ{_t32 l3}
              let _t34 = con Nothing  ; Δ{l3} · makes Maybe$Int
              let _t35 = call pick 4 _t34  ; Δ{_t34 l3}
              let _t36 = + _t33 _t35  ; Δ{l3}
              let _t37 = con Just 6  ; Δ{l3} · makes Maybe$Int
              let _t38 = call pick 4 _t37  ; Δ{_t37 l3}
              let _t39 = + _t36 _t38  ; Δ{l3}
              let _t40 = showInt _t39  ; Δ{l3} · makes String
              let _t41 = putStrLn _t40  ; Δ{_t40 l3}
              ret 0  ; Δ{}
              ret 1  ; Δ{}
              ret case _t41 of
            LCons _ _ ->
            _ ->
            _ ->
            ret "rect"  ; Δ{}
            ret "square"  ; Δ{}
            ret + _p0 k  ; Δ{}
            ret 0  ; Δ{}
            ret 1  ; Δ{}
            ret case _p1 of
            ret y  ; Δ{}
          Just k ->
          LCons _t4 xs ->
          LCons y _t2 ->
          LNil ->
          _ ->
          drop _t19 : Shape
          drop _t20 : Shape
          drop _t22 : Shape
          drop _t23 : Shape
          drop _t26 : Shape
          drop _t27 : Shape
          drop _t30 : String
          else
          let _t0 = * a 100  ; Δ{}
          let _t1 = * b 10  ; Δ{}
          let _t1 = + _p1 x  ; Δ{}
          let _t19 = con Rect 2 3  ; Δ{l3} · makes Shape
          let _t2 = + _t0 _t1  ; Δ{}
          let _t2 = == w h  ; Δ{}
          let _t20 = con Dot  ; Δ{_t19 l3} · makes Shape
          let _t21 = call sizeOf _t19 _t20  ; Δ{_t19 _t20 l3}
          let _t22 = con Dot  ; Δ{l3} · makes Shape
          let _t23 = con Circle 5  ; Δ{_t22 l3} · makes Shape
          let _t24 = call sizeOf _t22 _t23  ; Δ{_t22 _t23 l3}
          let _t25 = + _t21 _t24  ; Δ{l3}
          let _t26 = con Dot  ; Δ{l3} · makes Shape
          let _t27 = con Dot  ; Δ{_t26 l3} · makes Shape
          let _t28 = call sizeOf _t26 _t27  ; Δ{_t26 _t27 l3}
          let _t29 = + _t25 _t28  ; Δ{l3}
          let _t30 = showInt _t29  ; Δ{l3} · makes String
          let _t31 = putStrLn _t30  ; Δ{_t30 l3}
          ret "big circle"  ; Δ{}
          ret "circle"  ; Δ{}
          ret + _t2 c  ; Δ{}
          ret - 0 n$1002  ; Δ{}
          ret - 0 x  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret 1  ; Δ{}
          ret call total$go rest _t1  ; Δ{}
          ret case _p1 of
          ret case _t31 of
          ret if _t2 then
          ret n$1002  ; Δ{}
          ret r  ; Δ{}
          ret rtcall axion_contract_fail "runtime error: no clause of 'both' matched the arguments"  ; Δ{}
        (b, c) ->
        1 ->
        Circle r ->
        Dot ->
        Just _ ->
        LCons _ _ ->
        LCons _ _ ->
        LCons x _t5 ->
        LCons x rest ->
        LNil ->
        Rect w h ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        _ ->
        else
        else
        let _t0 = > r 10  ; Δ{}
        let _t10 = == _p1 0  ; Δ{}
        let _t11 = band _t9 _t10  ; Δ{}
        let _t9 = == _p0 0  ; Δ{}
        ret "dot"  ; Δ{}
        ret * w h  ; Δ{}
        ret 0  ; Δ{}
        ret 0  ; Δ{}
        ret 0  ; Δ{}
        ret 0  ; Δ{}
        ret 0  ; Δ{}
        ret 0  ; Δ{}
        ret 0  ; Δ{}
        ret 1  ; Δ{}
        ret 1  ; Δ{}
        ret 1  ; Δ{}
        ret 1  ; Δ{}
        ret 1  ; Δ{}
        ret 1  ; Δ{}
        ret case _p0 of
        ret case _p1 of
        ret case _t1 of
        ret case _t6 of
        ret if _t0 then
        ret if _t11 then
        ret rtcall axion_contract_fail "runtime error: no clause of 'classify' matched the arguments"  ; Δ{}
        ret rtcall axion_contract_fail "runtime error: no clause of 'pick' matched the arguments"  ; Δ{}
        ret rtcall axion_contract_fail "runtime error: no clause of 'second' matched the arguments"  ; Δ{}
        ret rtcall axion_contract_fail "runtime error: no clause of 'zipLen' matched the arguments"  ; Δ{}
        ret x  ; Δ{}
      Circle _ ->
      Circle r ->
      LCons _ _ ->
      LCons _ _t6 ->
      LCons _t0 _t1 ->
      LCons x _t0 ->
      LNil ->
      Nothing ->
      Rect _ _ ->
      Rect w h ->
      _ ->
      _ ->
      _ ->
      _ ->
      _ ->
      _ ->
      drop _t11 : Lst
      drop _t14 : Lst
      drop _t17 : String
      else
      else
      else
      else
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_Lst _dd0  ; Δ{}
      let _t10 = con LNil  ; Δ{l3} · makes Lst
      let _t11 = con LCons 5 _t10  ; Δ{_t10 l3} · moves{_t10} · makes Lst
      let _t12 = call second _t11  ; Δ{_t11 l3}
      let _t13 = + _t9 _t12  ; Δ{l3}
      let _t14 = con LNil  ; Δ{l3} · makes Lst
      let _t15 = call second _t14  ; Δ{_t14 l3}
      let _t16 = + _t13 _t15  ; Δ{l3}
      let _t17 = showInt _t16  ; Δ{l3} · makes String
      let _t18 = putStrLn _t17  ; Δ{_t17 l3}
      let _t2 = case _p1 of
      let _t4 = case _p0 of
      let _t5 = case _p0 of
      let _t6 = == _p0 0  ; Δ{}
      let _t7 = == _p1 1  ; Δ{}
      let _t8 = band _t6 _t7  ; Δ{}
      let _t8 = case _p0 of
      let _t9 = call second l3  ; Δ{l3}
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
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 2  ; Δ{}
      ret 200  ; Δ{}
      ret case $nf1 of
      ret case $nf1 of
      ret case _p0 of
      ret case _p0 of
      ret case _p0 of
      ret case _p1 of
      ret case _t18 of
      ret case _t3 of
      ret if _t2 then
      ret if _t4 then
      ret if _t5 then
      ret if _t8 then
      ret if _t8 then
      ret rtcall axion_contract_fail "runtime error: no clause of 'go' matched the arguments"  ; Δ{}
    ($nf1, n$1002) ->
    (a, $nf1) ->
    0 ->
    Circle _ ->
    LCons _ _ ->
    LCons _ _t3 ->
    LNil ->
    LNil ->
    Rect _ _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    else
    else
    else
    else
    else
    else
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = case _p1 of
    let _t1 = case _p1 of
    let _t1 = case _p1 of
    let _t2 = case _p0 of
    let _t3 = == _p0 1  ; Δ{}
    let _t3 = case _p0 of
    let _t4 = == _p1 0  ; Δ{}
    let _t5 = band _t3 _t4  ; Δ{}
    let _t7 = case _p0 of
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
    ret 100  ; Δ{}
    ret 3  ; Δ{}
    ret _p1  ; Δ{}
    ret case _p0 of
    ret case _p0 of
    ret case _p0 of
    ret case _p0 of
    ret if _t1 then
    ret if _t1 then
    ret if _t1 then
    ret if _t2 then
    ret if _t3 then
    ret if _t5 then
    ret if _t7 then
    ret rtcall axion_contract_fail "runtime error: no clause of 'headOr' matched the arguments"  ; Δ{}
  ; Δ{l3}
  ; Δ{l3}
  ; Δ{l3}
  ; Δ{l3}
  ; Δ{l3}
  ; Δ{l3}
  ; Δ{l3}
  ; Δ{l3}
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
  drop _t5 : Lst
  drop _t7 : String
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  else
  let _dd0 = band _p 1  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_tuple2$Int$Int _dd0  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = == _p0 0  ; Δ{}
  let _t0 = == _p0 1  ; Δ{}
  let _t0 = case _p0 of
  let _t0 = case _p0 of
  let _t0 = case _p0 of
  let _t0 = con LNil  ; Δ{} · makes Lst
  let _t1 = == _p1 1  ; Δ{}
  let _t1 = case _p0 of
  let _t1 = case _p0 of
  let _t1 = con LCons 3 _t0  ; Δ{_t0} · moves{_t0} · makes Lst
  let _t2 = band _t0 _t1  ; Δ{}
  let _t2 = con LCons 2 _t1  ; Δ{_t1} · moves{_t1} · makes Lst
  let _t3 = con LNil  ; Δ{l3} · makes Lst
  let _t4 = case _p0 of
  let _t4 = con LCons 8 _t3  ; Δ{_t3 l3} · moves{_t3} · makes Lst
  let _t5 = con LCons 9 _t4  ; Δ{_t4 l3} · moves{_t4} · makes Lst
  let _t6 = call zipLen l3 _t5  ; Δ{_t5 l3}
  let _t7 = showInt _t6  ; Δ{l3} · makes String
  let _t8 = putStrLn _t7  ; Δ{_t7 l3}
  let l3 = con LCons 1 _t2  ; Δ{_t2} · moves{_t2} · makes Lst
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call total$go l 0  ; Δ{}
  ret case _p0 of
  ret case _t8 of
  ret case b of
  ret case p of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t1 then
  ret if _t2 then
  ret if _t4 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_Lst _p  =
axion_drop_Maybe$Int _p  =
axion_drop_tuple2$Bool$Int _p  =
axion_drop_tuple2$Int$Int _p  =
axion_drop_tuple2$Int$tuple2$Int$Int _p  =
both _p0 _p1  =
classify _p0  =
flags p  =
headOr _p0  =
main  =
pick _p0 _p1  =
second _p0  =
sizeOf _p0 _p1  =
swapSum _p0  =
total l  =
total$go _p0 _p1  =
yes b  =
zipLen _p0 _p1  =
