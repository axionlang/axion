

























                                              drop _t118
                                              drop _t121 : String
                                              drop m : Array
                                              let _d1000000 = putStrLn _t121  ; Δ{_t121}
                                              let _t116 = * w w  ; Δ{}
                                              let _t117 = newArray _t116 0  ; Δ{} · makes Array
                                              let _t118 = closure lam$1 w  ; Δ{_t117} · makes Closure
                                              let _t119 = rtcall axion_par_for _t117 _t118  ; Δ{_t117 _t118}
                                              let _t120 = call sumA m 0 0  ; Δ{}
                                              let _t121 = showInt _t120  ; Δ{} · makes String
                                              let m = _t117  ; Δ{_t117} · moves{_t117}
                                              let w = 256  ; Δ{}
                                              ret _d1000000  ; Δ{}
                                            _ ->
                                          drop _t110
                                          drop _t114 : String
                                          drop v : Array
                                          let _t108 = toFloat32 0f  ; Δ{}
                                          let _t109 = newArray 1000 _t108  ; Δ{} · makes Array
                                          let _t110 = closure lam$0  ; Δ{_t109} · makes Closure
                                          let _t111 = rtcall axion_par_for _t109 _t110  ; Δ{_t109 _t110}
                                          let _t112 = toFloat32 0f  ; Δ{}
                                          let _t113 = call sumF v 0 _t112  ; Δ{}
                                          let _t114 = call show$Float32 _t113  ; Δ{} · makes String
                                          let _t115 = putStrLn _t114  ; Δ{_t114}
                                          let v = _t109  ; Δ{_t109} · moves{_t109}
                                          ret case _t115 of
                                        _ ->
                                      drop _t102 : String
                                      drop _t103 : String
                                      drop _t104 : String
                                      drop _t105 : String
                                      drop _t106 : String
                                      drop _t87 : String
                                      drop _t92 : String
                                      let _t100 = /#f32 _t98 _t99  ; Δ{_t87 _t92}
                                      let _t101 = ==#f32 _t96 _t100  ; Δ{_t87 _t92}
                                      let _t102 = call show$Bool _t101  ; Δ{_t87 _t92} · makes String
                                      let _t103 = rtcall axion_strcat " " _t102  ; Δ{_t102 _t87 _t92} · makes String
                                      let _t104 = rtcall axion_strcat _t92 _t103  ; Δ{_t103 _t87 _t92} · makes String
                                      let _t105 = rtcall axion_strcat " " _t104  ; Δ{_t104 _t87} · makes String
                                      let _t106 = rtcall axion_strcat _t87 _t105  ; Δ{_t105 _t87} · makes String
                                      let _t107 = putStrLn _t106  ; Δ{_t106}
                                      let _t83 = toFloat32 1.5f  ; Δ{}
                                      let _t84 = call f32 _t83  ; Δ{}
                                      let _t85 = toFloat32 2.5f  ; Δ{}
                                      let _t86 = <#f32 _t84 _t85  ; Δ{}
                                      let _t87 = call show$Bool _t86  ; Δ{} · makes String
                                      let _t88 = toFloat32 1.5f  ; Δ{_t87}
                                      let _t89 = call f32 _t88  ; Δ{_t87}
                                      let _t90 = toFloat32 2.5f  ; Δ{_t87}
                                      let _t91 = call >=$Float32 _t89 _t90  ; Δ{_t87}
                                      let _t92 = call show$Bool _t91  ; Δ{_t87} · makes String
                                      let _t93 = toFloat32 0f  ; Δ{_t87 _t92}
                                      let _t94 = call f32 _t93  ; Δ{_t87 _t92}
                                      let _t95 = toFloat32 0f  ; Δ{_t87 _t92}
                                      let _t96 = /#f32 _t94 _t95  ; Δ{_t87 _t92}
                                      let _t97 = toFloat32 0f  ; Δ{_t87 _t92}
                                      let _t98 = call f32 _t97  ; Δ{_t87 _t92}
                                      let _t99 = toFloat32 0f  ; Δ{_t87 _t92}
                                      ret case _t107 of
                                    _ ->
                                  drop _t66 : String
                                  drop _t72 : String
                                  drop _t77 : String
                                  drop _t78 : String
                                  drop _t79 : String
                                  drop _t80 : String
                                  drop _t81 : String
                                  let _t63 = toFloat32 10000000000f  ; Δ{}
                                  let _t64 = call f32 _t63  ; Δ{}
                                  let _t65 = truncateF32 _t64  ; Δ{}
                                  let _t66 = call show$Int32 _t65  ; Δ{} · makes String
                                  let _t67 = toFloat32 0f  ; Δ{_t66}
                                  let _t68 = call f32 _t67  ; Δ{_t66}
                                  let _t69 = toFloat32 0f  ; Δ{_t66}
                                  let _t70 = /#f32 _t68 _t69  ; Δ{_t66}
                                  let _t71 = truncateF32 _t70  ; Δ{_t66}
                                  let _t72 = call show$Int32 _t71  ; Δ{_t66} · makes String
                                  let _t73 = toFloat32 0f  ; Δ{_t66 _t72}
                                  let _t74 = toFloat32 2.75f  ; Δ{_t66 _t72}
                                  let _t75 = -#f32 _t73 _t74  ; Δ{_t66 _t72}
                                  let _t76 = truncateF32 _t75  ; Δ{_t66 _t72}
                                  let _t77 = call show$Int32 _t76  ; Δ{_t66 _t72} · makes String
                                  let _t78 = rtcall axion_strcat " " _t77  ; Δ{_t66 _t72 _t77} · makes String
                                  let _t79 = rtcall axion_strcat _t72 _t78  ; Δ{_t66 _t72 _t78} · makes String
                                  let _t80 = rtcall axion_strcat " " _t79  ; Δ{_t66 _t79} · makes String
                                  let _t81 = rtcall axion_strcat _t66 _t80  ; Δ{_t66 _t80} · makes String
                                  let _t82 = putStrLn _t81  ; Δ{_t81}
                                  ret case _t82 of
                                _ ->
                              drop _t56 : String
                              drop _t59 : String
                              drop _t60 : String
                              drop _t61 : String
                              let _t53 = toFloat32 3f  ; Δ{}
                              let _t54 = toFloat32 4f  ; Δ{}
                              let _t55 = call norm _t53 _t54  ; Δ{}
                              let _t56 = call show$Float32 _t55  ; Δ{} · makes String
                              let _t57 = toFloat32 2f  ; Δ{_t56}
                              let _t58 = sqrtF32 _t57  ; Δ{_t56}
                              let _t59 = call show$Float32 _t58  ; Δ{_t56} · makes String
                              let _t60 = rtcall axion_strcat " " _t59  ; Δ{_t56 _t59} · makes String
                              let _t61 = rtcall axion_strcat _t56 _t60  ; Δ{_t56 _t60} · makes String
                              let _t62 = putStrLn _t61  ; Δ{_t61}
                              ret case _t62 of
                            _ ->
                          drop _t51 : String
                          let _t49 = toFloat32 0f  ; Δ{}
                          let _t50 = call harmonic _t49 1000  ; Δ{}
                          let _t51 = call show$Float32 _t50  ; Δ{} · makes String
                          let _t52 = putStrLn _t51  ; Δ{_t51}
                          ret case _t52 of
                        _ ->
                      drop _t41 : String
                      drop _t45 : String
                      drop _t46 : String
                      drop _t47 : String
                      let _t39 = toFloat32 0.1f  ; Δ{}
                      let _t40 = call f32 _t39  ; Δ{}
                      let _t41 = call show$Float32 _t40  ; Δ{} · makes String
                      let _t42 = toFloat32 0.1f  ; Δ{_t41}
                      let _t43 = call f32 _t42  ; Δ{_t41}
                      let _t44 = fromFloat32 _t43  ; Δ{_t41}
                      let _t45 = rtcall axion_show_float _t44  ; Δ{_t41} · makes String
                      let _t46 = rtcall axion_strcat " " _t45  ; Δ{_t41 _t45} · makes String
                      let _t47 = rtcall axion_strcat _t41 _t46  ; Δ{_t41 _t46} · makes String
                      let _t48 = putStrLn _t47  ; Δ{_t47}
                      ret case _t48 of
                    _ ->
                  drop _t31 : String
                  drop _t35 : String
                  drop _t36 : String
                  drop _t37 : String
                  let _t30 = toInt32 4294967301  ; Δ{}
                  let _t31 = call show$Int32 _t30  ; Δ{} · makes String
                  let _t32 = call big  ; Δ{_t31}
                  let _t33 = _t32  ; Δ{_t31}
                  let _t34 = * _t33 2  ; Δ{_t31}
                  let _t35 = call show$Int _t34  ; Δ{_t31} · makes String
                  let _t36 = rtcall axion_strcat " " _t35  ; Δ{_t31 _t35} · makes String
                  let _t37 = rtcall axion_strcat _t31 _t36  ; Δ{_t31 _t36} · makes String
                  let _t38 = putStrLn _t37  ; Δ{_t37}
                  ret case _t38 of
                _ ->
              drop _t21 : String
              drop _t26 : String
              drop _t27 : String
              drop _t28 : String
              let _t17 = -#i32 0 2147483647  ; Δ{}
              let _t18 = -#i32 _t17 1  ; Δ{}
              let _t19 = -#i32 0 1  ; Δ{}
              let _t20 = call quot32 _t18 _t19  ; Δ{}
              let _t21 = call show$Int32 _t20  ; Δ{} · makes String
              let _t22 = -#i32 0 2147483647  ; Δ{_t21}
              let _t23 = -#i32 _t22 1  ; Δ{_t21}
              let _t24 = -#i32 0 1  ; Δ{_t21}
              let _t25 = call rem32 _t23 _t24  ; Δ{_t21}
              let _t26 = call show$Int32 _t25  ; Δ{_t21} · makes String
              let _t27 = rtcall axion_strcat " " _t26  ; Δ{_t21 _t26} · makes String
              let _t28 = rtcall axion_strcat _t21 _t27  ; Δ{_t21 _t27} · makes String
              let _t29 = putStrLn _t28  ; Δ{_t28}
              ret case _t29 of
            _ ->
          drop _t10 : String
          drop _t13 : String
          drop _t14 : String
          drop _t15 : String
          let _t10 = call show$Int32 _t9  ; Δ{} · makes String
          let _t11 = -#i32 0 7  ; Δ{_t10}
          let _t12 = call rem32 _t11 2  ; Δ{_t10}
          let _t13 = call show$Int32 _t12  ; Δ{_t10} · makes String
          let _t14 = rtcall axion_strcat " " _t13  ; Δ{_t10 _t13} · makes String
          let _t15 = rtcall axion_strcat _t10 _t14  ; Δ{_t10 _t14} · makes String
          let _t16 = putStrLn _t15  ; Δ{_t15}
          let _t8 = -#i32 0 7  ; Δ{}
          let _t9 = call quot32 _t8 2  ; Δ{}
          ret case _t16 of
        _ ->
      drop _t6 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t10 = toFloat32 2f  ; Δ{}
      let _t11 = *#f32 _t10 zr  ; Δ{}
      let _t12 = *#f32 _t11 zi  ; Δ{}
      let _t13 = +#f32 _t12 ci  ; Δ{}
      let _t14 = +#i32 k 1  ; Δ{}
      let _t5 = call lcg 1 100  ; Δ{}
      let _t6 = *#f32 zr zr  ; Δ{}
      let _t6 = call show$Int32 _t5  ; Δ{} · makes String
      let _t7 = *#f32 zi zi  ; Δ{}
      let _t7 = putStrLn _t6  ; Δ{_t6}
      let _t8 = -#f32 _t6 _t7  ; Δ{}
      let _t9 = +#f32 _t8 cr  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret call orbit cr ci _t9 _t13 _t14  ; Δ{}
      ret case _t7 of
      ret k  ; Δ{}
    _ ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = *#f32 zr zr  ; Δ{}
    let _t1 = *#i32 x 1103515245  ; Δ{}
    let _t1 = toFloat32 1f  ; Δ{}
    let _t2 = *#f32 zi zi  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = +#i32 _t1 12345  ; Δ{}
    let _t2 = int32ToFloat32 n  ; Δ{}
    let _t3 = +#f32 _t1 _t2  ; Δ{}
    let _t3 = -#i32 k 1  ; Δ{}
    let _t3 = /#f32 _t1 _t2  ; Δ{}
    let _t3 = rtcall axion_array_get a i  ; Δ{}
    let _t3 = rtcall axion_array_get a i  ; Δ{}
    let _t4 = + acc _t3  ; Δ{}
    let _t4 = +#f32 acc _t3  ; Δ{}
    let _t4 = +#f32 acc _t3  ; Δ{}
    let _t4 = toFloat32 4f  ; Δ{}
    let _t5 = -#i32 n 1  ; Δ{}
    let _t5 = >#f32 _t3 _t4  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "false"  ; Δ{}
    ret "true"  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret == x y  ; Δ{}
    ret ==#f32 x y  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret call harmonic _t4 _t5  ; Δ{}
    ret call lcg _t2 _t3  ; Δ{}
    ret call sumA a _t2 _t4  ; Δ{}
    ret call sumF a _t2 _t4  ; Δ{}
    ret if _t5 then
    ret k  ; Δ{}
    ret x  ; Δ{}
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
  drop _t3 : String
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
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = *#f32 x x  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = <#f32 x y  ; Δ{}
  let _t0 = call <=$Int32 k 0  ; Δ{}
  let _t0 = call <=$Int32 n 0  ; Δ{}
  let _t0 = call >=$Int32 k 200  ; Δ{}
  let _t0 = call big  ; Δ{}
  let _t0 = mod p w  ; Δ{}
  let _t0 = rtcall axion_array_len a  ; Δ{}
  let _t0 = rtcall axion_array_len a  ; Δ{}
  let _t0 = toInt32 i  ; Δ{}
  let _t1 = *#f32 y y  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call big  ; Δ{}
  let _t1 = int32ToFloat32 _t0  ; Δ{}
  let _t1 = toInt32 _t0  ; Δ{}
  let _t10 = div p w  ; Δ{}
  let _t11 = toInt32 _t10  ; Δ{}
  let _t12 = int32ToFloat32 _t11  ; Δ{}
  let _t13 = toFloat32 3f  ; Δ{}
  let _t14 = *#f32 _t12 _t13  ; Δ{}
  let _t15 = toInt32 w  ; Δ{}
  let _t16 = int32ToFloat32 _t15  ; Δ{}
  let _t17 = /#f32 _t14 _t16  ; Δ{}
  let _t18 = toFloat32 1.5f  ; Δ{}
  let _t19 = -#f32 _t17 _t18  ; Δ{}
  let _t2 = +#f32 _t0 _t1  ; Δ{}
  let _t2 = +#i32 _t0 _t1  ; Δ{}
  let _t2 = int32ToFloat32 _t1  ; Δ{}
  let _t2 = toFloat32 0.001f  ; Δ{}
  let _t20 = toFloat32 0f  ; Δ{}
  let _t21 = toFloat32 0f  ; Δ{}
  let _t3 = call show$Int32 _t2  ; Δ{} · makes String
  let _t3 = toFloat32 3f  ; Δ{}
  let _t4 = *#f32 _t2 _t3  ; Δ{}
  let _t4 = putStrLn _t3  ; Δ{_t3}
  let _t5 = toInt32 w  ; Δ{}
  let _t6 = int32ToFloat32 _t5  ; Δ{}
  let _t7 = /#f32 _t4 _t6  ; Δ{}
  let _t8 = toFloat32 2f  ; Δ{}
  let _t9 = -#f32 _t7 _t8  ; Δ{}
  ret *#f32 _t1 _t2  ; Δ{}
  ret 0  ; Δ{}
  ret 2000000000  ; Δ{}
  ret call le$Float32 y x  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call le$Int32 x y  ; Δ{}
  ret call le$Int32 y x  ; Δ{}
  ret call orbit _t9 _t19 _t20 _t21 0  ; Δ{}
  ret case _t4 of
  ret div#i32 a b  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t1 then
  ret if x then
  ret mod#i32 a b  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_show_float32 x  ; Δ{} · makes String
  ret showInt x  ; Δ{} · makes String
  ret showInt x  ; Δ{} · makes String
  ret sqrtF32 _t2  ; Δ{}
  ret x  ; Δ{}
<=$Int32 x y  =
>=$Float32 x y  =
>=$Int x y  =
>=$Int32 x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
big  =
f32 x  =
harmonic acc n  =
lam$0 [env ]i _w1  =
lam$1 [env w]p _w1  =
lcg x k  =
le$Float32 x y  =
le$Int x y  =
le$Int32 x y  =
main  =
norm x y  =
orbit cr ci zr zi k  =
quot32 a b  =
rem32 a b  =
show$Bool x  =
show$Float32 x  =
show$Int x  =
show$Int32 x  =
sumA a i acc  =
sumF a i acc  =
