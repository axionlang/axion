


















        let _t1 = - n 1  ; Δ{}
        let _t1 = - n 1  ; Δ{}
        let _t1 = call filter$$evenN ys  ; Δ{y ys} · moves{ys} · makes List$Int
        let _t2 = call take _t1 ys  ; Δ{} · makes List
        ret 1  ; Δ{}
        ret call drop _t1 ys  ; Δ{} · makes List
        ret call elem x ys  ; Δ{}
        ret call filter$$evenN ys  ; Δ{y ys} · moves{ys} · makes List$Int
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$Int
        ret con Cons y _t2  ; Δ{_t2} · moves{_t2}
        ret con Cons y ys  ; Δ{}
        ret con Nil  ; Δ{}
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs : List$Int
      else
      else
      else
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = < n 1  ; Δ{}
      let _t0 = == x y  ; Δ{}
      let _t0 = call append$Int zs ys  ; Δ{z zs} · moves{zs} · makes List$Int
      let _t0 = call evenN y  ; Δ{y ys}
      let _t0 = call foldr$$hoflam11 z ys  ; Δ{y ys} · moves{ys}
      let _t0 = call hoflam14 z y  ; Δ{y ys}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call reverse$Int ys  ; Δ{y ys} · moves{ys} · makes List$Int
      let _t0 = call sum ys  ; Δ{}
      let _t1 = con Nil  ; Δ{_t0 y}
      let _t2 = con Cons y _t1  ; Δ{_t0 y} · moves{y}
      ret + 1 _t0  ; Δ{}
      ret + y _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret call append$Int _t0 _t2  ; Δ{_t0} · moves{_t0} · makes List$Int
      ret call foldl$$hoflam14 _t0 ys  ; Δ{y ys} · moves{ys}
      ret call hoflam11 y _t0  ; Δ{y}
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{} · makes List$Int
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret ys  ; Δ{}
      ret z  ; Δ{}
      ret z  ; Δ{}
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
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
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
  drop _t12 : List$Int
  drop _t19 : List$Int
  drop _t37 : List$Int
  drop _t38 : List$Int
  drop _t4 : List$Int
  drop _t45 : List$Int
  drop _t55 : List$Int
  drop _t65 : List$Int
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = con Nil  ; Δ{} · makes List$Int
  let _t0 = mod n 2  ; Δ{}
  let _t1 = con Cons 4 _t0  ; Δ{_t0} · moves{_t0} · makes List$Int
  let _t10 = con Cons 4 _t9  ; Δ{_t8 _t9} · moves{_t9} · makes List$Int
  let _t11 = con Cons 3 _t10  ; Δ{_t10 _t8} · moves{_t10} · makes List$Int
  let _t12 = call append$Int _t8 _t11  ; Δ{_t11 _t8} · moves{_t11 _t8} · makes List$Int
  let _t13 = call sum _t12  ; Δ{_t12}
  let _t14 = + _t5 _t13  ; Δ{}
  let _t15 = con Nil  ; Δ{} · makes List$Int
  let _t16 = con Cons 30 _t15  ; Δ{_t15} · moves{_t15} · makes List$Int
  let _t17 = con Cons 20 _t16  ; Δ{_t16} · moves{_t16} · makes List$Int
  let _t18 = con Cons 10 _t17  ; Δ{_t17} · moves{_t17} · makes List$Int
  let _t19 = call reverse$Int _t18  ; Δ{_t18} · moves{_t18} · makes List$Int
  let _t2 = con Cons 3 _t1  ; Δ{_t1} · moves{_t1} · makes List$Int
  let _t20 = call sum _t19  ; Δ{_t19}
  let _t21 = + _t14 _t20  ; Δ{}
  let _t22 = con Nil  ; Δ{} · makes List$Int
  let _t23 = con Cons 3 _t22  ; Δ{_t22} · moves{_t22} · makes List$Int
  let _t24 = con Cons 2 _t23  ; Δ{_t23} · moves{_t23} · makes List$Int
  let _t25 = con Cons 1 _t24  ; Δ{_t24} · moves{_t24} · makes List$Int
  let _t26 = call foldr$$hoflam11 0 _t25  ; Δ{_t25} · moves{_t25}
  let _t27 = + _t21 _t26  ; Δ{}
  let _t28 = con Nil  ; Δ{} · makes List$Int
  let _t29 = con Cons 6 _t28  ; Δ{_t28} · moves{_t28} · makes List$Int
  let _t3 = con Cons 2 _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
  let _t30 = con Cons 5 _t29  ; Δ{_t29} · moves{_t29} · makes List$Int
  let _t31 = con Cons 4 _t30  ; Δ{_t30} · moves{_t30} · makes List$Int
  let _t32 = call foldl$$hoflam14 0 _t31  ; Δ{_t31} · moves{_t31}
  let _t33 = + _t27 _t32  ; Δ{}
  let _t34 = con Nil  ; Δ{} · makes List$Int
  let _t35 = con Cons 300 _t34  ; Δ{_t34} · moves{_t34} · makes List$Int
  let _t36 = con Cons 200 _t35  ; Δ{_t35} · moves{_t35} · makes List$Int
  let _t37 = con Cons 100 _t36  ; Δ{_t36} · moves{_t36} · makes List$Int
  let _t38 = call take 2 _t37  ; Δ{_t37} · makes List$Int
  let _t39 = call sum _t38  ; Δ{_t38}
  let _t4 = con Cons 1 _t3  ; Δ{_t3} · moves{_t3} · makes List$Int
  let _t40 = + _t33 _t39  ; Δ{}
  let _t41 = con Nil  ; Δ{} · makes List$Int
  let _t42 = con Cons 3 _t41  ; Δ{_t41} · moves{_t41} · makes List$Int
  let _t43 = con Cons 2 _t42  ; Δ{_t42} · moves{_t42} · makes List$Int
  let _t44 = con Cons 1 _t43  ; Δ{_t43} · moves{_t43} · makes List$Int
  let _t45 = call drop 1 _t44  ; Δ{_t44} · moves{_t44} · makes List$Int
  let _t46 = call sum _t45  ; Δ{_t45}
  let _t47 = + _t40 _t46  ; Δ{}
  let _t48 = con Nil  ; Δ{} · makes List$Int
  let _t49 = con Cons 6 _t48  ; Δ{_t48} · moves{_t48} · makes List$Int
  let _t5 = call length _t4  ; Δ{_t4}
  let _t50 = con Cons 5 _t49  ; Δ{_t49} · moves{_t49} · makes List$Int
  let _t51 = con Cons 4 _t50  ; Δ{_t50} · moves{_t50} · makes List$Int
  let _t52 = con Cons 3 _t51  ; Δ{_t51} · moves{_t51} · makes List$Int
  let _t53 = con Cons 2 _t52  ; Δ{_t52} · moves{_t52} · makes List$Int
  let _t54 = con Cons 1 _t53  ; Δ{_t53} · moves{_t53} · makes List$Int
  let _t55 = call filter$$evenN _t54  ; Δ{_t54} · moves{_t54} · makes List$Int
  let _t56 = call sum _t55  ; Δ{_t55}
  let _t57 = + _t47 _t56  ; Δ{}
  let _t58 = con Nil  ; Δ{}
  let _t59 = call null _t58  ; Δ{}
  let _t6 = con Nil  ; Δ{} · makes List$Int
  let _t60 = call b2i _t59  ; Δ{}
  let _t61 = + _t57 _t60  ; Δ{}
  let _t62 = con Nil  ; Δ{} · makes List$Int
  let _t63 = con Cons 3 _t62  ; Δ{_t62} · moves{_t62} · makes List$Int
  let _t64 = con Cons 2 _t63  ; Δ{_t63} · moves{_t63} · makes List$Int
  let _t65 = con Cons 1 _t64  ; Δ{_t64} · moves{_t64} · makes List$Int
  let _t66 = call elem 3 _t65  ; Δ{_t65}
  let _t67 = call b2i _t66  ; Δ{}
  let _t7 = con Cons 2 _t6  ; Δ{_t6} · moves{_t6} · makes List$Int
  let _t8 = con Cons 1 _t7  ; Δ{_t7} · moves{_t7} · makes List$Int
  let _t9 = con Nil  ; Δ{_t8} · makes List$Int
  ret + _t61 _t67  ; Δ{}
  ret + a x  ; Δ{}
  ret + x a  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret == _t0 0  ; Δ{}
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
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
append$Int xs ys  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
b2i b  =
drop n xs  =
elem x xs  =
evenN n  =
filter$$evenN xs  =
foldl$$hoflam14 z xs  =
foldr$$hoflam11 z xs  =
hoflam11 x a  =
hoflam14 a x  =
length xs  =
main  =
null xs  =
reverse$Int xs  =
sum xs  =
take n xs  =
