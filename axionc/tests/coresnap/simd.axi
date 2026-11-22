














                                  drop _t42 : String
                                  let _d1000000 = putStrLn _t42  ; Δ{_t42}
                                  let _t40 = vec.make.I64x2 7 9  ; Δ{}
                                  let _t41 = vec.lane.I64x2 _t40 1  ; Δ{}
                                  let _t42 = showInt _t41  ; Δ{} · makes String
                                  ret _d1000000  ; Δ{}
                                _ ->
                              drop _t38 : String
                              let _t34 = vec.make.F64x2 0.25f 0.5f  ; Δ{}
                              let _t35 = vec.make.F64x2 0.5f 0.25f  ; Δ{}
                              let _t36 = vec.div.F64x2 _t34 _t35  ; Δ{}
                              let _t37 = vec.sum.F64x2 _t36  ; Δ{}
                              let _t38 = rtcall axion_show_float _t37  ; Δ{} · makes String
                              let _t39 = putStrLn _t38  ; Δ{_t38}
                              ret case _t39 of
                            _ ->
                          drop _t32 : String
                          drop xs : Array
                          drop ys : Array
                          let _t27 = newArray 16 0f  ; Δ{} · makes Array
                          let _t28 = newArray 16 0f  ; Δ{xs} · makes Array
                          let _t29 = call fill _t28 0 16  ; Δ{_t28 xs} · moves{_t28} · makes Array
                          let _t30 = vec.splat.F64x4 0f  ; Δ{xs ys}
                          let _t31 = call dotLoop xs ys 0 16 _t30  ; Δ{xs ys}
                          let _t32 = rtcall axion_show_float _t31  ; Δ{} · makes String
                          let _t33 = putStrLn _t32  ; Δ{_t32}
                          let xs = call fill _t27 0 16  ; Δ{_t27} · moves{_t27} · makes Array
                          let ys = call scaleAll _t29 0 16  ; Δ{_t29 xs} · moves{_t29} · makes Array
                          ret case _t33 of
                        _ ->
                      drop _t25 : String
                      let _t21 = call ints  ; Δ{}
                      let _t22 = vec.splat.I64x4 25  ; Δ{}
                      let _t23 = vec.max.I64x4 _t21 _t22  ; Δ{}
                      let _t24 = vec.lane.I64x4 _t23 1  ; Δ{}
                      let _t25 = showInt _t24  ; Δ{} · makes String
                      let _t26 = putStrLn _t25  ; Δ{_t25}
                      ret case _t26 of
                    _ ->
                  drop _t19 : String
                  let _t17 = call ints  ; Δ{}
                  let _t18 = vec.sum.I64x4 _t17  ; Δ{}
                  let _t19 = showInt _t18  ; Δ{} · makes String
                  let _t20 = putStrLn _t19  ; Δ{_t19}
                  ret case _t20 of
                _ ->
              drop _t15 : String
              let _t12 = vec.mul.F64x4 v v  ; Δ{}
              let _t13 = vec.sqrt.F64x4 _t12  ; Δ{}
              let _t14 = vec.sum.F64x4 _t13  ; Δ{}
              let _t15 = rtcall axion_show_float _t14  ; Δ{} · makes String
              let _t16 = putStrLn _t15  ; Δ{_t15}
              ret case _t16 of
            _ ->
          drop _t10 : String
          drop _t19 : String
          let _d1000000 = putStrLn _t19  ; Δ{_t19}
          let _t10 = 1  ; Δ{}
          let _t10 = rtcall axion_show_float _t9  ; Δ{} · makes String
          let _t11 = call pick _t10 3 4  ; Δ{}
          let _t11 = putStrLn _t10  ; Δ{_t10}
          let _t12 = 0  ; Δ{}
          let _t13 = vec.splat.F64x2 1f  ; Δ{}
          let _t14 = vec.splat.F64x2 2f  ; Δ{}
          let _t15 = call pick$F64x2 _t12 _t13 _t14  ; Δ{}
          let _t16 = vec.sum.F64x2 _t15  ; Δ{}
          let _t17 = truncate _t16  ; Δ{}
          let _t18 = + _t11 _t17  ; Δ{}
          let _t19 = showInt _t18  ; Δ{} · makes String
          let _t7 = vec.splat.F64x4 2.5f  ; Δ{}
          let _t8 = vec.min.F64x4 v _t7  ; Δ{}
          let _t9 = vec.sum.F64x4 _t8  ; Δ{}
          ret _d1000000  ; Δ{}
          ret case _t11 of
        _ ->
        _ ->
        ret con Add  ; Δ{}
        ret con Neg  ; Δ{}
      drop _t5 : String
      drop _t8 : String
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t0 = vec.splat.I64x4 0  ; Δ{}
      let _t1 = vec.make.I64x4 1 1 1 1  ; Δ{}
      let _t2 = call go 20 _t1  ; Δ{}
      let _t3 = vec.sum.I64x4 _t2  ; Δ{}
      let _t4 = mod n 3  ; Δ{}
      let _t4 = vec.lane.F64x4 w 3  ; Δ{}
      let _t4 = vec.splat.I64x4 3  ; Δ{}
      let _t5 = == _t4 1  ; Δ{}
      let _t5 = call go 7 _t4  ; Δ{}
      let _t5 = rtcall axion_show_float _t4  ; Δ{} · makes String
      let _t6 = putStrLn _t5  ; Δ{_t5}
      let _t6 = vec.lane.I64x4 _t5 2  ; Δ{}
      let _t7 = + _t3 _t6  ; Δ{}
      let _t8 = showInt _t7  ; Δ{} · makes String
      let _t9 = putStrLn _t8  ; Δ{_t8}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t6 of
      ret case _t9 of
      ret con Mul  ; Δ{}
      ret if _t5 then
      ret vec.add.I64x4 a b  ; Δ{}
      ret vec.mul.I64x4 a b  ; Δ{}
      ret vec.sub.I64x4 _t0 a  ; Δ{}
    Add ->
    Mul ->
    Neg ->
    _ ->
    _ ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = - n 1  ; Δ{}
    let _t1 = toFloat i  ; Δ{}
    let _t10 = rtcall axion_array_get_nobc xs _t9  ; Δ{}
    let _t10 = vec.make.F64x4 _t3 _t5 _t7 _t9  ; Δ{}
    let _t11 = vec.make.F64x4 _t4 _t6 _t8 _t10  ; Δ{}
    let _t11 = vec.splat.F64x4 2f  ; Δ{}
    let _t12 = rtcall axion_array_range ys i 4  ; Δ{}
    let _t12 = vec.mul.F64x4 _t10 _t11  ; Δ{}
    let _t13 = rtcall axion_array_get_nobc ys _t12  ; Δ{}
    let _t13 = rtcall axion_array_range a i 4  ; Δ{}
    let _t14 = + _t12 1  ; Δ{}
    let _t14 = vec.lane.F64x4 _t12 0  ; Δ{}
    let _t15 = rtcall axion_array_get_nobc ys _t14  ; Δ{}
    let _t15 = rtcall axion_array_set_nobc a _t13 _t14  ; Δ{} · makes Array
    let _t16 = + _t12 2  ; Δ{}
    let _t16 = + _t13 1  ; Δ{_t15}
    let _t17 = rtcall axion_array_get_nobc ys _t16  ; Δ{}
    let _t17 = vec.lane.F64x4 _t12 1  ; Δ{_t15}
    let _t18 = + _t12 3  ; Δ{}
    let _t18 = rtcall axion_array_set_nobc _t15 _t16 _t17  ; Δ{_t15} · moves{_t15} · makes Array
    let _t19 = + _t13 2  ; Δ{_t18}
    let _t19 = rtcall axion_array_get_nobc ys _t18  ; Δ{}
    let _t2 = + i 4  ; Δ{}
    let _t2 = mod n 3  ; Δ{}
    let _t2 = rtcall axion_array_range a i 4  ; Δ{}
    let _t2 = rtcall axion_array_set a i _t1  ; Δ{} · makes Array
    let _t20 = vec.lane.F64x4 _t12 2  ; Δ{_t18}
    let _t20 = vec.make.F64x4 _t13 _t15 _t17 _t19  ; Δ{}
    let _t21 = rtcall axion_array_set_nobc _t18 _t19 _t20  ; Δ{_t18} · moves{_t18} · makes Array
    let _t21 = vec.mul.F64x4 _t11 _t20  ; Δ{}
    let _t22 = + _t13 3  ; Δ{_t21}
    let _t22 = vec.add.F64x4 acc _t21  ; Δ{}
    let _t23 = vec.lane.F64x4 _t12 3  ; Δ{_t21}
    let _t24 = rtcall axion_array_set_nobc _t21 _t22 _t23  ; Δ{_t21} · moves{_t21} · makes Array
    let _t25 = + i 4  ; Δ{_t24}
    let _t3 = + i 1  ; Δ{_t2}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = rtcall axion_array_get_nobc a _t2  ; Δ{}
    let _t3 = rtcall axion_array_range xs i 4  ; Δ{}
    let _t4 = + _t2 1  ; Δ{}
    let _t4 = rtcall axion_array_get_nobc xs _t3  ; Δ{}
    let _t5 = + _t3 1  ; Δ{}
    let _t5 = rtcall axion_array_get_nobc a _t4  ; Δ{}
    let _t6 = + _t2 2  ; Δ{}
    let _t6 = if _t3 then
    let _t6 = rtcall axion_array_get_nobc xs _t5  ; Δ{}
    let _t7 = + _t3 2  ; Δ{}
    let _t7 = rtcall axion_array_get_nobc a _t6  ; Δ{}
    let _t7 = vec.make.I64x4 1 2 3 n  ; Δ{}
    let _t8 = + _t2 3  ; Δ{}
    let _t8 = call step _t6 acc _t7  ; Δ{}
    let _t8 = rtcall axion_array_get_nobc xs _t7  ; Δ{}
    let _t9 = + _t3 3  ; Δ{}
    let _t9 = rtcall axion_array_get_nobc a _t8  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret a  ; Δ{}
    ret a  ; Δ{}
    ret acc  ; Δ{}
    ret call dotLoop xs ys _t2 n _t22  ; Δ{}
    ret call fill _t2 _t3 n  ; Δ{_t2} · moves{_t2} · makes Array
    ret call go _t1 _t8  ; Δ{}
    ret call scaleAll _t24 _t25 n  ; Δ{_t24} · moves{_t24} · makes Array
    ret vec.sum.F64x4 acc  ; Δ{}
    ret x  ; Δ{}
    ret x  ; Δ{}
    ret y  ; Δ{}
    ret y  ; Δ{}
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
  drop _t2 : String
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
  let _t0 = + i 4  ; Δ{}
  let _t0 = + i 4  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = call mainA  ; Δ{}
  let _t0 = vec.make.I64x4 1 2 3 4  ; Δ{}
  let _t0 = vec.splat.F64x4 1f  ; Δ{}
  let _t0 = vec.splat.F64x4 a  ; Δ{}
  let _t1 = call <=$Int _t0 n  ; Δ{}
  let _t1 = call <=$Int _t0 n  ; Δ{}
  let _t1 = vec.splat.I64x4 10  ; Δ{}
  let _t1 = vec.sum.F64x4 w  ; Δ{}
  let _t2 = rtcall axion_show_float _t1  ; Δ{} · makes String
  let _t2 = vec.mul.I64x4 _t0 _t1  ; Δ{}
  let _t3 = putStrLn _t2  ; Δ{_t2}
  let _t3 = vec.make.I64x4 0 1 2 3  ; Δ{}
  let v = vec.make.F64x4 1f 2f 3f 4f  ; Δ{}
  let w = call axpy 0.5f v _t0  ; Δ{}
  ret 0  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret case _t0 of
  ret case _t3 of
  ret case op of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t1 then
  ret if b then
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
  ret vec.fma.F64x4 _t0 x y  ; Δ{}
  ret vec.sub.I64x4 _t2 _t3  ; Δ{}
<=$Int x y  =
axion_drop_Array _p  =
axion_drop_List _p  =
axpy a x y  =
dotLoop xs ys i n acc  =
fill a i n  =
go n acc  =
ints  =
le$Int x y  =
main  =
mainA  =
pick b x y  =
pick$F64x2 b x y  =
scaleAll a i n  =
step op a b  =
