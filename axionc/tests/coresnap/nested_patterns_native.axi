




















                                                                          drop _t102 : String
                                                                          drop _t89 : Maybe$Maybe$Int
                                                                          drop _t92 : Maybe$Maybe$Int
                                                                          drop _t96 : Maybe$Maybe$Int
                                                                          drop _t99 : Maybe$Maybe$Int
                                                                          let _d1000000 = putStrLn _t102  ; Δ{_t102}
                                                                          let _t100 = call lits _t99  ; Δ{_t99}
                                                                          let _t101 = + _t98 _t100  ; Δ{}
                                                                          let _t102 = showInt _t101  ; Δ{} · makes String
                                                                          let _t88 = con Just 0  ; Δ{} · makes Maybe$Int
                                                                          let _t89 = con Just _t88  ; Δ{_t88} · moves{_t88} · makes Maybe$Maybe$Int
                                                                          let _t90 = call lits _t89  ; Δ{_t89}
                                                                          let _t91 = con Just 7  ; Δ{} · makes Maybe$Int
                                                                          let _t92 = con Just _t91  ; Δ{_t91} · moves{_t91} · makes Maybe$Maybe$Int
                                                                          let _t93 = call lits _t92  ; Δ{_t92}
                                                                          let _t94 = + _t90 _t93  ; Δ{}
                                                                          let _t95 = con Nothing  ; Δ{} · makes Maybe$Int
                                                                          let _t96 = con Just _t95  ; Δ{_t95} · moves{_t95} · makes Maybe$Maybe$Int
                                                                          let _t97 = call lits _t96  ; Δ{_t96}
                                                                          let _t98 = + _t94 _t97  ; Δ{}
                                                                          let _t99 = con Nothing  ; Δ{} · makes Maybe$Maybe$Int
                                                                          ret _d1000000  ; Δ{}
                                                                        _ ->
                                                                      drop _t85 : List$String
                                                                      drop _t86 : String
                                                                      let _t83 = con Nil  ; Δ{} · makes List$String
                                                                      let _t84 = con Cons "b" _t83  ; Δ{_t83} · moves{_t83} · makes List$String
                                                                      let _t85 = con Cons "a" _t84  ; Δ{_t84} · moves{_t84} · makes List$String
                                                                      let _t86 = call firstOr _t85  ; Δ{_t85} · makes String
                                                                      let _t87 = putStrLn _t86  ; Δ{_t86}
                                                                      ret case _t87 of
                                                                    _ ->
                                                                  drop _t80 : List$String
                                                                  drop _t81 : String
                                                                  let _t79 = con Nil  ; Δ{} · makes List$String
                                                                  let _t80 = con Cons "only" _t79  ; Δ{_t79} · moves{_t79} · makes List$String
                                                                  let _t81 = call firstOr _t80  ; Δ{_t80} · makes String
                                                                  let _t82 = putStrLn _t81  ; Δ{_t81}
                                                                  ret case _t82 of
                                                                _ ->
                                                              drop _t76 : Maybe$Named
                                                              drop _t77 : String
                                                              let _t76 = con Nothing  ; Δ{} · makes Maybe$Named
                                                              let _t77 = call labelOf _t76  ; Δ{_t76} · makes String
                                                              let _t78 = putStrLn _t77  ; Δ{_t77}
                                                              ret case _t78 of
                                                            _ ->
                                                          drop _t73 : Maybe$Named
                                                          drop _t74 : String
                                                          let _t71 = con Rect 1 2  ; Δ{} · makes Shape
                                                          let _t72 = con Named "box" _t71  ; Δ{_t71} · moves{_t71} · makes Named
                                                          let _t73 = con Just _t72  ; Δ{_t72} · moves{_t72} · makes Maybe$Named
                                                          let _t74 = call labelOf _t73  ; Δ{_t73} · makes String
                                                          let _t75 = putStrLn _t74  ; Δ{_t74}
                                                          ret case _t75 of
                                                        _ ->
                                                      drop _t68 : Maybe$Named
                                                      drop _t69 : String
                                                      let _t66 = con Circle 3  ; Δ{} · makes Shape
                                                      let _t67 = con Named "sun" _t66  ; Δ{_t66} · moves{_t66} · makes Named
                                                      let _t68 = con Just _t67  ; Δ{_t67} · moves{_t67} · makes Maybe$Named
                                                      let _t69 = call labelOf _t68  ; Δ{_t68} · makes String
                                                      let _t70 = putStrLn _t69  ; Δ{_t69}
                                                      ret case _t70 of
                                                    _ ->
                                                  drop _t63 : Maybe$tuple2$tuple2$Int$Int$String
                                                  drop _t64 : String
                                                  let _t63 = con Nothing  ; Δ{} · makes Maybe$tuple2$tuple2$Int$Int$String
                                                  let _t64 = call deep _t63  ; Δ{_t63} · makes String
                                                  let _t65 = putStrLn _t64  ; Δ{_t64}
                                                  ret case _t65 of
                                                _ ->
                                              drop _t60 : Maybe$tuple2$tuple2$Int$Int$String
                                              drop _t61 : String
                                              let _t58 = tuple 4 5  ; Δ{} · makes heap
                                              let _t59 = tuple _t58 "x"  ; Δ{_t58} · moves{_t58} · makes heap
                                              let _t60 = con Just _t59  ; Δ{_t59} · moves{_t59} · makes Maybe$tuple2$tuple2$Int$Int$String
                                              let _t61 = call deep _t60  ; Δ{_t60} · makes String
                                              let _t62 = putStrLn _t61  ; Δ{_t61}
                                              ret case _t62 of
                                            _ ->
                                          drop _t55 : Maybe$tuple2$tuple2$Int$Int$String
                                          drop _t56 : String
                                          let _t53 = tuple 0 5  ; Δ{} · makes heap
                                          let _t54 = tuple _t53 "y="  ; Δ{_t53} · moves{_t53} · makes heap
                                          let _t55 = con Just _t54  ; Δ{_t54} · moves{_t54} · makes Maybe$tuple2$tuple2$Int$Int$String
                                          let _t56 = call deep _t55  ; Δ{_t55} · makes String
                                          let _t57 = putStrLn _t56  ; Δ{_t56}
                                          ret case _t57 of
                                        _ ->
                                      drop _t50 : List$String
                                      drop _t51 : String
                                      let _t50 = con Nil  ; Δ{} · makes List$String
                                      let _t51 = call names _t50  ; Δ{_t50} · makes String
                                      let _t52 = putStrLn _t51  ; Δ{_t51}
                                      ret case _t52 of
                                    _ ->
                                  drop _t47 : List$String
                                  drop _t48 : String
                                  let _t46 = con Nil  ; Δ{} · makes List$String
                                  let _t47 = con Cons "solo" _t46  ; Δ{_t46} · moves{_t46} · makes List$String
                                  let _t48 = call names _t47  ; Δ{_t47} · makes String
                                  let _t49 = putStrLn _t48  ; Δ{_t48}
                                  ret case _t49 of
                                _ ->
                              drop _t43 : List$String
                              drop _t44 : String
                              let _t40 = con Nil  ; Δ{} · makes List$String
                              let _t41 = con Cons "ef" _t40  ; Δ{_t40} · moves{_t40} · makes List$String
                              let _t42 = con Cons "cd" _t41  ; Δ{_t41} · moves{_t41} · makes List$String
                              let _t43 = con Cons "ab" _t42  ; Δ{_t42} · moves{_t42} · makes List$String
                              let _t44 = call names _t43  ; Δ{_t43} · makes String
                              let _t45 = putStrLn _t44  ; Δ{_t44}
                              ret case _t45 of
                            _ ->
                          drop _t37 : List$Int
                          drop _t38 : String
                          let _t37 = con Nil  ; Δ{} · makes List$Int
                          let _t38 = call classify _t37  ; Δ{_t37} · makes String
                          let _t39 = putStrLn _t38  ; Δ{_t38}
                          ret case _t39 of
                        _ ->
                      drop _t34 : List$Int
                      drop _t35 : String
                      let _t31 = con Nil  ; Δ{} · makes List$Int
                      let _t32 = con Cons 3 _t31  ; Δ{_t31} · moves{_t31} · makes List$Int
                      let _t33 = con Cons 2 _t32  ; Δ{_t32} · moves{_t32} · makes List$Int
                      let _t34 = con Cons 1 _t33  ; Δ{_t33} · moves{_t33} · makes List$Int
                      let _t35 = call classify _t34  ; Δ{_t34} · makes String
                      let _t36 = putStrLn _t35  ; Δ{_t35}
                      ret case _t36 of
                    _ ->
                    ret "two zeros"  ; Δ{}
                    ret "zero second"  ; Δ{}
                  _ ->
                  _ ->
                  drop _t0 : String
                  drop _t0 : String
                  drop _t1 : String
                  drop _t28 : List$Int
                  drop _t29 : String
                  let _d1000000 = rtcall axion_strcat "one " _t0  ; Δ{_t0} · makes String
                  let _d1000000 = rtcall axion_strcat s$1003 _t0  ; Δ{_t0} · makes String
                  let _d1000001 = rtcall axion_strcat _t1 s$1003  ; Δ{_t1} · makes String
                  let _t0 = showInt a  ; Δ{} · makes String
                  let _t0 = showInt y  ; Δ{} · makes String
                  let _t1 = showInt x$1004  ; Δ{} · makes String
                  let _t27 = con Nil  ; Δ{} · makes List$Int
                  let _t28 = con Cons 9 _t27  ; Δ{_t27} · moves{_t27} · makes List$Int
                  let _t29 = call classify _t28  ; Δ{_t28} · makes String
                  let _t30 = putStrLn _t29  ; Δ{_t29}
                  ret 0  ; Δ{}
                  ret 0  ; Δ{}
                  ret 1  ; Δ{}
                  ret 1  ; Δ{}
                  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
                  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
                  ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
                  ret case _t30 of
                0 ->
                0 ->
                0 ->
                Nil ->
                _ ->
                _ ->
                _ ->
                _ ->
                ret 0  ; Δ{}
                ret 1  ; Δ{}
                ret case $nf11 of
                ret case $nf19 of
              Cons $nf11 _ ->
              Cons $nf19 _ ->
              Nil ->
              _ ->
              drop _t24 : List$Int
              drop _t25 : String
              let $fieldcopy0 = rtcall axion_strcat l$1002 ""  ; Δ{} · makes String
              let _t22 = con Nil  ; Δ{} · makes List$Int
              let _t23 = con Cons 0 _t22  ; Δ{_t22} · moves{_t22} · makes List$Int
              let _t24 = con Cons 7 _t23  ; Δ{_t23} · moves{_t23} · makes List$Int
              let _t25 = call classify _t24  ; Δ{_t24} · makes String
              let _t26 = putStrLn _t25  ; Δ{_t25}
              ret "zero first"  ; Δ{}
              ret $fieldcopy0  ; Δ{$fieldcopy0} · moves{$fieldcopy0}
              ret 0  ; Δ{}
              ret 0  ; Δ{}
              ret 100  ; Δ{}
              ret case $nf16 of
              ret case $nf22 of
              ret case $nf7 of
              ret case _t26 of
              ret case x$1004 of
              ret n$1002  ; Δ{}
              ret rtcall axion_strcat "circle " l$1002  ; Δ{} · makes String
            (x$1004, y) ->
            0 ->
            Circle _ ->
            Cons $nf16 _ ->
            Cons $nf7 _ ->
            Cons a $nf22 ->
            _ ->
            _ ->
            _ ->
            _ ->
            _ ->
            _ ->
            let $fieldcopy0 = rtcall axion_strcat s ""  ; Δ{} · makes String
            ret $fieldcopy0  ; Δ{$fieldcopy0} · moves{$fieldcopy0}
            ret 0  ; Δ{}
            ret 0  ; Δ{}
            ret 1  ; Δ{}
            ret case $nf10 of
            ret case $nf18 of
            ret case $nf20 of
          0 ->
          Cons _ $nf18 ->
          Cons _ $nf20 ->
          Nil ->
          _ ->
          _ ->
          _ ->
          drop _t0 : String
          drop _t19 : List$Int
          drop _t2 : String
          drop _t20 : String
          let $fieldcopy0 = rtcall axion_strcat a$1001 ""  ; Δ{} · makes String
          let _d1000000 = rtcall axion_strcat a$1001 _t0  ; Δ{_t0} · makes String
          let _d1000001 = rtcall axion_strcat "other " _t2  ; Δ{_t2} · makes String
          let _t0 = * 3 r  ; Δ{}
          let _t0 = rtcall axion_strcat "+" b  ; Δ{} · makes String
          let _t1 = call length xs  ; Δ{}
          let _t17 = con Nil  ; Δ{} · makes List$Int
          let _t18 = con Cons 5 _t17  ; Δ{_t17} · moves{_t17} · makes List$Int
          let _t19 = con Cons 0 _t18  ; Δ{_t18} · moves{_t18} · makes List$Int
          let _t2 = showInt _t1  ; Δ{} · makes String
          let _t20 = call classify _t19  ; Δ{_t19} · makes String
          let _t21 = putStrLn _t20  ; Δ{_t20}
          ret $fieldcopy0  ; Δ{$fieldcopy0} · moves{$fieldcopy0}
          ret * _t0 r  ; Δ{}
          ret * w h  ; Δ{}
          ret - 0 1  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 1  ; Δ{}
          ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
          ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
          ret case $nf14 of
          ret case $nf15 of
          ret case $nf2 of
          ret case $nf3 of
          ret case $nf6 of
          ret case _t21 of
          ret case n$1002 of
          ret case xs of
        ($nf2, s$1003) ->
        0 ->
        Circle r ->
        Cons $nf14 _ ->
        Cons _ $nf15 ->
        Cons b _ ->
        Just n$1002 ->
        Named l$1002 $nf3 ->
        Nil ->
        Nil ->
        Nothing ->
        Rect w h ->
        _ ->
        _ ->
        _ ->
        _ ->
        else
        let $nfok21 = case xs of
        ret 0  ; Δ{}
        ret case $nf12 of
        ret case $nf4 of
        ret case $nf9 of
        ret case xs of
        ret if $nfok21 then
      Cons $nf12 _ ->
      Cons $nf9 $nf10 ->
      Cons s $nf4 ->
      _ ->
      drop _t14 : List$Int
      drop _t15 : String
      else
      let $nfok17 = case xs of
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = call axion_drop_Maybe$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_Named _dd0  ; Δ{}
      let _dd1 = call axion_drop_tuple2$tuple2$Int$Int$String _dd0  ; Δ{}
      let _dd1 = rtcall axion_free _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t12 = con Nil  ; Δ{} · makes List$Int
      let _t13 = con Cons 0 _t12  ; Δ{_t12} · moves{_t12} · makes List$Int
      let _t14 = con Cons 0 _t13  ; Δ{_t13} · moves{_t13} · makes List$Int
      let _t15 = call classify _t14  ; Δ{_t14} · makes String
      let _t16 = putStrLn _t15  ; Δ{_t15}
      ret "-"  ; Δ{}
      ret "?"  ; Δ{}
      ret "none"  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret - 0 2  ; Δ{}
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
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case $nf1 of
      ret case $nf1 of
      ret case $nf1 of
      ret case $nf1 of
      ret case $nf2 of
      ret case $nf2 of
      ret case $nf5 of
      ret case _t16 of
      ret case xs of
      ret if $nfok17 then
    Cons $nf5 $nf6 ->
    Cons _ $nf2 ->
    Cons a$1001 $nf2 ->
    Cons y ys ->
    Just $nf1 ->
    Just $nf1 ->
    Just $nf1 ->
    Just $nf1 ->
    Nil ->
    Nil ->
    Nothing ->
    Nothing ->
    Nothing ->
    Nothing ->
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
    let $nfok13 = case xs of
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t0 = call length xs  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
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
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret case xs of
    ret case xs of
    ret if $nfok13 then
    ret showInt _t0  ; Δ{} · makes String
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
  drop _t1 : Maybe$Shape
  drop _t10 : String
  drop _t4 : Maybe$Shape
  drop _t7 : Maybe$Shape
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
  let $nfok3 = case xs of
  let $nfok8 = case xs of
  let _dd0 = band _p 1  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd1 = rtcall axion_free _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = call axion_drop_tuple2$Int$Int _dd2  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = con Rect 3 4  ; Δ{} · makes Shape
  let _t1 = con Just _t0  ; Δ{_t0} · moves{_t0} · makes Maybe$Shape
  let _t10 = showInt _t9  ; Δ{} · makes String
  let _t11 = putStrLn _t10  ; Δ{_t10}
  let _t2 = call area _t1  ; Δ{_t1}
  let _t3 = con Circle 2  ; Δ{} · makes Shape
  let _t4 = con Just _t3  ; Δ{_t3} · moves{_t3} · makes Maybe$Shape
  let _t5 = call area _t4  ; Δ{_t4}
  let _t6 = + _t2 _t5  ; Δ{}
  let _t7 = con Nothing  ; Δ{} · makes Maybe$Shape
  let _t8 = call area _t7  ; Δ{_t7}
  let _t9 = + _t6 _t8  ; Δ{}
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
  ret case _t11 of
  ret case m of
  ret case m of
  ret case m of
  ret case m of
  ret case xs of
  ret case xs of
  ret if $nfok3 then
  ret if $nfok8 then
  ret rtcall axion_array_free _p  ; Δ{}
area m  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$Int _p  =
axion_drop_Maybe$Maybe$Int _p  =
axion_drop_Maybe$Named _p  =
axion_drop_Maybe$Shape _p  =
axion_drop_Maybe$tuple2$tuple2$Int$Int$String _p  =
axion_drop_Named _p  =
axion_drop_tuple2$Int$Int _p  =
axion_drop_tuple2$tuple2$Int$Int$String _p  =
classify xs  =
deep m  =
firstOr xs  =
labelOf m  =
length xs  =
lits m  =
main  =
names xs  =
