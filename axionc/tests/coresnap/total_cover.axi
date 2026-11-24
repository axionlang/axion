

















                  drop _t49 : List$tuple2$Int$Int
                  drop _t51 : String
                  let _d1000000 = putStrLn _t51  ; Δ{_t51}
                  let _t45 = tuple 1 2  ; Δ{} · makes heap
                  let _t46 = tuple 3 4  ; Δ{_t45} · makes heap
                  let _t47 = con Nil  ; Δ{_t45 _t46} · makes List$tuple2$Int$Int
                  let _t48 = con Cons _t46 _t47  ; Δ{_t45 _t46 _t47} · moves{_t46 _t47} · makes List$tuple2$Int$Int
                  let _t49 = con Cons _t45 _t48  ; Δ{_t45 _t48} · moves{_t45 _t48} · makes List$tuple2$Int$Int
                  let _t50 = call pairSum _t49  ; Δ{_t49}
                  let _t51 = showInt _t50  ; Δ{} · makes String
                  ret _d1000000  ; Δ{}
                _ ->
              drop _t0 : tuple2$Bool$Bool
              drop _t0 : tuple2$Bool$Bool
              drop _t0 : tuple2$Bool$Bool
              drop _t0 : tuple2$Bool$Bool
              drop _t36 : Shape
              drop _t37 : Shape
              drop _t43 : String
              let _t29 = 1  ; Δ{}
              let _t30 = 0  ; Δ{}
              let _t31 = call both _t29 _t30  ; Δ{}
              let _t32 = 0  ; Δ{}
              let _t33 = 1  ; Δ{}
              let _t34 = call both _t32 _t33  ; Δ{}
              let _t35 = + _t31 _t34  ; Δ{}
              let _t36 = con Dot  ; Δ{} · makes Shape
              let _t37 = con Circle 5  ; Δ{_t36} · makes Shape
              let _t38 = call sizeOf _t36 _t37  ; Δ{_t36 _t37}
              let _t39 = + _t35 _t38  ; Δ{}
              let _t40 = con Nothing  ; Δ{} · makes Maybe$Int
              let _t41 = call orElse _t40 9  ; Δ{_t40} · moves{_t40}
              let _t42 = + _t39 _t41  ; Δ{}
              let _t43 = showInt _t42  ; Δ{} · makes String
              let _t44 = putStrLn _t43  ; Δ{_t43}
              ret 0  ; Δ{}
              ret 1  ; Δ{}
              ret 2  ; Δ{}
              ret 3  ; Δ{}
              ret case _t44 of
            False ->
            False ->
            True ->
            True ->
            _ ->
          drop _t23 : String
          drop _t24 : String
          drop _t25 : String
          drop _t26 : String
          drop _t27 : String
          let _t23 = call describe 0  ; Δ{} · makes String
          let _t24 = call describe 1  ; Δ{_t23} · makes String
          let _t25 = call describe 7  ; Δ{_t23 _t24} · makes String
          let _t26 = rtcall axion_strcat _t24 _t25  ; Δ{_t23 _t24 _t25} · makes String
          let _t27 = rtcall axion_strcat _t23 _t26  ; Δ{_t23 _t26} · makes String
          let _t28 = putStrLn _t27  ; Δ{_t27}
          ret case $nf2 of
          ret case $nf2 of
          ret case _t28 of
          ret x  ; Δ{}
          ret y  ; Δ{}
        False ->
        LCons y _ ->
        LNil ->
        True ->
        _ ->
      drop _t13 : Shape
      drop _t15 : Shape
      drop _t18 : Shape
      drop _t21 : String
      drop m
      drop m
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple2$Int$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_Lst _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_tuple2$Int$Int _dd2  ; Δ{}
      let _t0 = + acc a  ; Δ{}
      let _t0 = call hoflam11 z y  ; Δ{}
      let _t13 = con Rect 2 3  ; Δ{} · makes Shape
      let _t14 = call classify _t13  ; Δ{_t13}
      let _t15 = con Circle 4  ; Δ{} · makes Shape
      let _t16 = call classify _t15  ; Δ{_t15}
      let _t17 = + _t14 _t16  ; Δ{}
      let _t18 = con Dot  ; Δ{} · makes Shape
      let _t19 = call classify _t18  ; Δ{_t18}
      let _t20 = + _t17 _t19  ; Δ{}
      let _t21 = showInt _t20  ; Δ{} · makes String
      let _t22 = putStrLn _t21  ; Δ{_t21}
      ret "many"  ; Δ{}
      ret "one"  ; Δ{}
      ret "zero"  ; Δ{}
      ret * w h  ; Δ{}
      ret + _t0 b  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret call foldl$$hoflam11 _t0 ys  ; Δ{}
      ret case $nf1 of
      ret case $nf1 of
      ret case _t22 of
      ret d  ; Δ{}
      ret r  ; Δ{}
      ret x  ; Δ{x} · moves{x}
      ret z  ; Δ{}
    ($nf1, $nf2) ->
    (a, b) ->
    0 ->
    1 ->
    Circle r ->
    Cons y ys ->
    Dot ->
    Just x ->
    LCons x $nf1 ->
    LNil ->
    Nil ->
    Nothing ->
    Rect w h ->
    _ ->
    _ ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
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
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
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
  ; Δ{}
  drop _t11 : String
  drop _t2 : Lst
  drop _t5 : Lst
  drop _t8 : Lst
  else
  else
  else
  else
  let _dd0 = band _p 1  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = con LNil  ; Δ{} · makes Lst
  let _t0 = tuple a b  ; Δ{} · makes heap
  let _t1 = con LCons 2 _t0  ; Δ{_t0} · moves{_t0} · makes Lst
  let _t10 = + _t3 _t9  ; Δ{}
  let _t11 = showInt _t10  ; Δ{} · makes String
  let _t12 = putStrLn _t11  ; Δ{_t11}
  let _t2 = con LCons 1 _t1  ; Δ{_t1} · moves{_t1} · makes Lst
  let _t3 = call firstTwo _t2  ; Δ{_t2}
  let _t4 = con LNil  ; Δ{} · makes Lst
  let _t5 = con LCons 1 _t4  ; Δ{_t4} · moves{_t4} · makes Lst
  let _t6 = con LNil  ; Δ{_t5} · makes Lst
  let _t7 = con LCons 3 _t6  ; Δ{_t5 _t6} · moves{_t6} · makes Lst
  let _t8 = con LCons 2 _t7  ; Δ{_t5 _t7} · moves{_t7} · makes Lst
  let _t9 = call zipLen _t5 _t8  ; Δ{_t5 _t8}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret <unsupported: constructor pattern in a multi-clause function head — interpreter only>  ; Δ{}
  ret <unsupported: constructor pattern in a multi-clause function head — interpreter only>  ; Δ{}
  ret call foldl$$hoflam11 0 ps  ; Δ{}
  ret case _p1 of
  ret case _t0 of
  ret case _t12 of
  ret case l of
  ret case m of
  ret case n of
  ret case s of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$tuple2$Int$Int _p  =
axion_drop_Lst _p  =
axion_drop_Maybe$Int _p  =
axion_drop_tuple2$Bool$Bool _p  =
axion_drop_tuple2$Int$Int _p  =
both a b  =
classify s  =
describe n  =
firstTwo l  =
foldl$$hoflam11 z xs  =
hoflam11 acc _p1  =
main  =
orElse m d  =
pairSum ps  =
sizeOf _p0 _p1  =
zipLen _p0 _p1  =
