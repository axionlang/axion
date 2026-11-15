



































          drop s : String
          drop t : tuple2$String$tuple2$String$Int
          drop v
          drop v
          let _d1000000 = rtcall axion_str_len s  ; Δ{m}
          let _t0 = rtcall axion_str_len a  ; Δ{t}
          let _t1 = rtcall axion_str_len c  ; Δ{t}
          let _t2 = + _t0 _t1  ; Δ{t}
          ret + _t2 n  ; Δ{}
          ret _d1000000  ; Δ{m}
          ret n  ; Δ{m}
        (c, n) ->
        JNum n ->
        JStr s ->
        drop y : tuple2$String$Int
        drop y : tuple2$String$Int
        drop y : tuple2$String$Int
        drop y : tuple2$String$Int
        drop y : tuple2$String$Int
        drop y : tuple2$String$Int
        drop y : tuple2$String$J
        drop ys : List$tuple2$String$Int
        let _t1 = call filter$$big ys  ; Δ{y ys} · moves{ys} · makes List$tuple2$String$Int
        let _t1 = call filter$$bigH ys  ; Δ{y ys} · moves{ys} · makes List$tuple2$String$Int
        let _t1 = call filter$$hoflam10 ys  ; Δ{y ys} · moves{ys} · makes List$tuple2$String$Int
        let _t1 = call filter$$hoflam12 ys  ; Δ{y ys} · moves{ys} · makes List$tuple2$String$Int
        let _t1 = call filter$$hoflamcap0 _cap0 ys  ; Δ{y ys} · moves{ys} · makes List$tuple2$String$Int
        let _t1 = call filter$$isK _cap0 ys  ; Δ{y ys} · moves{ys} · makes List$tuple2$String$J
        let _t1 = call takeWhile$$big ys  ; Δ{y ys} · moves{ys} · makes List$tuple2$String$Int
        ret 1  ; Δ{}
        ret call any$$big ys  ; Δ{}
        ret call filter$$big ys  ; Δ{ys} · moves{ys} · makes List$tuple2$String$Int
        ret call filter$$bigH ys  ; Δ{ys} · moves{ys} · makes List$tuple2$String$Int
        ret call filter$$hoflam10 ys  ; Δ{ys} · moves{ys} · makes List$tuple2$String$Int
        ret call filter$$hoflam12 ys  ; Δ{ys} · moves{ys} · makes List$tuple2$String$Int
        ret call filter$$hoflamcap0 _cap0 ys  ; Δ{ys} · moves{ys} · makes List$tuple2$String$Int
        ret call filter$$isK _cap0 ys  ; Δ{ys} · moves{ys} · makes List$tuple2$String$J
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$tuple2$String$Int
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$tuple2$String$Int
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$tuple2$String$Int
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$tuple2$String$Int
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$tuple2$String$Int
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$tuple2$String$Int
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$tuple2$String$J
        ret con Nil  ; Δ{} · makes List$tuple2$String$Int
      drop m : tuple2$String$J skip{1}
      drop t
      drop t : tuple2$String$Int
      drop t : tuple2$String$Int skip{0}
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
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      else
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
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple2$String$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple2$String$J _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_tuple2$String$Int _dd2  ; Δ{}
      let _dd3 = call axion_drop_tuple2$String$J _dd2  ; Δ{}
      let _t0 = call big y  ; Δ{y ys}
      let _t0 = call big y  ; Δ{y ys}
      let _t0 = call big y  ; Δ{}
      let _t0 = call bigH y  ; Δ{y ys}
      let _t0 = call hoflam10 y  ; Δ{y ys}
      let _t0 = call hoflam12 y  ; Δ{y ys}
      let _t0 = call hoflam15 z y  ; Δ{y ys} · moves{y}
      let _t0 = call hoflamcap0 _cap0 y  ; Δ{y ys}
      let _t0 = call isK _cap0 y  ; Δ{y ys}
      let _t0 = call length ys  ; Δ{}
      let _t0 = rtcall axion_str_cmp a k  ; Δ{}
      let _t0 = rtcall axion_str_cmp a k  ; Δ{}
      let _t0 = rtcall axion_str_len a  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret + _t0 b  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret == _t0 0  ; Δ{}
      ret == _t0 0  ; Δ{}
      ret > b 1  ; Δ{}
      ret > b 1  ; Δ{}
      ret > b 1  ; Δ{}
      ret > b 2  ; Δ{}
      ret a  ; Δ{t}
      ret b  ; Δ{}
      ret b  ; Δ{}
      ret call foldl$$hoflam15 _t0 ys  ; Δ{ys} · moves{ys}
      ret case p of
      ret case v of
      ret con Nil  ; Δ{} · makes List$tuple2$String$Int
      ret con Nil  ; Δ{} · makes List$tuple2$String$Int
      ret con Nil  ; Δ{} · makes List$tuple2$String$Int
      ret con Nil  ; Δ{} · makes List$tuple2$String$Int
      ret con Nil  ; Δ{} · makes List$tuple2$String$Int
      ret con Nil  ; Δ{} · makes List$tuple2$String$Int
      ret con Nil  ; Δ{} · makes List$tuple2$String$J
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret z  ; Δ{}
    (a, b) ->
    (a, b) ->
    (a, b) ->
    (a, b) ->
    (a, b) ->
    (a, b) ->
    (a, b) ->
    (a, b) ->
    (a, b) ->
    (a, p) ->
    (a, v) ->
    (a, v) ->
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
    drop _t21 : List$tuple2$String$Int
    else
    else
    else
    let _d1000000 = call length _t21  ; Δ{_t21}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t20 = call pairs 70  ; Δ{} · makes List$tuple2$String$Int
    let _t21 = call takeWhile$$big _t20  ; Δ{_t20} · moves{_t20} · makes List$tuple2$String$Int
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
    ret 0  ; Δ{}
    ret _d1000000  ; Δ{}
  ; Δ{m}
  ; Δ{t}
  ; Δ{y ys}
  ; Δ{y ys}
  ; Δ{y ys}
  ; Δ{y ys}
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
  drop _t0 : List$tuple2$String$Int
  drop _t1 : List$tuple2$String$Int
  drop _t12 : List$tuple2$String$Int
  drop _t18 : List$tuple2$String$Int
  drop _t25 : tuple2$String$Int
  drop _t29 : tuple2$String$Int
  drop _t4 : List$tuple2$String$Int
  drop _t42 : String
  drop _t8 : List$tuple2$String$Int
  else
  else
  else
  else
  else
  let _d1000000 = call length _t0  ; Δ{_t0}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_J _dd0  ; Δ{}
  let _dd1 = call axion_drop_tuple2$String$Int _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
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
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call filter$$hoflamcap0 k xs  ; Δ{} · makes List$tuple2$String$Int
  let _t0 = call pairs 10  ; Δ{} · makes List$tuple2$String$Int
  let _t0 = call show$Int n  ; Δ{} · makes String
  let _t0 = call valOf m  ; Δ{}
  let _t1 = call filter$$big _t0  ; Δ{_t0} · moves{_t0} · makes List$tuple2$String$Int
  let _t1 = tuple _t0 1  ; Δ{_t0} · moves{_t0} · makes heap
  let _t10 = + _t6 _t9  ; Δ{}
  let _t10 = con Cons _t4 _t9  ; Δ{_t1 _t4 _t9} · moves{_t4 _t9} · makes List$tuple2$String$Int
  let _t11 = call pairs 40  ; Δ{} · makes List$tuple2$String$Int
  let _t12 = call filter$$hoflam12 _t11  ; Δ{_t11} · moves{_t11} · makes List$tuple2$String$Int
  let _t13 = call length _t12  ; Δ{_t12}
  let _t14 = + _t10 _t13  ; Δ{}
  let _t15 = call pairs 50  ; Δ{} · makes List$tuple2$String$Int
  let _t16 = call count "51" _t15  ; Δ{_t15} · moves{_t15}
  let _t17 = + _t14 _t16  ; Δ{}
  let _t18 = call pairs 60  ; Δ{} · makes List$tuple2$String$Int
  let _t19 = call any$$big _t18  ; Δ{_t18}
  let _t2 = + n 1  ; Δ{_t1}
  let _t2 = call length _t1  ; Δ{_t1}
  let _t22 = if _t19 then
  let _t23 = + _t17 _t22  ; Δ{}
  let _t24 = call show$Int 1234  ; Δ{} · makes String
  let _t25 = tuple _t24 5  ; Δ{_t24} · moves{_t24} · makes heap
  let _t26 = call lenK _t25  ; Δ{_t25}
  let _t27 = + _t23 _t26  ; Δ{}
  let _t28 = call show$Int 1234  ; Δ{} · makes String
  let _t29 = tuple _t28 5  ; Δ{_t28} · moves{_t28} · makes heap
  let _t3 = call pairs 20  ; Δ{} · makes List$tuple2$String$Int
  let _t3 = call show$Int _t2  ; Δ{_t1} · makes String
  let _t30 = call lenK _t29  ; Δ{_t29}
  let _t31 = + _t27 _t30  ; Δ{}
  let _t32 = call show$Int 9  ; Δ{} · makes String
  let _t33 = tuple _t32 3  ; Δ{_t32} · moves{_t32} · makes heap
  let _t34 = call sndG$String _t33  ; Δ{_t33} · moves{_t33}
  let _t35 = + _t31 _t34  ; Δ{}
  let _t36 = call show$Int 9  ; Δ{} · makes String
  let _t37 = tuple _t36 3  ; Δ{_t36} · moves{_t36} · makes heap
  let _t38 = call sndG$String _t37  ; Δ{_t37} · moves{_t37}
  let _t39 = + _t35 _t38  ; Δ{}
  let _t4 = call filter$$bigH _t3  ; Δ{_t3} · moves{_t3} · makes List$tuple2$String$Int
  let _t4 = tuple _t3 2  ; Δ{_t1 _t3} · moves{_t3} · makes heap
  let _t40 = call show$Int 123  ; Δ{} · makes String
  let _t41 = tuple _t40 4  ; Δ{_t40} · moves{_t40} · makes heap
  let _t42 = call fstS _t41  ; Δ{_t41} · moves{_t41} · makes String
  let _t43 = rtcall axion_str_len _t42  ; Δ{_t42}
  let _t44 = + _t39 _t43  ; Δ{}
  let _t45 = call show$Int 1  ; Δ{} · makes String
  let _t46 = call show$Int 22  ; Δ{_t45} · makes String
  let _t47 = tuple _t46 3  ; Δ{_t45 _t46} · moves{_t46} · makes heap
  let _t48 = tuple _t45 _t47  ; Δ{_t45 _t47} · moves{_t45 _t47} · makes heap
  let _t49 = call inner _t48  ; Δ{_t48} · moves{_t48}
  let _t5 = + n 2  ; Δ{_t1 _t4}
  let _t5 = call length _t4  ; Δ{_t4}
  let _t50 = + _t44 _t49  ; Δ{}
  let _t51 = con JNum 1  ; Δ{} · makes J
  let _t52 = tuple "a" _t51  ; Δ{_t51} · moves{_t51} · makes heap
  let _t53 = call show$Int 123  ; Δ{_t52} · makes String
  let _t54 = con JStr _t53  ; Δ{_t52 _t53} · moves{_t53} · makes J
  let _t55 = tuple "b" _t54  ; Δ{_t52 _t54} · moves{_t54} · makes heap
  let _t56 = con JNum 5  ; Δ{_t52 _t55} · makes J
  let _t57 = tuple "b" _t56  ; Δ{_t52 _t55 _t56} · moves{_t56} · makes heap
  let _t58 = con Nil  ; Δ{_t52 _t55 _t57} · makes List$tuple2$String$J
  let _t59 = con Cons _t57 _t58  ; Δ{_t52 _t55 _t57 _t58} · moves{_t57 _t58} · makes List$tuple2$String$J
  let _t6 = + _t2 _t5  ; Δ{}
  let _t6 = call show$Int _t5  ; Δ{_t1 _t4} · makes String
  let _t60 = con Cons _t55 _t59  ; Δ{_t52 _t55 _t59} · moves{_t55 _t59} · makes List$tuple2$String$J
  let _t61 = con Cons _t52 _t60  ; Δ{_t52 _t60} · moves{_t52 _t60} · makes List$tuple2$String$J
  let _t62 = call filter$$isK "b" _t61  ; Δ{_t61} · moves{_t61} · makes List$tuple2$String$J
  let _t63 = call foldl$$hoflam15 0 _t62  ; Δ{_t62} · moves{_t62}
  let _t7 = call pairs 30  ; Δ{} · makes List$tuple2$String$Int
  let _t7 = tuple _t6 3  ; Δ{_t1 _t4 _t6} · moves{_t6} · makes heap
  let _t8 = call filter$$hoflam10 _t7  ; Δ{_t7} · moves{_t7} · makes List$tuple2$String$Int
  let _t8 = con Nil  ; Δ{_t1 _t4 _t7} · makes List$tuple2$String$Int
  let _t9 = call length _t8  ; Δ{_t8}
  let _t9 = con Cons _t7 _t8  ; Δ{_t1 _t4 _t7 _t8} · moves{_t7 _t8} · makes List$tuple2$String$Int
  let _tag = loadraw _p+0  ; Δ{}
  ret + _t50 _t63  ; Δ{}
  ret + acc _t0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case _p0 of
  ret case _p0 of
  ret case m of
  ret case m of
  ret case t of
  ret case t of
  ret case t of
  ret case t of
  ret case t of
  ret case t of
  ret case t of
  ret case t of
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
  ret con Cons _t1 _t10  ; Δ{_t1 _t10} · moves{_t1 _t10} · makes List$tuple2$String$Int
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
any$$big xs  =
axion_drop_Array _p  =
axion_drop_J _p  =
axion_drop_List _p  =
axion_drop_List$tuple2$String$Int _p  =
axion_drop_List$tuple2$String$J _p  =
axion_drop_tuple2$String$Int _p  =
axion_drop_tuple2$String$J _p  =
axion_drop_tuple2$String$J_skip_1 _p  =
axion_drop_tuple2$String$tuple2$String$Int _p  =
big t  =
bigH _p0  =
count k xs  =
filter$$big xs  =
filter$$bigH xs  =
filter$$hoflam10 xs  =
filter$$hoflam12 xs  =
filter$$hoflamcap0 _cap0 xs  =
filter$$isK _cap0 xs  =
foldl$$hoflam15 z xs  =
fstS t  =
hoflam10 t  =
hoflam12 _p0  =
hoflam15 acc m  =
hoflamcap0 k t  =
inner t  =
isK k m  =
lenK t  =
length xs  =
main  =
pairs n  =
show$Int x  =
sndG t  =
sndG$String t  =
takeWhile$$big xs  =
valOf m  =
