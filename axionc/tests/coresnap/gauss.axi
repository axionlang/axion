


























        let _t4 = + i 1  ; Δ{}
        ret best  ; Δ{}
        ret call printSol x n _t4  ; Δ{}
        ret i  ; Δ{}
      _ ->
      drop _t2 : String
      else
      let _d1000000 = putStrLn _t2  ; Δ{_t2}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t1 = call ix n i j  ; Δ{}
      let _t1 = call ix n i j  ; Δ{}
      let _t1 = call ix n i k  ; Δ{}
      let _t1 = call ix n i k  ; Δ{}
      let _t1 = call ix n i n  ; Δ{}
      let _t1 = call ix n r1 j  ; Δ{}
      let _t1 = call resid a x n 0 0f  ; Δ{}
      let _t1 = call rowSum a x n i 0 0f  ; Δ{}
      let _t2 = call ix n i n  ; Δ{}
      let _t2 = call ix n k j  ; Δ{}
      let _t2 = call ix n r2 j  ; Δ{}
      let _t2 = call verdict _t1  ; Δ{} · makes String
      let _t2 = rtcall axion_array_get m _t1  ; Δ{}
      let _t2 = rtcall axion_array_get m _t1  ; Δ{}
      let _t2 = rtcall axion_array_get m _t1  ; Δ{}
      let _t2 = rtcall axion_array_get m _t1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = call ix n best k  ; Δ{}
      let _t3 = call ix n i j  ; Δ{}
      let _t3 = call ix n k k  ; Δ{}
      let _t3 = call ix n r1 j  ; Δ{}
      let _t3 = rtcall axion_array_get a _t2  ; Δ{}
      let _t3 = rtcall axion_array_get x j  ; Δ{}
      let _t4 = *. factor mkj  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + j 1  ; Δ{}
      let _t4 = call ix n r2 j  ; Δ{m1}
      let _t4 = call rowSum m x n i _t3 0f  ; Δ{}
      let _t4 = rtcall axion_array_get m _t3  ; Δ{}
      let _t4 = rtcall axion_array_get m _t3  ; Δ{}
      let _t5 = *. d d  ; Δ{}
      let _t5 = + i 1  ; Δ{m1}
      let _t5 = + j 1  ; Δ{m2}
      let _t5 = +. acc term  ; Δ{}
      let _t5 = -. mij _t4  ; Δ{}
      let _t5 = >. cur bst  ; Δ{}
      let _t5 = call ix n i i  ; Δ{}
      let _t6 = + i 1  ; Δ{}
      let _t6 = + j 1  ; Δ{m1}
      let _t6 = +. acc _t5  ; Δ{}
      let _t6 = rtcall axion_array_get m _t5  ; Δ{}
      let _t7 = - i 1  ; Δ{x2}
      let best2 = if _t5 then
      let bst = call fabs _t4  ; Δ{}
      let cur = call fabs _t2  ; Δ{}
      let d = -. _t1 _t3  ; Δ{}
      let factor = /. _t2 _t4  ; Δ{}
      let m1 = call elimRow m n k i k factor  ; Δ{} · makes Array
      let m1 = rtcall axion_array_set m _t3 _t5  ; Δ{} · makes Array
      let m1 = rtcall axion_array_set m _t3 v2  ; Δ{} · makes Array
      let m2 = rtcall axion_array_set m1 _t4 v1  ; Δ{m1} · moves{m1} · makes Array
      let mij = rtcall axion_array_get m _t1  ; Δ{}
      let mkj = rtcall axion_array_get m _t2  ; Δ{}
      let s = -. _t2 _t4  ; Δ{}
      let term = *. _t2 _t3  ; Δ{}
      let v1 = rtcall axion_array_get m _t1  ; Δ{}
      let v2 = rtcall axion_array_get m _t2  ; Δ{}
      let x2 = rtcall axion_array_set x i xi  ; Δ{} · makes Array
      let xi = /. s _t6  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{}
      ret acc  ; Δ{}
      ret acc  ; Δ{}
      ret best  ; Δ{}
      ret best  ; Δ{}
      ret call argmaxCol m n k _t6 best2  ; Δ{}
      ret call backsub m x2 n _t7  ; Δ{x2} · moves{x2} · makes Array
      ret call elimBelow m1 n k _t5  ; Δ{m1} · moves{m1} · makes Array
      ret call elimRow m1 n k i _t6 factor  ; Δ{m1} · moves{m1} · makes Array
      ret call resid a x n _t4 _t6  ; Δ{}
      ret call rowSum m x n i _t4 _t5  ; Δ{}
      ret call swapRow m2 n r1 r2 _t5  ; Δ{m2} · moves{m2} · makes Array
      ret i  ; Δ{}
      ret m  ; Δ{}
      ret m  ; Δ{}
      ret m  ; Δ{}
      ret x  ; Δ{}
    _ ->
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
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t0 = < i 0  ; Δ{}
    let _t0 = > j n  ; Δ{}
    let _t0 = > j n  ; Δ{}
    let _t0 = call >=$Int i n  ; Δ{}
    let _t0 = call >=$Int i n  ; Δ{}
    let _t0 = call >=$Int i n  ; Δ{}
    let _t0 = call >=$Int j n  ; Δ{}
    let _t1 = + k 1  ; Δ{m1}
    let _t1 = call ix n i j  ; Δ{}
    let _t1 = call ix n i j  ; Δ{}
    let _t1 = call ix n i k  ; Δ{}
    let _t1 = call ix n i k  ; Δ{}
    let _t1 = call ix n i n  ; Δ{}
    let _t1 = call ix n r1 j  ; Δ{}
    let _t1 = call rowSum a x n i 0 0f  ; Δ{}
    let _t1 = rtcall axion_array_get x i  ; Δ{}
    let _t2 = + k 1  ; Δ{m2}
    let _t2 = call ix n i n  ; Δ{}
    let _t2 = call ix n k j  ; Δ{}
    let _t2 = call ix n r2 j  ; Δ{}
    let _t2 = rtcall axion_array_get_nobc m _t1  ; Δ{}
    let _t2 = rtcall axion_array_get_nobc m _t1  ; Δ{}
    let _t2 = rtcall axion_array_get_nobc m _t1  ; Δ{}
    let _t2 = rtcall axion_array_get_nobc m _t1  ; Δ{}
    let _t2 = rtcall axion_show_float _t1  ; Δ{} · makes String
    let _t3 = + i 1  ; Δ{}
    let _t3 = call ix n best k  ; Δ{}
    let _t3 = call ix n i j  ; Δ{}
    let _t3 = call ix n k k  ; Δ{}
    let _t3 = call ix n r1 j  ; Δ{}
    let _t3 = putStrLn _t2  ; Δ{_t2}
    let _t3 = rtcall axion_array_get_nobc a _t2  ; Δ{}
    let _t3 = rtcall axion_array_get_nobc x j  ; Δ{}
    let _t4 = *. factor mkj  ; Δ{}
    let _t4 = + i 1  ; Δ{}
    let _t4 = + j 1  ; Δ{}
    let _t4 = call ix n r2 j  ; Δ{m1}
    let _t4 = call rowSum m x n i _t3 0f  ; Δ{}
    let _t4 = rtcall axion_array_get m _t3  ; Δ{}
    let _t4 = rtcall axion_array_get_nobc m _t3  ; Δ{}
    let _t5 = *. d d  ; Δ{}
    let _t5 = + i 1  ; Δ{m1}
    let _t5 = + j 1  ; Δ{m2}
    let _t5 = +. acc term  ; Δ{}
    let _t5 = -. mij _t4  ; Δ{}
    let _t5 = >. cur bst  ; Δ{}
    let _t5 = call ix n i i  ; Δ{}
    let _t6 = + i 1  ; Δ{}
    let _t6 = + j 1  ; Δ{m1}
    let _t6 = +. acc _t5  ; Δ{}
    let _t6 = rtcall axion_array_get_nobc m _t5  ; Δ{}
    let _t7 = - i 1  ; Δ{x2}
    let _tag = loadraw _p+0  ; Δ{}
    let best2 = if _t5 then
    let bst = call fabs _t4  ; Δ{}
    let cur = call fabs _t2  ; Δ{}
    let d = -. _t1 _t3  ; Δ{}
    let factor = /. _t2 _t4  ; Δ{}
    let m1 = call elimRow m n k i k factor  ; Δ{} · makes Array
    let m1 = call swapRow m n k p 0  ; Δ{} · makes Array
    let m1 = rtcall axion_array_set_nobc m _t3 _t5  ; Δ{} · makes Array
    let m1 = rtcall axion_array_set_nobc m _t3 v2  ; Δ{} · makes Array
    let m2 = call elimBelow m1 n k _t1  ; Δ{m1} · moves{m1} · makes Array
    let m2 = rtcall axion_array_set_nobc m1 _t4 v1  ; Δ{m1} · moves{m1} · makes Array
    let mij = rtcall axion_array_get_nobc m _t1  ; Δ{}
    let mkj = rtcall axion_array_get_nobc m _t2  ; Δ{}
    let p = call argmaxCol m n k k k  ; Δ{}
    let s = -. _t2 _t4  ; Δ{}
    let term = *. _t2 _t3  ; Δ{}
    let v1 = rtcall axion_array_get_nobc m _t1  ; Δ{}
    let v2 = rtcall axion_array_get_nobc m _t2  ; Δ{}
    let x2 = rtcall axion_array_set_nobc x i xi  ; Δ{} · makes Array
    let xi = /. s _t6  ; Δ{}
    ret "FAIL"  ; Δ{}
    ret "ok"  ; Δ{}
    ret -. 0f x  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret best  ; Δ{}
    ret call argmaxCol$bce m n k _t6 best2  ; Δ{}
    ret call argmaxCol$bce m n k i best  ; Δ{}
    ret call backsub$bce m x n i  ; Δ{} · makes Array
    ret call backsub$bce m x2 n _t7  ; Δ{x2} · moves{x2} · makes Array
    ret call elimBelow$bce m n k i  ; Δ{} · makes Array
    ret call elimBelow$bce m1 n k _t5  ; Δ{m1} · moves{m1} · makes Array
    ret call elimRow$bce m n k i j factor  ; Δ{} · makes Array
    ret call elimRow$bce m1 n k i _t6 factor  ; Δ{m1} · moves{m1} · makes Array
    ret call forward m2 n _t2  ; Δ{m2} · moves{m2} · makes Array
    ret call resid$bce a x n _t4 _t6  ; Δ{}
    ret call resid$bce a x n i acc  ; Δ{}
    ret call rowSum$bce m x n i _t4 _t5  ; Δ{}
    ret call rowSum$bce m x n i j acc  ; Δ{}
    ret call swapRow$bce m n r1 r2 j  ; Δ{} · makes Array
    ret call swapRow$bce m2 n r1 r2 _t5  ; Δ{m2} · moves{m2} · makes Array
    ret case _t3 of
    ret if _t0 then
    ret if _t0 then
    ret if _t0 then
    ret if _t0 then
    ret if _t0 then
    ret if _t0 then
    ret if _t0 then
    ret m  ; Δ{}
    ret m  ; Δ{}
    ret m  ; Δ{}
    ret m  ; Δ{}
    ret putStr ""  ; Δ{}
    ret x  ; Δ{}
    ret x  ; Δ{}
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
  drop _t3 : Array
  drop m : Array
  drop x : Array
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
  let $bce1 = > i -1  ; Δ{}
  let $bce1 = > i -1  ; Δ{}
  let $bce1 = > i -1  ; Δ{}
  let $bce1 = > j -1  ; Δ{}
  let $bce1 = > j -1  ; Δ{}
  let $bce1 = > j -1  ; Δ{}
  let $bce1 = rtcall axion_array_len m  ; Δ{}
  let $bce10 = + n 1  ; Δ{}
  let $bce10 = band $bce7 $bce9  ; Δ{}
  let $bce10 = band $bce7 $bce9  ; Δ{}
  let $bce10 = band $bce7 $bce9  ; Δ{}
  let $bce10 = band $bce7 $bce9  ; Δ{}
  let $bce10 = band $bce7 $bce9  ; Δ{}
  let $bce10 = band $bce7 $bce9  ; Δ{}
  let $bce11 = * 1 $bce10  ; Δ{}
  let $bce11 = + n 1  ; Δ{}
  let $bce11 = + n 1  ; Δ{}
  let $bce11 = + n 1  ; Δ{}
  let $bce11 = > 1 0  ; Δ{}
  let $bce11 = > 1 0  ; Δ{}
  let $bce11 = > 1 0  ; Δ{}
  let $bce12 = * 1 $bce11  ; Δ{}
  let $bce12 = * 1 $bce11  ; Δ{}
  let $bce12 = * 1 $bce11  ; Δ{}
  let $bce12 = > $bce11 0  ; Δ{}
  let $bce12 = band $bce10 $bce11  ; Δ{}
  let $bce12 = band $bce10 $bce11  ; Δ{}
  let $bce12 = band $bce10 $bce11  ; Δ{}
  let $bce13 = * 1 $bce11  ; Δ{}
  let $bce13 = * 1 $bce11  ; Δ{}
  let $bce13 = * 1 $bce11  ; Δ{}
  let $bce13 = > $bce12 0  ; Δ{}
  let $bce13 = > $bce12 0  ; Δ{}
  let $bce13 = > $bce12 0  ; Δ{}
  let $bce13 = band $bce9 $bce12  ; Δ{}
  let $bce14 = * $bce11 $bce12  ; Δ{}
  let $bce14 = - 1 $bce11  ; Δ{}
  let $bce14 = - 1 $bce11  ; Δ{}
  let $bce14 = - 1 $bce11  ; Δ{}
  let $bce14 = band $bce10 $bce13  ; Δ{}
  let $bce14 = band $bce10 $bce13  ; Δ{}
  let $bce14 = band $bce10 $bce13  ; Δ{}
  let $bce15 = * $bce12 $bce13  ; Δ{}
  let $bce15 = * $bce12 $bce13  ; Δ{}
  let $bce15 = * $bce12 $bce13  ; Δ{}
  let $bce15 = + $bce13 $bce14  ; Δ{}
  let $bce15 = + $bce13 $bce14  ; Δ{}
  let $bce15 = + $bce13 $bce14  ; Δ{}
  let $bce15 = - 1 $bce12  ; Δ{}
  let $bce16 = + $bce14 $bce15  ; Δ{}
  let $bce16 = - $bce8 1  ; Δ{}
  let $bce16 = - $bce8 1  ; Δ{}
  let $bce16 = - $bce8 1  ; Δ{}
  let $bce16 = - 1 $bce13  ; Δ{}
  let $bce16 = - 1 $bce13  ; Δ{}
  let $bce16 = - 1 $bce13  ; Δ{}
  let $bce17 = + $bce15 $bce16  ; Δ{}
  let $bce17 = + $bce15 $bce16  ; Δ{}
  let $bce17 = + $bce15 $bce16  ; Δ{}
  let $bce17 = - $bce7 1  ; Δ{}
  let $bce17 = div $bce16 $bce15  ; Δ{}
  let $bce17 = div $bce16 $bce15  ; Δ{}
  let $bce17 = div $bce16 $bce15  ; Δ{}
  let $bce18 = + $bce17 1  ; Δ{}
  let $bce18 = + $bce17 1  ; Δ{}
  let $bce18 = + $bce17 2  ; Δ{}
  let $bce18 = - $bce8 1  ; Δ{}
  let $bce18 = - $bce8 1  ; Δ{}
  let $bce18 = - $bce8 1  ; Δ{}
  let $bce18 = div $bce17 $bce16  ; Δ{}
  let $bce19 = + $bce18 1  ; Δ{}
  let $bce19 = > $bce18 n  ; Δ{}
  let $bce19 = > $bce18 n  ; Δ{}
  let $bce19 = > $bce18 n  ; Δ{}
  let $bce19 = div $bce18 $bce17  ; Δ{}
  let $bce19 = div $bce18 $bce17  ; Δ{}
  let $bce19 = div $bce18 $bce17  ; Δ{}
  let $bce2 = + n 1  ; Δ{}
  let $bce2 = rtcall axion_array_len a  ; Δ{}
  let $bce2 = rtcall axion_array_len m  ; Δ{}
  let $bce2 = rtcall axion_array_len m  ; Δ{}
  let $bce2 = rtcall axion_array_len m  ; Δ{}
  let $bce2 = rtcall axion_array_len m  ; Δ{}
  let $bce2 = rtcall axion_array_len m  ; Δ{}
  let $bce20 = + $bce19 2  ; Δ{}
  let $bce20 = + $bce19 2  ; Δ{}
  let $bce20 = + $bce19 2  ; Δ{}
  let $bce20 = > $bce19 i  ; Δ{}
  let $bce20 = band $bce12 $bce19  ; Δ{}
  let $bce20 = band $bce12 $bce19  ; Δ{}
  let $bce20 = band $bce12 $bce19  ; Δ{}
  let $bce21 = + n 1  ; Δ{}
  let $bce21 = + n 1  ; Δ{}
  let $bce21 = > $bce20 n  ; Δ{}
  let $bce21 = > $bce20 n  ; Δ{}
  let $bce21 = > $bce20 n  ; Δ{}
  let $bce21 = band $bce13 $bce20  ; Δ{}
  let $bce21 = rtcall axion_array_len x  ; Δ{}
  let $bce22 = * k $bce21  ; Δ{}
  let $bce22 = * r2 $bce21  ; Δ{}
  let $bce22 = + n 1  ; Δ{}
  let $bce22 = > 0 -1  ; Δ{}
  let $bce22 = band $bce14 $bce21  ; Δ{}
  let $bce22 = band $bce14 $bce21  ; Δ{}
  let $bce22 = band $bce14 $bce21  ; Δ{}
  let $bce23 = * 0 $bce22  ; Δ{}
  let $bce23 = + $bce22 0  ; Δ{}
  let $bce23 = + $bce22 0  ; Δ{}
  let $bce23 = + n 1  ; Δ{}
  let $bce23 = band $bce20 $bce22  ; Δ{}
  let $bce24 = * k $bce23  ; Δ{}
  let $bce24 = + $bce23 0  ; Δ{}
  let $bce24 = - $bce21 0  ; Δ{}
  let $bce24 = > $bce23 -1  ; Δ{}
  let $bce24 = > $bce23 -1  ; Δ{}
  let $bce25 = + $bce24 k  ; Δ{}
  let $bce25 = > $bce24 -1  ; Δ{}
  let $bce25 = > $bce24 0  ; Δ{}
  let $bce25 = band $bce20 $bce24  ; Δ{}
  let $bce25 = band $bce20 $bce24  ; Δ{}
  let $bce26 = - $bce2 $bce23  ; Δ{}
  let $bce26 = - $bce2 $bce23  ; Δ{}
  let $bce26 = > $bce25 -1  ; Δ{}
  let $bce26 = band $bce21 $bce25  ; Δ{}
  let $bce26 = band $bce23 $bce25  ; Δ{}
  let $bce27 = - $bce1 $bce24  ; Δ{}
  let $bce27 = > $bce26 0  ; Δ{}
  let $bce27 = > $bce26 0  ; Δ{}
  let $bce27 = > 1 0  ; Δ{}
  let $bce27 = band $bce22 $bce26  ; Δ{}
  let $bce28 = - $bce2 $bce25  ; Δ{}
  let $bce28 = > $bce27 0  ; Δ{}
  let $bce28 = band $bce25 $bce27  ; Δ{}
  let $bce28 = band $bce25 $bce27  ; Δ{}
  let $bce28 = band $bce26 $bce27  ; Δ{}
  let $bce29 = * 1 $bce27  ; Δ{}
  let $bce29 = > $bce28 0  ; Δ{}
  let $bce29 = > 1 0  ; Δ{}
  let $bce29 = > 1 0  ; Δ{}
  let $bce29 = band $bce26 $bce28  ; Δ{}
  let $bce3 = * 0 $bce2  ; Δ{}
  let $bce3 = + n 1  ; Δ{}
  let $bce3 = + n 1  ; Δ{}
  let $bce3 = + n 1  ; Δ{}
  let $bce3 = + n 1  ; Δ{}
  let $bce3 = + n 1  ; Δ{}
  let $bce3 = + n 1  ; Δ{}
  let $bce30 = + n 1  ; Δ{}
  let $bce30 = - 1 $bce27  ; Δ{}
  let $bce30 = band $bce27 $bce29  ; Δ{}
  let $bce30 = band $bce28 $bce29  ; Δ{}
  let $bce30 = band $bce28 $bce29  ; Δ{}
  let $bce31 = * 1 $bce29  ; Δ{}
  let $bce31 = * 1 $bce29  ; Δ{}
  let $bce31 = * 1 $bce30  ; Δ{}
  let $bce31 = + $bce29 $bce30  ; Δ{}
  let $bce32 = + $bce31 1  ; Δ{}
  let $bce32 = - $bce24 1  ; Δ{}
  let $bce32 = - 1 $bce29  ; Δ{}
  let $bce32 = - 1 $bce29  ; Δ{}
  let $bce33 = + $bce31 $bce32  ; Δ{}
  let $bce33 = + $bce31 $bce32  ; Δ{}
  let $bce33 = > $bce32 0  ; Δ{}
  let $bce33 = div $bce32 $bce31  ; Δ{}
  let $bce34 = + $bce33 2  ; Δ{}
  let $bce34 = - $bce26 1  ; Δ{}
  let $bce34 = - $bce26 1  ; Δ{}
  let $bce34 = band $bce29 $bce33  ; Δ{}
  let $bce35 = * $bce32 $bce33  ; Δ{}
  let $bce35 = > $bce34 n  ; Δ{}
  let $bce35 = div $bce34 $bce33  ; Δ{}
  let $bce35 = div $bce34 $bce33  ; Δ{}
  let $bce36 = + $bce35 1  ; Δ{}
  let $bce36 = + $bce35 1  ; Δ{}
  let $bce36 = - 1 $bce33  ; Δ{}
  let $bce36 = band $bce28 $bce35  ; Δ{}
  let $bce37 = + $bce35 $bce36  ; Δ{}
  let $bce37 = > $bce36 n  ; Δ{}
  let $bce37 = > $bce36 n  ; Δ{}
  let $bce38 = - $bce27 1  ; Δ{}
  let $bce38 = band $bce30 $bce37  ; Δ{}
  let $bce38 = band $bce30 $bce37  ; Δ{}
  let $bce39 = div $bce38 $bce37  ; Δ{}
  let $bce4 = * 0 $bce3  ; Δ{}
  let $bce4 = * 0 $bce3  ; Δ{}
  let $bce4 = * 0 $bce3  ; Δ{}
  let $bce4 = * i $bce3  ; Δ{}
  let $bce4 = * i $bce3  ; Δ{}
  let $bce4 = * r1 $bce3  ; Δ{}
  let $bce4 = + $bce3 n  ; Δ{}
  let $bce40 = + $bce39 1  ; Δ{}
  let $bce41 = > $bce40 i  ; Δ{}
  let $bce42 = band $bce34 $bce41  ; Δ{}
  let $bce43 = rtcall axion_array_len x  ; Δ{}
  let $bce44 = > 0 -1  ; Δ{}
  let $bce45 = band $bce42 $bce44  ; Δ{}
  let $bce46 = - $bce43 0  ; Δ{}
  let $bce47 = > $bce46 0  ; Δ{}
  let $bce48 = band $bce45 $bce47  ; Δ{}
  let $bce49 = > 1 0  ; Δ{}
  let $bce5 = + $bce4 0  ; Δ{}
  let $bce5 = + $bce4 0  ; Δ{}
  let $bce5 = + $bce4 0  ; Δ{}
  let $bce5 = + $bce4 k  ; Δ{}
  let $bce5 = + $bce4 k  ; Δ{}
  let $bce5 = + $bce4 n  ; Δ{}
  let $bce5 = > $bce4 -1  ; Δ{}
  let $bce50 = band $bce48 $bce49  ; Δ{}
  let $bce51 = * 1 $bce49  ; Δ{}
  let $bce52 = - 1 $bce49  ; Δ{}
  let $bce53 = + $bce51 $bce52  ; Δ{}
  let $bce54 = - $bce46 1  ; Δ{}
  let $bce55 = div $bce54 $bce53  ; Δ{}
  let $bce56 = + $bce55 1  ; Δ{}
  let $bce57 = > $bce56 i  ; Δ{}
  let $bce58 = band $bce50 $bce57  ; Δ{}
  let $bce6 = > $bce5 -1  ; Δ{}
  let $bce6 = > $bce5 -1  ; Δ{}
  let $bce6 = > $bce5 -1  ; Δ{}
  let $bce6 = > $bce5 -1  ; Δ{}
  let $bce6 = > $bce5 -1  ; Δ{}
  let $bce6 = > $bce5 -1  ; Δ{}
  let $bce6 = band 1 $bce5  ; Δ{}
  let $bce7 = - $bce1 $bce4  ; Δ{}
  let $bce7 = band $bce1 $bce6  ; Δ{}
  let $bce7 = band $bce1 $bce6  ; Δ{}
  let $bce7 = band $bce1 $bce6  ; Δ{}
  let $bce7 = band $bce1 $bce6  ; Δ{}
  let $bce7 = band $bce1 $bce6  ; Δ{}
  let $bce7 = band $bce1 $bce6  ; Δ{}
  let $bce8 = - $bce2 $bce5  ; Δ{}
  let $bce8 = - $bce2 $bce5  ; Δ{}
  let $bce8 = - $bce2 $bce5  ; Δ{}
  let $bce8 = - $bce2 $bce5  ; Δ{}
  let $bce8 = - $bce2 $bce5  ; Δ{}
  let $bce8 = - $bce2 $bce5  ; Δ{}
  let $bce8 = > $bce7 0  ; Δ{}
  let $bce9 = > $bce8 0  ; Δ{}
  let $bce9 = > $bce8 0  ; Δ{}
  let $bce9 = > $bce8 0  ; Δ{}
  let $bce9 = > $bce8 0  ; Δ{}
  let $bce9 = > $bce8 0  ; Δ{}
  let $bce9 = > $bce8 0  ; Δ{}
  let $bce9 = band $bce6 $bce8  ; Δ{}
  let _d1000000 = call report _t3 x n  ; Δ{_t3 x}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = + n 1  ; Δ{}
  let _t0 = + n 1  ; Δ{}
  let _t0 = < i 0  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = <. r 0.000001f  ; Δ{}
  let _t0 = <. x 0f  ; Δ{}
  let _t0 = > j n  ; Δ{}
  let _t0 = > j n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call >=$Int j n  ; Δ{}
  let _t0 = call >=$Int k n  ; Δ{}
  let _t0 = call build n  ; Δ{} · makes Array
  let _t0 = call ix n i j  ; Δ{}
  let _t0 = call printSol x n 0  ; Δ{}
  let _t1 = * i _t0  ; Δ{}
  let _t1 = * n _t0  ; Δ{}
  let _t1 = newArray n 0f  ; Δ{m} · makes Array
  let _t2 = - n 1  ; Δ{_t1 m}
  let _t3 = call build n  ; Δ{x} · makes Array
  let m = call forward _t0 n 0  ; Δ{_t0} · moves{_t0} · makes Array
  let m = newArray _t1 0f  ; Δ{} · makes Array
  let m$1 = call put m n 0 0 2f  ; Δ{m} · moves{m} · makes Array
  let m$10 = call put m$9 n 2 1 1f  ; Δ{m$9} · moves{m$9} · makes Array
  let m$11 = call put m$10 n 2 2 2f  ; Δ{m$10} · moves{m$10} · makes Array
  let m$2 = call put m$1 n 0 1 1f  ; Δ{m$1} · moves{m$1} · makes Array
  let m$3 = call put m$2 n 0 2 -1f  ; Δ{m$2} · moves{m$2} · makes Array
  let m$4 = call put m$3 n 0 3 8f  ; Δ{m$3} · moves{m$3} · makes Array
  let m$5 = call put m$4 n 1 0 -3f  ; Δ{m$4} · moves{m$4} · makes Array
  let m$6 = call put m$5 n 1 1 -1f  ; Δ{m$5} · moves{m$5} · makes Array
  let m$7 = call put m$6 n 1 2 2f  ; Δ{m$6} · moves{m$6} · makes Array
  let m$8 = call put m$7 n 1 3 -11f  ; Δ{m$7} · moves{m$7} · makes Array
  let m$9 = call put m$8 n 2 0 -2f  ; Δ{m$8} · moves{m$8} · makes Array
  let n = 3  ; Δ{}
  let x = call backsub m _t1 n _t2  ; Δ{_t1 m} · moves{_t1} · makes Array
  ret + _t1 j  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call put m$11 n 2 3 -3f  ; Δ{m$11} · moves{m$11} · makes Array
  ret case _t0 of
  ret if $bce22 then
  ret if $bce22 then
  ret if $bce30 then
  ret if $bce36 then
  ret if $bce38 then
  ret if $bce38 then
  ret if $bce58 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_array_set m _t0 v  ; Δ{} · makes Array
>=$Int x y  =
argmaxCol m n k i best  =
argmaxCol$bce m n k i best  =
axion_drop_Array _p  =
axion_drop_List _p  =
backsub m x n i  =
backsub$bce m x n i  =
build n  =
elimBelow m n k i  =
elimBelow$bce m n k i  =
elimRow m n k i j factor  =
elimRow$bce m n k i j factor  =
fabs x  =
forward m n k  =
ix n i j  =
le$Int x y  =
main  =
printSol x n i  =
put m n i j v  =
report a x n  =
resid a x n i acc  =
resid$bce a x n i acc  =
rowSum m x n i j acc  =
rowSum$bce m x n i j acc  =
swapRow m n r1 r2 j  =
swapRow$bce m n r1 r2 j  =
verdict r  =
