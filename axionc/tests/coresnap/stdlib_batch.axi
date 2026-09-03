


























          drop _t0
          drop _t0
          let _t1 = call mapMaybe$$half ys  ; Δ{z} · makes List$Int
          ret call mapMaybe$$half ys  ; Δ{} · makes List$Int
          ret con Cons z _t1  ; Δ{_t1 z} · moves{_t1 z} · makes List$Int
        Just z ->
        Nothing ->
        drop _t1 : Maybe$Int
        let _d1000000 = call incMaybe _t1  ; Δ{_t1} · makes Maybe$Int
        let _t1 = call findIndex p ys  ; Δ{} · makes Maybe$Int
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
        ret con Just 0  ; Δ{} · makes Maybe$Int
      drop m
      drop m
      drop m : Maybe$Int
      drop m : Maybe$Int
      drop p
      drop p
      drop p
      drop p : tuple$Int$Int
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = + i 1  ; Δ{}
      let _t0 = call half y  ; Δ{} · makes Maybe$Int
      let _t0 = call length ys  ; Δ{}
      let _t0 = callclo p y  ; Δ{}
      let _t0 = con Nil  ; Δ{x}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret a  ; Δ{}
      ret a  ; Δ{}
      ret b  ; Δ{}
      ret call minus a b  ; Δ{}
      ret case _t0 of
      ret con Cons x _t0  ; Δ{x} · moves{x}
      ret con Just _t0  ; Δ{} · makes Maybe$Int
      ret con Just y  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{} · makes List$Int
      ret con Nothing  ; Δ{}
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret i  ; Δ{i} · moves{i}
      ret if _t0 then
    (a, b) ->
    (a, b) ->
    (a, b) ->
    (a, b) ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Just i ->
    Just i ->
    Just x ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nothing ->
    Nothing ->
    Nothing ->
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
  ; Δ{_t0}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
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
  drop _t14 : List$Int
  drop _t15 : List$Int
  drop _t19 : List$Int
  drop _t23 : List$Int
  drop _t29 : List$Int
  drop _t38 : String
  else
  else
  else
  let _d1000000 = call findIndex _t0 xs  ; Δ{_t0} · makes Maybe$Int
  let _d1000000 = putStrLn _t38  ; Δ{_t38}
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = + n n  ; Δ{}
  let _t0 = closure lam$0 x  ; Δ{} · makes heap
  let _t0 = tuple 10 99  ; Δ{} · makes heap
  let _t0 = tuple x y  ; Δ{} · makes heap
  let _t1 = call fst$Int$Int _t0  ; Δ{_t0} · moves{_t0}
  let _t10 = call uncurry$$minus _t9  ; Δ{_t9} · moves{_t9}
  let _t11 = + _t8 _t10  ; Δ{}
  let _t12 = con Nil  ; Δ{} · makes List$Int
  let _t13 = con Cons 2 _t12  ; Δ{_t12} · moves{_t12} · makes List$Int
  let _t14 = con Cons 1 _t13  ; Δ{_t13} · moves{_t13} · makes List$Int
  let _t15 = call mapMaybe$$half _t14  ; Δ{_t14} · makes List$Int
  let _t16 = call length _t15  ; Δ{_t15}
  let _t17 = + _t11 _t16  ; Δ{}
  let _t18 = con Just 5  ; Δ{} · makes Maybe$Int
  let _t19 = call maybeToList$Int _t18  ; Δ{_t18} · moves{_t18} · makes List$Int
  let _t2 = tuple 7 5  ; Δ{} · makes heap
  let _t20 = call length _t19  ; Δ{_t19}
  let _t21 = + _t17 _t20  ; Δ{}
  let _t22 = con Nil  ; Δ{} · makes List$Int
  let _t23 = con Cons 6 _t22  ; Δ{_t22} · moves{_t22} · makes List$Int
  let _t24 = call listToMaybe _t23  ; Δ{_t23} · makes Maybe$Int
  let _t25 = call idxOr _t24  ; Δ{_t24} · moves{_t24}
  let _t26 = + _t21 _t25  ; Δ{}
  let _t27 = con Nil  ; Δ{} · makes List$Int
  let _t28 = con Cons 3 _t27  ; Δ{_t27} · moves{_t27} · makes List$Int
  let _t29 = con Cons 1 _t28  ; Δ{_t28} · moves{_t28} · makes List$Int
  let _t3 = call snd$Int$Int _t2  ; Δ{_t2} · moves{_t2}
  let _t30 = call elemIndex$Int 3 _t29  ; Δ{_t29} · makes Maybe$Int
  let _t31 = call idxOr _t30  ; Δ{_t30} · moves{_t30}
  let _t32 = + _t26 _t31  ; Δ{}
  let _t33 = 1  ; Δ{}
  let _t34 = call const 6 _t33  ; Δ{}
  let _t35 = + _t32 _t34  ; Δ{}
  let _t36 = call id 1  ; Δ{}
  let _t37 = + _t35 _t36  ; Δ{}
  let _t38 = call show$Int _t37  ; Δ{} · makes String
  let _t4 = + _t1 _t3  ; Δ{}
  let _t5 = call flip$$minus 3 20  ; Δ{}
  let _t6 = + _t4 _t5  ; Δ{}
  let _t7 = call curry$$fst 4 100  ; Δ{}
  let _t8 = + _t6 _t7  ; Δ{}
  let _t9 = tuple 30 1  ; Δ{} · makes heap
  ret - x y  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret == x y  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{}
  ret call eq$Int x y  ; Δ{}
  ret call fst _t0  ; Δ{_t0} · moves{_t0}
  ret call minus y x  ; Δ{}
  ret case m of
  ret case m of
  ret case m of
  ret case p of
  ret case p of
  ret case p of
  ret case p of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Just _t0  ; Δ{} · makes Maybe$Int
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret x  ; Δ{}
  ret x  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_Maybe$Int _p  =
axion_drop_tuple$Int$Int _p  =
const x y  =
curry$$fst x y  =
elemIndex$Int x xs  =
eq$Int x y  =
findIndex p xs  =
flip$$minus x y  =
fst p  =
fst$Int$Int p  =
half n  =
id x  =
idxOr m  =
incMaybe m  =
lam$0 [env x]y  =
length xs  =
listToMaybe xs  =
main  =
mapMaybe$$half xs  =
maybeToList$Int m  =
minus x y  =
show$Int x  =
snd$Int$Int p  =
uncurry$$minus p  =
