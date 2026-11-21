


























                              drop _t40 : String
                              let _d1000000 = putStrLn _t40  ; Δ{_t40}
                              let _t40 = call tempPart 9  ; Δ{} · makes String
                              ret _d1000000  ; Δ{}
                            _ ->
                          drop _t36 : tuple2$Int$Int
                          drop _t38 : String
                          let _t36 = tuple 4 2  ; Δ{} · makes heap
                          let _t37 = call local _t36  ; Δ{_t36}
                          let _t38 = showInt _t37  ; Δ{} · makes String
                          let _t39 = putStrLn _t38  ; Δ{_t38}
                          ret case _t39 of
                        _ ->
                      drop _t30 : String
                      drop _t33 : String
                      drop _t34 : String
                      let _t29 = call pairK 7  ; Δ{} · makes tuple2$String$Int
                      let _t30 = call fst$String$Int _t29  ; Δ{_t29} · moves{_t29} · makes String
                      let _t31 = rtcall axion_strcat "v" "w"  ; Δ{_t30} · makes String
                      let _t32 = tuple "u" _t31  ; Δ{_t30 _t31} · moves{_t31} · makes heap
                      let _t33 = call snd$String$String _t32  ; Δ{_t30 _t32} · moves{_t32} · makes String
                      let _t34 = rtcall axion_strcat _t30 _t33  ; Δ{_t30 _t33} · makes String
                      let _t35 = putStrLn _t34  ; Δ{_t34}
                      ret case _t35 of
                    _ ->
                  drop _t20 : List$tuple2$String$Int
                  drop _t24 : List$tuple2$String$Int
                  drop _t27 : String
                  let _t18 = rtcall axion_strcat "q" ""  ; Δ{} · makes String
                  let _t19 = tuple _t18 2  ; Δ{_t18} · moves{_t18} · makes heap
                  let _t20 = call keepIf _t19  ; Δ{_t19} · moves{_t19} · makes List$tuple2$String$Int
                  let _t21 = call length _t20  ; Δ{_t20}
                  let _t22 = rtcall axion_strcat "r" ""  ; Δ{} · makes String
                  let _t23 = tuple _t22 0  ; Δ{_t22} · moves{_t22} · makes heap
                  let _t24 = call keepIf _t23  ; Δ{_t23} · moves{_t23} · makes List$tuple2$String$Int
                  let _t25 = call length _t24  ; Δ{_t24}
                  let _t26 = + _t21 _t25  ; Δ{}
                  let _t27 = showInt _t26  ; Δ{} · makes String
                  let _t28 = putStrLn _t27  ; Δ{_t27}
                  ret case _t28 of
                _ ->
              drop _t15 : tuple2$String$Int
              drop _t16 : String
              let _t14 = rtcall axion_strcat "x" "y"  ; Δ{} · makes String
              let _t15 = tuple _t14 4  ; Δ{_t14} · moves{_t14} · makes heap
              let _t16 = call again _t15  ; Δ{_t15} · makes String
              let _t17 = putStrLn _t16  ; Δ{_t16}
              ret case _t17 of
            _ ->
          drop _t12 : String
          drop _t8 : List$String
          drop ps : List$tuple2$String$Int
          let _t10 = call length ps  ; Δ{ps}
          let _t11 = + _t9 _t10  ; Δ{}
          let _t12 = showInt _t11  ; Δ{} · makes String
          let _t13 = putStrLn _t12  ; Δ{_t12}
          let _t8 = call firsts ps  ; Δ{ps} · makes List$String
          let _t9 = call length _t8  ; Δ{_t8 ps}
          ret $tup5  ; Δ{}
          ret case _t13 of
        ($tup5, _) ->
        _ ->
        drop y : tuple2$String$Int
        let _t1 = call filter$$hoflam10 ys  ; Δ{y ys} · moves{ys} · makes List$tuple2$String$Int
        ret call filter$$hoflam10 ys  ; Δ{ys} · moves{ys} · makes List$tuple2$String$Int
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$tuple2$String$Int
      drop _t0 : String
      drop _t0 : tuple2$String$Int skip{0}
      drop _t1 : String
      drop _t5 : List$String
      drop _t6 : String
      drop p : tuple2$String$Int skip{0}
      drop p : tuple2$String$String skip{1}
      drop xs
      drop xs
      drop xs
      drop xs : List$tuple2$String$Int
      else
      let $borrowcopy0 = rtcall axion_strcat _t0 ""  ; Δ{_t1} · makes String
      let _d1000000 = rtcall axion_strcat a _t1  ; Δ{_t1} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple2$String$Int _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_tuple2$String$Int _dd2  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = * a 10  ; Δ{}
      let _t0 = call catL rest  ; Δ{} · makes String
      let _t0 = call fst$String$Int y  ; Δ{y ys} · moves{y} · makes String
      let _t0 = call hoflam10 y  ; Δ{y ys}
      let _t0 = call hoflam12 y  ; Δ{} · makes String
      let _t0 = call length ys  ; Δ{}
      let _t0 = case y of
      let _t1 = call firsts ys  ; Δ{} · makes List$String
      let _t1 = call map$$fst$String$Int ys  ; Δ{_t0 ys} · moves{ys} · makes List$String
      let _t1 = call map$$hoflam12 ys  ; Δ{_t0} · makes List$String
      let _t1 = rtcall axion_strcat "," _t0  ; Δ{_t0} · makes String
      let _t5 = call map$$hoflam12 ps  ; Δ{ps} · makes List$String
      let _t6 = call catL _t5  ; Δ{_t5 ps} · makes String
      let _t7 = putStrLn _t6  ; Δ{_t6 ps}
      let ps = call mkPs 0  ; Δ{} · makes List$tuple2$String$Int
      ret "."  ; Δ{}
      ret $tup0  ; Δ{}
      ret $tup1  ; Δ{}
      ret $tup2  ; Δ{}
      ret $tup3  ; Δ{_t2}
      ret $tup4  ; Δ{y}
      ret $tup6  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret + _t0 b  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret a  ; Δ{_t0}
      ret a  ; Δ{p}
      ret b  ; Δ{p}
      ret case _t7 of
      ret con Cons $borrowcopy0 _t1  ; Δ{$borrowcopy0 _t1} · moves{$borrowcopy0 _t1} · makes List$String
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1}
      ret con Cons _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes List$String
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$String
      ret con Nil  ; Δ{} · makes List$tuple2$String$Int
      ret if _t0 then
    ($tup1, _) ->
    ($tup3, _) ->
    ($tup6, _) ->
    (_, $tup0) ->
    (_, $tup2) ->
    (_, $tup4) ->
    (a, _) ->
    (a, b) ->
    (a, b) ->
    (a, b) ->
    Cons a rest ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    _ ->
    drop y : tuple2$String$Int
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t2 = con Nil  ; Δ{y} · makes List$tuple2$String$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret con Cons y _t2  ; Δ{_t2 y} · moves{_t2 y} · makes List$tuple2$String$Int
    ret con Nil  ; Δ{} · makes List$tuple2$String$Int
  ; Δ{_t0}
  ; Δ{_t2}
  ; Δ{ps}
  ; Δ{y ys}
  ; Δ{y}
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
  drop _t2 : List$String
  drop _t2 : String
  drop _t3 : String
  drop _t4 : String
  drop _t5 : String
  drop s : String
  else
  else
  else
  else
  let _d1000000 = rtcall axion_strcat _t0 _t5  ; Δ{_t5} · makes String
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _rcl2000000 = rtcall axion_strcat s "!"  ; Δ{_t0} · makes String
  let _t0 = call mkPs 0  ; Δ{} · makes List$tuple2$String$Int
  let _t0 = call pairK n  ; Δ{} · makes tuple2$String$Int
  let _t0 = case p of
  let _t0 = case p of
  let _t0 = case p of
  let _t0 = case y of
  let _t0 = rtcall axion_strcat "a" ""  ; Δ{} · makes String
  let _t0 = showInt n  ; Δ{} · makes String
  let _t1 = + k 1  ; Δ{_t0}
  let _t1 = > _t0 0  ; Δ{y}
  let _t1 = call big _t0  ; Δ{_t0} · moves{_t0} · makes List$tuple2$String$Int
  let _t1 = case p of
  let _t10 = con Cons _t8 _t9  ; Δ{_t2 _t5 _t8 _t9} · moves{_t8 _t9} · makes List$tuple2$String$Int
  let _t11 = con Cons _t5 _t10  ; Δ{_t10 _t2 _t5} · moves{_t10 _t5} · makes List$tuple2$String$Int
  let _t2 = call map$$fst$String$Int _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = showInt _t1  ; Δ{} · makes String
  let _t2 = tuple _t0 _t1  ; Δ{_t0} · moves{_t0} · makes heap
  let _t3 = call catL _t2  ; Δ{_t2} · makes String
  let _t3 = case p of
  let _t3 = rtcall axion_strcat "bb" ""  ; Δ{_t2} · makes String
  let _t4 = + k 2  ; Δ{_t2 _t3}
  let _t4 = putStrLn _t3  ; Δ{_t3}
  let _t4 = rtcall axion_strcat _t2 _t3  ; Δ{_t2} · makes String
  let _t5 = rtcall axion_strcat ":" _t4  ; Δ{_t4} · makes String
  let _t5 = tuple _t3 _t4  ; Δ{_t2 _t3} · moves{_t3} · makes heap
  let _t6 = rtcall axion_strcat "ccc" ""  ; Δ{_t2 _t5} · makes String
  let _t7 = + k 3  ; Δ{_t2 _t5 _t6}
  let _t8 = tuple _t6 _t7  ; Δ{_t2 _t5 _t6} · moves{_t6} · makes heap
  let _t9 = con Nil  ; Δ{_t2 _t5 _t8} · makes List$tuple2$String$Int
  let s = case _t0 of
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret > _t0 1  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _rcl2000000  ; Δ{_rcl2000000 _t0} · moves{_rcl2000000}
  ret call filter$$hoflam10 ps  ; Δ{} · makes List$tuple2$String$Int
  ret call local$local$fst$let0 q  ; Δ{}
  ret case _t4 of
  ret case p of
  ret case p of
  ret case p of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Cons _t2 _t11  ; Δ{_t11 _t2} · moves{_t11 _t2} · makes List$tuple2$String$Int
  ret if _t1 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_strcat _t0 "!"  ; Δ{} · makes String
  ret tuple _t0 n  ; Δ{_t0} · moves{_t0} · makes heap
again p  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
axion_drop_List$tuple2$String$Int _p  =
axion_drop_tuple2$Int$Int _p  =
axion_drop_tuple2$String$Int _p  =
axion_drop_tuple2$String$String _p  =
axion_drop_tuple2$String$String_skip_1 _p  =
big ps  =
catL xs  =
filter$$hoflam10 xs  =
firsts xs  =
fst$String$Int p  =
hoflam10 p  =
hoflam12 p  =
keepIf y  =
length xs  =
local q  =
local$local$fst$let0 p  =
main  =
map$$fst$String$Int xs  =
map$$hoflam12 xs  =
mkPs k  =
pairK n  =
snd$String$String p  =
tempPart n  =
