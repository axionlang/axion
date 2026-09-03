







































                                      drop _t60 : List$Int
                                      drop _t63 : String
                                      let _d1000000 = putStrLn _t63  ; Δ{_t63}
                                      let _t57 = con Nil  ; Δ{} · makes List$Int
                                      let _t58 = con Cons 2 _t57  ; Δ{_t57} · moves{_t57} · makes List$Int
                                      let _t59 = con Cons 8 _t58  ; Δ{_t58} · moves{_t58} · makes List$Int
                                      let _t60 = con Cons 9 _t59  ; Δ{_t59} · moves{_t59} · makes List$Int
                                      let _t61 = call findIndex$$lt5 _t60  ; Δ{_t60} · makes Maybe$Int
                                      let _t62 = call fromMaybe 99 _t61  ; Δ{_t61} · moves{_t61}
                                      let _t63 = call show$Int _t62  ; Δ{} · makes String
                                      ret _d1000000  ; Δ{}
                                    _ ->
                                  drop _t52 : List$tuple$Int$Int
                                  drop _t55 : String
                                  let _t48 = tuple 1 10  ; Δ{} · makes heap
                                  let _t49 = tuple 2 20  ; Δ{_t48} · makes heap
                                  let _t50 = con Nil  ; Δ{_t48 _t49} · makes List$tuple$Int$Int
                                  let _t51 = con Cons _t49 _t50  ; Δ{_t48 _t49 _t50} · moves{_t49 _t50} · makes List$tuple$Int$Int
                                  let _t52 = con Cons _t48 _t51  ; Δ{_t48 _t51} · moves{_t48 _t51} · makes List$tuple$Int$Int
                                  let _t53 = call lookup$Int 2 _t52  ; Δ{_t52} · makes Maybe$Int
                                  let _t54 = call fromMaybe 99 _t53  ; Δ{_t53} · moves{_t53}
                                  let _t55 = call show$Int _t54  ; Δ{} · makes String
                                  let _t56 = putStrLn _t55  ; Δ{_t55}
                                  ret case _t56 of
                                _ ->
                              drop _t44 : List$Bool
                              drop _t46 : String
                              let _t40 = 0  ; Δ{}
                              let _t41 = 0  ; Δ{}
                              let _t42 = con Nil  ; Δ{} · makes List$Bool
                              let _t43 = con Cons _t41 _t42  ; Δ{_t42} · moves{_t42} · makes List$Bool
                              let _t44 = con Cons _t40 _t43  ; Δ{_t43} · moves{_t43} · makes List$Bool
                              let _t45 = call or _t44  ; Δ{_t44}
                              let _t46 = call show$Bool _t45  ; Δ{} · makes String
                              let _t47 = putStrLn _t46  ; Δ{_t46}
                              ret case _t47 of
                            _ ->
                          drop _t36 : List$Bool
                          drop _t38 : String
                          let _t32 = 1  ; Δ{}
                          let _t33 = 1  ; Δ{}
                          let _t34 = con Nil  ; Δ{} · makes List$Bool
                          let _t35 = con Cons _t33 _t34  ; Δ{_t34} · moves{_t34} · makes List$Bool
                          let _t36 = con Cons _t32 _t35  ; Δ{_t35} · moves{_t35} · makes List$Bool
                          let _t37 = call and _t36  ; Δ{_t36}
                          let _t38 = call show$Bool _t37  ; Δ{} · makes String
                          let _t39 = putStrLn _t38  ; Δ{_t38}
                          ret case _t39 of
                        _ ->
                      drop _t28 : List$Int
                      drop _t30 : String
                      let _t27 = call range 1 3  ; Δ{} · makes List$Int
                      let _t28 = call concatMap$$dup _t27  ; Δ{_t27} · moves{_t27} · makes List$Int
                      let _t29 = call sum _t28  ; Δ{_t28}
                      let _t30 = call show$Int _t29  ; Δ{} · makes String
                      let _t31 = putStrLn _t30  ; Δ{_t30}
                      ret case _t31 of
                    _ ->
                  drop _t25 : String
                  let _t22 = call range 1 6  ; Δ{} · makes List$Int
                  let _t23 = call splitAt 2 _t22  ; Δ{_t22} · moves{_t22}
                  let _t24 = call sumPair _t23  ; Δ{}
                  let _t25 = call show$Int _t24  ; Δ{} · makes String
                  let _t26 = putStrLn _t25  ; Δ{_t25}
                  ret case _t26 of
                _ ->
              drop _t16
              drop _t20 : String
              let _t16 = closure lam$3  ; Δ{} · makes heap
              let _t17 = call range 1 6  ; Δ{_t16} · makes List$Int
              let _t18 = call span _t16 _t17  ; Δ{_t16 _t17} · moves{_t17}
              let _t19 = call sumPair _t18  ; Δ{}
              let _t20 = call show$Int _t19  ; Δ{} · makes String
              let _t21 = putStrLn _t20  ; Δ{_t20}
              ret case _t21 of
            _ ->
            ret call lookup$Int k ps  ; Δ{} · makes Maybe
            ret con Just b  ; Δ{}
          drop _t10
          drop _t12 : List$Int
          drop _t14 : String
          else
          let _t0 = == a k  ; Δ{}
          let _t10 = closure lam$2  ; Δ{} · makes heap
          let _t11 = call range 1 6  ; Δ{_t10} · makes List$Int
          let _t12 = call dropWhile _t10 _t11  ; Δ{_t10 _t11} · moves{_t11} · makes List$Int
          let _t13 = call sum _t12  ; Δ{_t12}
          let _t14 = call show$Int _t13  ; Δ{} · makes String
          let _t15 = putStrLn _t14  ; Δ{_t14}
          ret case _t15 of
          ret if _t0 then
        (a, b) ->
        _ ->
        drop _t1 : Maybe$Int
        let _d1000000 = call incMaybe _t1  ; Δ{_t1} · makes Maybe$Int
        let _t1 = call findIndex$$lt5 ys  ; Δ{} · makes Maybe$Int
        let _t1 = call takeWhile p ys  ; Δ{} · makes List
        let _t3 = call span p ys  ; Δ{}
        let _t3 = con Nil  ; Δ{}
        let _t4 = con Cons y ys  ; Δ{}
        let _t4 = con Nil  ; Δ{}
        let _t5 = - n 1  ; Δ{}
        let _t5 = con Cons y ys  ; Δ{}
        let _t6 = call splitAt _t5 ys  ; Δ{}
        ret 0  ; Δ{}
        ret 1  ; Δ{}
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
        ret call and ys  ; Δ{}
        ret call consFst y _t3  ; Δ{}
        ret call consFst y _t6  ; Δ{}
        ret call dropWhile p ys  ; Δ{} · makes List
        ret call or ys  ; Δ{}
        ret con Cons y _t1  ; Δ{_t1} · moves{_t1}
        ret con Cons y ys  ; Δ{}
        ret con Just 0  ; Δ{} · makes Maybe$Int
        ret con Nil  ; Δ{}
        ret tuple _t3 _t4  ; Δ{} · makes heap
        ret tuple _t4 _t5  ; Δ{} · makes heap
      drop _t4
      drop _t5 : List$Int
      drop _t6 : List$Int
      drop _t8 : String
      drop ab
      drop ab : tuple$List$Int$List$Int
      drop m
      drop m
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
      let _t0 = call lt5 y  ; Δ{}
      let _t0 = call product ys  ; Δ{}
      let _t0 = call sum a  ; Δ{ab}
      let _t0 = call sum ys  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = con Cons y a  ; Δ{}
      let _t0 = con Nil  ; Δ{}
      let _t0 = con Nil  ; Δ{}
      let _t1 = call map$$dup ys  ; Δ{_t0 ys} · moves{ys} · makes List$List$Int
      let _t1 = call sum b  ; Δ{ab}
      let _t1 = con Nil  ; Δ{}
      let _t1 = con Nil  ; Δ{}
      let _t2 = < n 1  ; Δ{}
      let _t2 = callclo p y  ; Δ{}
      let _t4 = closure lam$1  ; Δ{} · makes heap
      let _t5 = call range 1 10  ; Δ{_t4} · makes List$Int
      let _t6 = call takeWhile _t4 _t5  ; Δ{_t4 _t5} · makes List$Int
      let _t7 = call sum _t6  ; Δ{_t6}
      let _t8 = call show$Int _t7  ; Δ{} · makes String
      let _t9 = putStrLn _t8  ; Δ{_t8}
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
      ret case _t9 of
      ret case p of
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$List$Int
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Just _t0  ; Δ{} · makes Maybe$Int
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
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
      ret tuple _t0 _t1  ; Δ{} · makes heap
      ret tuple _t0 _t1  ; Δ{} · makes heap
      ret tuple _t0 b  ; Δ{} · makes heap
      ret ys  ; Δ{}
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
  ret _d1000000  ; Δ{}
  ret call concat$Int _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  ret call lt5 eta$1  ; Δ{}
  ret call lt5 eta$3  ; Δ{}
  ret call lt5 eta$5  ; Δ{}
  ret case _t3 of
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
dropWhile p xs  =
dup n  =
findIndex$$lt5 xs  =
fromMaybe d m  =
incMaybe m  =
lam$0 [env ]x  =
lam$1 [env ]eta$1  =
lam$2 [env ]eta$3  =
lam$3 [env ]eta$5  =
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
span p xs  =
splitAt n xs  =
sum xs  =
sumPair ab  =
takeWhile p xs  =
