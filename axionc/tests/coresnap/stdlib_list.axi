






































                                    _ ->
                                _ ->
                            _ ->
                        _ ->
                    _ ->
                _ ->
            _ ->
        _ ->
    _ ->
        (a, b) ->
    (a, b) ->
    (a, b) ->
and xs  =
append xs ys  =
axion_drop_Array _p  =
axion_drop_List$Bool _p  =
axion_drop_List$Int _p  =
axion_drop_List$tuple$Int$Int _p  =
axion_drop_List _p  =
axion_drop_Maybe$Int _p  =
concatMap f xs  =
concat xs  =
consFst y ab  =
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
      drop ab
  drop _t0
  drop _t0 : List$Int
          drop _t10
          drop _t12 : List$Int
          drop _t14 : String
              drop _t16
        drop _t1 : Maybe$Int
              drop _t20 : String
                  drop _t25 : String
                      drop _t27
                      drop _t28 : List$Int
                      drop _t29 : List$Int
  drop _t2 : String
                      drop _t31 : String
                          drop _t37 : List$Bool
                          drop _t39 : String
      drop _t4
                              drop _t45 : List$Bool
                              drop _t47 : String
                                  drop _t53 : List$tuple$Int$Int
                                  drop _t54 : Maybe$Int
                                  drop _t56 : String
                                      drop _t58
      drop _t5 : List$Int
                                      drop _t62 : List$Int
                                      drop _t63 : Maybe$Int
                                      drop _t65 : String
      drop _t6 : List$Int
      drop _t8 : String
dropWhile p xs  =
      drop xs
      drop xs
      drop xs
      drop xs
dup n  =
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
findIndex p xs  =
fromMaybe d m  =
incMaybe m  =
    Just i ->
    Just x ->
lam$0 [env ]x  =
lam$1 [env ]eta$1  =
lam$2 [env ]eta$3  =
lam$3 [env ]eta$5  =
lam$4 [env ]eta$7  =
lam$5 [env ]eta$9  =
        let _d1000000 = call incMaybe _t1  ; Δ{_t1} · makes Maybe$Int
  let _d1000000 = call maybe d _t0 m  ; Δ{_t0}
                                      let _d1000000 = putStrLn _t65  ; Δ{_t65}
  let _dd0 = band _p 1  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List$Bool _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple$Int$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd1 = if _dd0 then
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
          let _t0 = == a k  ; Δ{}
      let _t0 = call append zs ys  ; Δ{z zs} · moves{zs} · makes List
      let _t0 = callclo f y  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = call concat ys  ; Δ{y ys} · moves{ys} · makes List
  let _t0 = call map f xs  ; Δ{} · makes List
      let _t0 = call product ys  ; Δ{}
  let _t0 = call range 1 6  ; Δ{} · makes List$Int
      let _t0 = call sum a  ; Δ{}
      let _t0 = call sum ys  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
      let _t0 = con Cons y a  ; Δ{}
      let _t0 = con Nil  ; Δ{}
      let _t0 = con Nil  ; Δ{}
  let _t0 = con Nil  ; Δ{} · makes List$Int
      let _t0 = + i 1  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
          let _t10 = closure lam$2  ; Δ{} · makes heap
          let _t11 = call range 1 6  ; Δ{_t10} · makes List$Int
          let _t12 = call dropWhile _t10 _t11  ; Δ{_t10 _t11} · moves{_t11} · makes List$Int
          let _t13 = call sum _t12  ; Δ{_t12}
          let _t14 = call show$Int _t13  ; Δ{} · makes String
          let _t15 = putStrLn _t14  ; Δ{_t14}
              let _t16 = closure lam$3  ; Δ{} · makes heap
              let _t17 = call range 1 6  ; Δ{_t16} · makes List$Int
              let _t18 = call span _t16 _t17  ; Δ{_t16 _t17} · moves{_t17}
              let _t19 = call sumPair _t18  ; Δ{}
        let _t1 = call findIndex p ys  ; Δ{} · makes Maybe$Int
      let _t1 = call map f ys  ; Δ{} · makes List
  let _t1 = call product _t0  ; Δ{_t0}
      let _t1 = call sum b  ; Δ{}
        let _t1 = call takeWhile p ys  ; Δ{} · makes List
  let _t1 = con Cons n _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
      let _t1 = con Nil  ; Δ{}
      let _t1 = con Nil  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
              let _t20 = call show$Int _t19  ; Δ{} · makes String
              let _t21 = putStrLn _t20  ; Δ{_t20}
                  let _t22 = call range 1 6  ; Δ{} · makes List$Int
                  let _t23 = call splitAt 2 _t22  ; Δ{_t22} · moves{_t22}
                  let _t24 = call sumPair _t23  ; Δ{}
                  let _t25 = call show$Int _t24  ; Δ{} · makes String
                  let _t26 = putStrLn _t25  ; Δ{_t25}
                      let _t27 = closure lam$4  ; Δ{} · makes heap
                      let _t28 = call range 1 3  ; Δ{_t27} · makes List$Int
                      let _t29 = call concatMap _t27 _t28  ; Δ{_t27 _t28} · makes List$Int
    let _t2 = + acc lo  ; Δ{}
    let _t2 = callclo c lo n  ; Δ{}
      let _t2 = callclo p y  ; Δ{}
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
  let _t2 = call show$Int _t1  ; Δ{} · makes String
      let _t2 = < n 1  ; Δ{}
                      let _t30 = call sum _t29  ; Δ{_t29}
                      let _t31 = call show$Int _t30  ; Δ{} · makes String
                      let _t32 = putStrLn _t31  ; Δ{_t31}
                          let _t33 = 1  ; Δ{}
                          let _t34 = 1  ; Δ{}
                          let _t35 = con Nil  ; Δ{} · makes List$Bool
                          let _t36 = con Cons _t34 _t35  ; Δ{_t35} · moves{_t35} · makes List$Bool
                          let _t37 = con Cons _t33 _t36  ; Δ{_t36} · moves{_t36} · makes List$Bool
                          let _t38 = call and _t37  ; Δ{_t37}
                          let _t39 = call show$Bool _t38  ; Δ{} · makes String
        let _t3 = call span p ys  ; Δ{}
        let _t3 = con Nil  ; Δ{}
  let _t3 = putStrLn _t2  ; Δ{_t2}
                          let _t40 = putStrLn _t39  ; Δ{_t39}
                              let _t41 = 0  ; Δ{}
                              let _t42 = 0  ; Δ{}
                              let _t43 = con Nil  ; Δ{} · makes List$Bool
                              let _t44 = con Cons _t42 _t43  ; Δ{_t43} · moves{_t43} · makes List$Bool
                              let _t45 = con Cons _t41 _t44  ; Δ{_t44} · moves{_t44} · makes List$Bool
                              let _t46 = call or _t45  ; Δ{_t45}
                              let _t47 = call show$Bool _t46  ; Δ{} · makes String
                              let _t48 = putStrLn _t47  ; Δ{_t47}
                                  let _t49 = tuple 1 10  ; Δ{} · makes heap
      let _t4 = closure lam$1  ; Δ{} · makes heap
        let _t4 = con Cons y ys  ; Δ{}
        let _t4 = con Nil  ; Δ{}
                                  let _t50 = tuple 2 20  ; Δ{_t49} · makes heap
                                  let _t51 = con Nil  ; Δ{_t49 _t50} · makes List$tuple$Int$Int
                                  let _t52 = con Cons _t50 _t51  ; Δ{_t49 _t50 _t51} · moves{_t50 _t51} · makes List$tuple$Int$Int
                                  let _t53 = con Cons _t49 _t52  ; Δ{_t49 _t52} · moves{_t49 _t52} · makes List$tuple$Int$Int
                                  let _t54 = call lookup$Int 2 _t53  ; Δ{_t53} · makes Maybe$Int
                                  let _t55 = call fromMaybe 99 _t54  ; Δ{_t54}
                                  let _t56 = call show$Int _t55  ; Δ{} · makes String
                                  let _t57 = putStrLn _t56  ; Δ{_t56}
                                      let _t58 = closure lam$5  ; Δ{} · makes heap
                                      let _t59 = con Nil  ; Δ{_t58} · makes List$Int
      let _t5 = call range 1 10  ; Δ{_t4} · makes List$Int
        let _t5 = con Cons y ys  ; Δ{}
        let _t5 = - n 1  ; Δ{}
                                      let _t60 = con Cons 2 _t59  ; Δ{_t58 _t59} · moves{_t59} · makes List$Int
                                      let _t61 = con Cons 8 _t60  ; Δ{_t58 _t60} · moves{_t60} · makes List$Int
                                      let _t62 = con Cons 9 _t61  ; Δ{_t58 _t61} · moves{_t61} · makes List$Int
                                      let _t63 = call findIndex _t58 _t62  ; Δ{_t58 _t62} · makes Maybe$Int
                                      let _t64 = call fromMaybe 99 _t63  ; Δ{_t63}
                                      let _t65 = call show$Int _t64  ; Δ{} · makes String
        let _t6 = call splitAt _t5 ys  ; Δ{}
      let _t6 = call takeWhile _t4 _t5  ; Δ{_t4 _t5} · makes List$Int
      let _t7 = call sum _t6  ; Δ{_t6}
      let _t8 = call show$Int _t7  ; Δ{} · makes String
      let _t9 = putStrLn _t8  ; Δ{_t8}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
lookup$Int k xs  =
lt5 n  =
main  =
map f xs  =
maybe d f m  =
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
or xs  =
product xs  =
rangeFused lo hi c n  =
rangeFusedSum lo hi acc  =
range lo hi  =
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
    ret acc  ; Δ{}
        ret call and ys  ; Δ{}
      ret call append y _t0  ; Δ{_t0 y} · moves{_t0 y} · makes List
      ret callclo f x  ; Δ{}
  ret call concat _t0  ; Δ{_t0} · moves{_t0} · makes List
        ret call consFst y _t3  ; Δ{}
        ret call consFst y _t6  ; Δ{}
        ret call dropWhile p ys  ; Δ{} · makes List
  ret call dup eta$7  ; Δ{} · makes List$Int
            ret call lookup$Int k ps  ; Δ{} · makes Maybe
  ret call lt5 eta$1  ; Δ{}
  ret call lt5 eta$3  ; Δ{}
  ret call lt5 eta$5  ; Δ{}
  ret call lt5 eta$9  ; Δ{}
        ret call or ys  ; Δ{}
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
  ret case ab of
  ret case ab of
  ret case m of
  ret case m of
      ret case p of
          ret case _t15 of
              ret case _t21 of
                  ret case _t26 of
                      ret case _t32 of
  ret case _t3 of
                          ret case _t40 of
                              ret case _t48 of
                                  ret case _t57 of
      ret case _t9 of
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
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  ret con Cons n _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
        ret con Cons y _t1  ; Δ{_t1} · moves{_t1}
        ret con Cons y ys  ; Δ{}
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
        ret con Just 0  ; Δ{} · makes Maybe$Int
            ret con Just b  ; Δ{}
      ret con Just _t0  ; Δ{} · makes Maybe$Int
        ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
    ret con Nil  ; Δ{} · makes List$Int
      ret con Nothing  ; Δ{}
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret con Nothing  ; Δ{} · makes Maybe$Int
                                      ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret d  ; Δ{}
    ret "false"  ; Δ{}
          ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
      ret if _t2 then
      ret if _t2 then
  ret if x then
      ret if y then
      ret if y then
  ret < n 5  ; Δ{}
    ret n  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
      ret + _t0 _t1  ; Δ{}
    ret "true"  ; Δ{}
      ret tuple _t0 b  ; Δ{} · makes heap
      ret tuple _t0 _t1  ; Δ{} · makes heap
      ret tuple _t0 _t1  ; Δ{} · makes heap
        ret tuple _t3 _t4  ; Δ{} · makes heap
        ret tuple _t4 _t5  ; Δ{} · makes heap
  ret x  ; Δ{}
      ret ys  ; Δ{}
      ret * y _t0  ; Δ{}
      ret + y _t0  ; Δ{}
show$Bool x  =
show$Int x  =
span p xs  =
splitAt n xs  =
sumPair ab  =
sum xs  =
takeWhile p xs  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
