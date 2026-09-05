






































                                      drop _t57 : List$Int
                                      drop _t60 : String
                                      let _d1000000 = putStrLn _t60  ; Δ{_t60}
                                      let _t54 = con Nil  ; Δ{} · makes List$Int
                                      let _t55 = con Cons 2 _t54  ; Δ{_t54} · moves{_t54} · makes List$Int
                                      let _t56 = con Cons 8 _t55  ; Δ{_t55} · moves{_t55} · makes List$Int
                                      let _t57 = con Cons 9 _t56  ; Δ{_t56} · moves{_t56} · makes List$Int
                                      let _t58 = call findIndex$$lt5 _t57  ; Δ{_t57} · makes Maybe$Int
                                      let _t59 = call fromMaybe 99 _t58  ; Δ{_t58} · moves{_t58}
                                      let _t60 = call show$Int _t59  ; Δ{} · makes String
                                      ret _d1000000  ; Δ{}
                                    _ ->
                                  drop _t49 : List$tuple$Int$Int
                                  drop _t52 : String
                                  let _t45 = tuple 1 10  ; Δ{} · makes heap
                                  let _t46 = tuple 2 20  ; Δ{_t45} · makes heap
                                  let _t47 = con Nil  ; Δ{_t45 _t46} · makes List$tuple$Int$Int
                                  let _t48 = con Cons _t46 _t47  ; Δ{_t45 _t46 _t47} · moves{_t46 _t47} · makes List$tuple$Int$Int
                                  let _t49 = con Cons _t45 _t48  ; Δ{_t45 _t48} · moves{_t45 _t48} · makes List$tuple$Int$Int
                                  let _t50 = call lookup$Int 2 _t49  ; Δ{_t49} · makes Maybe$Int
                                  let _t51 = call fromMaybe 99 _t50  ; Δ{_t50} · moves{_t50}
                                  let _t52 = call show$Int _t51  ; Δ{} · makes String
                                  let _t53 = putStrLn _t52  ; Δ{_t52}
                                  ret case _t53 of
                                _ ->
                              drop _t41 : List$Bool
                              drop _t43 : String
                              let _t37 = 0  ; Δ{}
                              let _t38 = 0  ; Δ{}
                              let _t39 = con Nil  ; Δ{} · makes List$Bool
                              let _t40 = con Cons _t38 _t39  ; Δ{_t39} · moves{_t39} · makes List$Bool
                              let _t41 = con Cons _t37 _t40  ; Δ{_t40} · moves{_t40} · makes List$Bool
                              let _t42 = call or _t41  ; Δ{_t41}
                              let _t43 = call show$Bool _t42  ; Δ{} · makes String
                              let _t44 = putStrLn _t43  ; Δ{_t43}
                              ret case _t44 of
                            _ ->
                          drop _t33 : List$Bool
                          drop _t35 : String
                          let _t29 = 1  ; Δ{}
                          let _t30 = 1  ; Δ{}
                          let _t31 = con Nil  ; Δ{} · makes List$Bool
                          let _t32 = con Cons _t30 _t31  ; Δ{_t31} · moves{_t31} · makes List$Bool
                          let _t33 = con Cons _t29 _t32  ; Δ{_t32} · moves{_t32} · makes List$Bool
                          let _t34 = call and _t33  ; Δ{_t33}
                          let _t35 = call show$Bool _t34  ; Δ{} · makes String
                          let _t36 = putStrLn _t35  ; Δ{_t35}
                          ret case _t36 of
                        _ ->
                      drop _t25 : List$Int
                      drop _t27 : String
                      let _t24 = call range 1 3  ; Δ{} · makes List$Int
                      let _t25 = call concatMap$$dup _t24  ; Δ{_t24} · moves{_t24} · makes List$Int
                      let _t26 = call sum _t25  ; Δ{_t25}
                      let _t27 = call show$Int _t26  ; Δ{} · makes String
                      let _t28 = putStrLn _t27  ; Δ{_t27}
                      ret case _t28 of
                    _ ->
                  drop _t22 : String
                  let _t19 = call range 1 6  ; Δ{} · makes List$Int
                  let _t20 = call splitAt 2 _t19  ; Δ{_t19} · moves{_t19}
                  let _t21 = call sumPair _t20  ; Δ{}
                  let _t22 = call show$Int _t21  ; Δ{} · makes String
                  let _t23 = putStrLn _t22  ; Δ{_t22}
                  ret case _t23 of
                _ ->
              drop _t17 : String
              let _t14 = call range 1 6  ; Δ{} · makes List$Int
              let _t15 = call span$$lt5 _t14  ; Δ{_t14} · moves{_t14} · makes tuple$List$Int$List$Int
              let _t16 = call sumPair _t15  ; Δ{_t15} · moves{_t15}
              let _t17 = call show$Int _t16  ; Δ{} · makes String
              let _t18 = putStrLn _t17  ; Δ{_t17}
              ret case _t18 of
            _ ->
            ret call lookup$Int k ps  ; Δ{} · makes Maybe
            ret con Just b  ; Δ{}
          drop _t10 : List$Int
          drop _t12 : String
          else
          let _t0 = call eq$Int a k  ; Δ{}
          let _t10 = call dropWhile$$lt5 _t9  ; Δ{_t9} · moves{_t9} · makes List$Int
          let _t11 = call sum _t10  ; Δ{_t10}
          let _t12 = call show$Int _t11  ; Δ{} · makes String
          let _t13 = putStrLn _t12  ; Δ{_t12}
          let _t9 = call range 1 6  ; Δ{} · makes List$Int
          ret case _t13 of
          ret if _t0 then
        (a, b) ->
        _ ->
        drop _t1 : Maybe$Int
        drop ys : List$Int
        let _d1000000 = call incMaybe _t1  ; Δ{_t1} · makes Maybe$Int
        let _t1 = call findIndex$$lt5 ys  ; Δ{} · makes Maybe$Int
        let _t1 = call takeWhile$$lt5 ys  ; Δ{y ys} · moves{ys} · makes List$Int
        let _t3 = call span$$lt5 ys  ; Δ{y ys} · moves{ys} · makes tuple$List$Int$List$Int
        let _t3 = con Nil  ; Δ{}
        let _t4 = con Cons y ys  ; Δ{}
        let _t4 = con Nil  ; Δ{y ys} · makes List$Int
        let _t5 = - n 1  ; Δ{}
        let _t5 = con Cons y ys  ; Δ{_t4 y ys} · moves{y ys} · makes List$Int
        let _t6 = call splitAt _t5 ys  ; Δ{}
        ret 0  ; Δ{}
        ret 1  ; Δ{}
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
        ret call and ys  ; Δ{}
        ret call consFst y _t6  ; Δ{}
        ret call consFst$Int y _t3  ; Δ{_t3 y} · moves{_t3 y} · makes tuple$List$Int$List$Int
        ret call dropWhile$$lt5 ys  ; Δ{y ys} · moves{ys} · makes List$Int
        ret call or ys  ; Δ{}
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$Int
        ret con Cons y ys  ; Δ{y ys} · moves{y ys} · makes List$Int
        ret con Just 0  ; Δ{} · makes Maybe$Int
        ret con Nil  ; Δ{y} · makes List$Int
        ret tuple _t3 _t4  ; Δ{} · makes heap
        ret tuple _t4 _t5  ; Δ{_t4 _t5} · moves{_t4 _t5} · makes heap
      drop _t5 : List$Int
      drop _t7 : String
      drop ab
      drop ab
      drop ab : tuple$List$Int$List$Int
      drop m
      drop m
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs : List$List$Int
      else
      else
      else
      else
      else
      else
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Bool _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple$Int$Int _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
      let _dd3 = call axion_drop_tuple$Int$Int _dd2  ; Δ{}
      let _t0 = + i 1  ; Δ{}
      let _t0 = call append$Int zs ys  ; Δ{z zs} · moves{zs} · makes List$Int
      let _t0 = call concat$Int ys  ; Δ{y ys} · moves{ys} · makes List$Int
      let _t0 = call dup y  ; Δ{y ys} · moves{y} · makes List$Int
      let _t0 = call lt5 y  ; Δ{y ys}
      let _t0 = call lt5 y  ; Δ{y ys}
      let _t0 = call lt5 y  ; Δ{}
      let _t0 = call product ys  ; Δ{}
      let _t0 = call sum a  ; Δ{ab}
      let _t0 = call sum ys  ; Δ{}
      let _t0 = con Cons y a  ; Δ{}
      let _t0 = con Cons y a  ; Δ{}
      let _t0 = con Nil  ; Δ{}
      let _t0 = con Nil  ; Δ{} · makes List$Int
      let _t1 = call map$$dup ys  ; Δ{_t0 ys} · moves{ys} · makes List$List$Int
      let _t1 = call sum b  ; Δ{ab}
      let _t1 = con Nil  ; Δ{_t0} · makes List$Int
      let _t1 = con Nil  ; Δ{}
      let _t2 = < n 1  ; Δ{}
      let _t2 = call lt5 y  ; Δ{y ys}
      let _t4 = call range 1 10  ; Δ{} · makes List$Int
      let _t5 = call takeWhile$$lt5 _t4  ; Δ{_t4} · moves{_t4} · makes List$Int
      let _t6 = call sum _t5  ; Δ{_t5}
      let _t7 = call show$Int _t6  ; Δ{} · makes String
      let _t8 = putStrLn _t7  ; Δ{_t7}
      ret * y _t0  ; Δ{}
      ret + _t0 _t1  ; Δ{}
      ret + y _t0  ; Δ{}
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
      ret call append$Int y _t0  ; Δ{_t0 y} · moves{_t0 y} · makes List$Int
      ret callclo f x  ; Δ{x} · moves{x}
      ret case _t8 of
      ret case p of
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$List$Int
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Just _t0  ; Δ{} · makes Maybe$Int
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nil  ; Δ{} · makes List$List$Int
      ret con Nothing  ; Δ{}
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret d  ; Δ{}
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t2 then
      ret if _t2 then
      ret if y then
      ret if y then
      ret tuple _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes heap
      ret tuple _t0 _t1  ; Δ{} · makes heap
      ret tuple _t0 b  ; Δ{} · makes heap
      ret tuple _t0 b  ; Δ{} · makes heap
      ret ys  ; Δ{}
    (a, b) ->
    (a, b) ->
    (a, b) ->
    Cons p ps ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
    Just i ->
    Just x ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nothing ->
    Nothing ->
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
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t2 = + acc lo  ; Δ{}
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
    let _t2 = callclo c lo n  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "false"  ; Δ{}
    ret "true"  ; Δ{}
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
    ret acc  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
    ret con Nil  ; Δ{} · makes List$Int
    ret n  ; Δ{}
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
  drop _t0
  drop _t0 : List$Int
  drop _t2 : String
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
  let _d1000000 = call maybe d _t0 m  ; Δ{_t0}
  let _dd0 = band _p 1  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
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
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = call map$$dup xs  ; Δ{} · makes List$List$Int
  let _t0 = call range 1 6  ; Δ{} · makes List$Int
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t1 = call product _t0  ; Δ{_t0}
  let _t1 = con Cons n _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t2 = call show$Int _t1  ; Δ{} · makes String
  let _t3 = putStrLn _t2  ; Δ{_t2}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret < n 5  ; Δ{}
  ret == x y  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call concat$Int _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  ret case _t3 of
  ret case ab of
  ret case ab of
  ret case ab of
  ret case m of
  ret case m of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Cons n _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if x then
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret x  ; Δ{}
and xs  =
append$Int xs ys  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Bool _p  =
axion_drop_List$Int _p  =
axion_drop_List$List$Int _p  =
axion_drop_List$tuple$Int$Int _p  =
axion_drop_Maybe$Int _p  =
axion_drop_tuple$Int$Int _p  =
axion_drop_tuple$List$Int$List$Int _p  =
concat$Int xs  =
concatMap$$dup xs  =
consFst y ab  =
consFst$Int y ab  =
dropWhile$$lt5 xs  =
dup n  =
eq$Int x y  =
findIndex$$lt5 xs  =
fromMaybe d m  =
incMaybe m  =
lam$0 [env ]x  =
lookup$Int k xs  =
lt5 n  =
main  =
map$$dup xs  =
maybe d f m  =
or xs  =
product xs  =
range lo hi  =
rangeFused lo hi c n  =
rangeFusedSum lo hi acc  =
show$Bool x  =
show$Int x  =
span$$lt5 xs  =
splitAt n xs  =
sum xs  =
sumPair ab  =
takeWhile$$lt5 xs  =
