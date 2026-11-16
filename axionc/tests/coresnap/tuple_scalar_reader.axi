




















                      drop _t28 : tuple2$String$Int
                      drop _t30 : String
                      let _d1000000 = putStrLn _t30  ; Δ{_t30}
                      let _t28 = call mkp 5  ; Δ{} · makes tuple2$String$Int
                      let _t29 = call sndof _t28  ; Δ{_t28}
                      let _t30 = call show$Int _t29  ; Δ{} · makes String
                      ret _d1000000  ; Δ{}
                    _ ->
                  drop _t24 : tuple2$Integer$Int
                  drop _t26 : String
                  let _t24 = call mkb 8  ; Δ{} · makes tuple2$Integer$Int
                  let _t25 = call useOwned _t24  ; Δ{_t24}
                  let _t26 = call show$Int _t25  ; Δ{} · makes String
                  let _t27 = putStrLn _t26  ; Δ{_t26}
                  ret case _t27 of
                _ ->
              drop _t19 : List$tuple2$String$Int
              drop _t20 : List$Int
              drop _t22 : String
              let _t13 = call mkp 1  ; Δ{} · makes tuple2$String$Int
              let _t14 = call mkp 2  ; Δ{_t13} · makes tuple2$String$Int
              let _t15 = call mkp 3  ; Δ{_t13 _t14} · makes tuple2$String$Int
              let _t16 = con Nil  ; Δ{_t13 _t14 _t15} · makes List$tuple2$String$Int
              let _t17 = con Cons _t15 _t16  ; Δ{_t13 _t14 _t15 _t16} · moves{_t15 _t16} · makes List$tuple2$String$Int
              let _t18 = con Cons _t14 _t17  ; Δ{_t13 _t14 _t17} · moves{_t14 _t17} · makes List$tuple2$String$Int
              let _t19 = con Cons _t13 _t18  ; Δ{_t13 _t18} · moves{_t13 _t18} · makes List$tuple2$String$Int
              let _t20 = call map$$sndof _t19  ; Δ{_t19} · makes List$Int
              let _t21 = call length _t20  ; Δ{_t20}
              let _t22 = call show$Int _t21  ; Δ{} · makes String
              let _t23 = putStrLn _t22  ; Δ{_t22}
              ret case _t23 of
            _ ->
          drop _t10 : String
          drop _t11 : String
          drop _t9 : String
          let _t10 = call show$Int 7  ; Δ{_t9} · makes String
          let _t11 = rtcall axion_strcat _t9 _t10  ; Δ{_t10 _t9} · makes String
          let _t12 = putStrLn _t11  ; Δ{_t11}
          let _t8 = call mkp 7  ; Δ{} · makes tuple2$String$Int
          let _t9 = call keyOf _t8  ; Δ{_t8} · moves{_t8} · makes String
          ret call sndof h  ; Δ{}
          ret case _t12 of
        (h, rest) ->
        _ ->
      drop _t4 : tuple2$String$Int
      drop _t6 : String
      drop t : tuple2$String$Int skip{0}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple2$String$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_tuple2$tuple2$String$Int$List$tuple2$String$Int _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_tuple2$String$Int _dd2  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call sndof y  ; Δ{}
      let _t1 = call map$$sndof ys  ; Δ{} · makes List$Int
      let _t4 = call mkp 7  ; Δ{} · makes tuple2$String$Int
      let _t5 = call twiceRead _t4  ; Δ{_t4}
      let _t6 = call show$Int _t5  ; Δ{} · makes String
      let _t7 = putStrLn _t6  ; Δ{_t6}
      ret + 1 _t0  ; Δ{}
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
      ret a  ; Δ{t}
      ret b  ; Δ{}
      ret b  ; Δ{}
      ret case _t7 of
      ret case p of
      ret con Cons _t0 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
      ret con Nil  ; Δ{} · makes List$Int
    (a, b) ->
    (a, b) ->
    (a, b) ->
    Cons y ys ->
    Cons y ys ->
    Just p ->
    Nil ->
    Nil ->
    Nothing ->
    _ ->
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
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : Maybe$tuple2$tuple2$String$Int$List$tuple2$String$Int
  drop _t2 : String
  else
  else
  else
  else
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_List$tuple2$String$Int _dd0  ; Δ{}
  let _dd1 = rtcall axion_bignum_free _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = call axion_drop_tuple2$String$Int _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call build 9  ; Δ{} · makes Maybe$tuple2$tuple2$String$Int$List$tuple2$String$Int
  let _t0 = call mkp n  ; Δ{} · makes tuple2$String$Int
  let _t0 = call sndof t  ; Δ{}
  let _t0 = rtcall axion_bignum_from_i64 n  ; Δ{} · makes Integer
  let _t1 = + n 1  ; Δ{_t0}
  let _t1 = call pick _t0  ; Δ{_t0}
  let _t1 = call sndof t  ; Δ{}
  let _t2 = call mkp _t1  ; Δ{_t0} · makes tuple2$String$Int
  let _t2 = call show$Int _t1  ; Δ{} · makes String
  let _t3 = con Nil  ; Δ{_t0 _t2} · makes List$tuple2$String$Int
  let _t3 = putStrLn _t2  ; Δ{_t2}
  let _t4 = con Cons _t2 _t3  ; Δ{_t0 _t2 _t3} · moves{_t2 _t3} · makes List$tuple2$String$Int
  let _t5 = tuple _t0 _t4  ; Δ{_t0 _t4} · moves{_t0 _t4} · makes heap
  ret + _t0 _t1  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret call bsnd t  ; Δ{}
  ret case _t3 of
  ret case m of
  ret case t of
  ret case t of
  ret case t of
  ret case xs of
  ret case xs of
  ret con Just _t5  ; Δ{_t5} · moves{_t5} · makes Maybe$tuple2$tuple2$String$Int$List$tuple2$String$Int
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
  ret tuple "k" n  ; Δ{} · makes heap
  ret tuple _t0 n  ; Δ{_t0} · moves{_t0} · makes heap
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
axion_drop_List$tuple2$String$Int _p  =
axion_drop_Maybe$tuple2$tuple2$String$Int$List$tuple2$String$Int _p  =
axion_drop_tuple2$Integer$Int _p  =
axion_drop_tuple2$String$Int _p  =
axion_drop_tuple2$tuple2$String$Int$List$tuple2$String$Int _p  =
bsnd t  =
build n  =
keyOf t  =
length xs  =
main  =
map$$sndof xs  =
mkb n  =
mkp n  =
pick m  =
show$Int x  =
sndof t  =
twiceRead t  =
useOwned t  =
