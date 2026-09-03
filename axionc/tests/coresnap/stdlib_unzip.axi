


















        (a, b) ->
    (a, b) ->
        (a, b, c) ->
add3 a b c  =
    (as_, bs) ->
axion_drop_Array _p  =
axion_drop_List$Int _p  =
axion_drop_List$tuple$Int$Int$Int _p  =
axion_drop_List$tuple$Int$Int _p  =
axion_drop_List _p  =
axion_drop_tuple$Int$Int$Int _p  =
axion_drop_tuple$Int$Int _p  =
axion_drop_tuple$List$Int$List$Int _p  =
    Cons a as_ ->
        Cons b bs ->
consBoth a b ab  =
            Cons c cs ->
    Cons p ps ->
    Cons t rest ->
    Cons y ys ->
      drop ab
      drop ab : tuple$List$Int$List$Int
  drop _t0
  drop _t12 : List$Int
  drop _t15 : List$Int
  drop _t16 : List$tuple$Int$Int$Int
  drop _t19 : String
  drop _t4 : List$tuple$Int$Int
  drop _t9 : List$Int
    else
    else
    else
    else
  else
  else
  else
  else
lam$0 [env ]a b c  =
  let _d1000000 = call zipWith3 _t0 xs ys zs  ; Δ{_t0} · makes List
  let _d1000000 = putStrLn _t19  ; Δ{_t19}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
  let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple$Int$Int$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple$Int$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
  let _dd3 = call axion_drop_List$Int _dd2  ; Δ{}
      let _dd3 = call axion_drop_tuple$Int$Int$Int _dd2  ; Δ{}
      let _dd3 = call axion_drop_tuple$Int$Int _dd2  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
          let _t0 = + a b  ; Δ{}
  let _t0 = + a b  ; Δ{}
              let _t0 = callclo f a b c  ; Δ{}
      let _t0 = call sum a  ; Δ{ab}
      let _t0 = call sum ys  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
      let _t0 = con Cons a as_  ; Δ{}
      let _t0 = con Nil  ; Δ{}
  let _t0 = tuple 1 2  ; Δ{} · makes heap
  let _t10 = con Nil  ; Δ{_t9} · makes List$Int
  let _t11 = con Cons 20 _t10  ; Δ{_t10 _t9} · moves{_t10} · makes List$Int
  let _t12 = con Cons 10 _t11  ; Δ{_t11 _t9} · moves{_t11} · makes List$Int
  let _t13 = con Nil  ; Δ{_t12 _t9} · makes List$Int
  let _t14 = con Cons 200 _t13  ; Δ{_t12 _t13 _t9} · moves{_t13} · makes List$Int
  let _t15 = con Cons 100 _t14  ; Δ{_t12 _t14 _t9} · moves{_t14} · makes List$Int
  let _t16 = call zip3 _t9 _t12 _t15  ; Δ{_t12 _t15 _t9} · makes List$tuple$Int$Int$Int
  let _t17 = call sum3 _t16  ; Δ{_t16}
  let _t18 = + _t6 _t17  ; Δ{}
  let _t19 = call show$Int _t18  ; Δ{} · makes String
      let _t1 = call sum b  ; Δ{ab}
              let _t1 = call zipWith3 f as_ bs cs  ; Δ{} · makes List
      let _t1 = con Cons b bs  ; Δ{}
      let _t1 = con Nil  ; Δ{}
          let _t1 = + _t0 c  ; Δ{}
  let _t1 = tuple 3 4  ; Δ{_t0} · makes heap
          let _t2 = call sum3 rest  ; Δ{}
          let _t2 = call unzip ps  ; Δ{}
  let _t2 = con Nil  ; Δ{_t0 _t1} · makes List$tuple$Int$Int
  let _t3 = con Cons _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t1 _t2} · makes List$tuple$Int$Int
  let _t4 = con Cons _t0 _t3  ; Δ{_t0 _t3} · moves{_t0 _t3} · makes List$tuple$Int$Int
  let _t5 = call unzip _t4  ; Δ{_t4}
  let _t6 = call sumBoth _t5  ; Δ{}
  let _t7 = con Nil  ; Δ{} · makes List$Int
  let _t8 = con Cons 2 _t7  ; Δ{_t7} · moves{_t7} · makes List$Int
  let _t9 = con Cons 1 _t8  ; Δ{_t8} · moves{_t8} · makes List$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
main  =
            Nil ->
        Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
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
          ret call consBoth a b _t2  ; Δ{}
  ret case ab of
  ret case ab of
      ret case p of
      ret case t of
  ret case ts of
  ret case xs of
  ret case xs of
  ret case xs of
      ret case ys of
          ret case zs of
              ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1}
              ret con Nil  ; Δ{}
          ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret + _t0 c  ; Δ{}
      ret + _t0 _t1  ; Δ{}
          ret + _t1 _t2  ; Δ{}
  ret tuple a b c  ; Δ{} · makes heap
      ret tuple _t0 _t1  ; Δ{} · makes heap
      ret tuple _t0 _t1  ; Δ{} · makes heap
      ret + y _t0  ; Δ{}
show$Int x  =
sum3 ts  =
sumBoth ab  =
sum xs  =
unzip xs  =
zip3 xs ys zs  =
zipWith3 f xs ys zs  =
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
