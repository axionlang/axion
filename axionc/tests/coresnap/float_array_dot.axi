






      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t1 = + i 1  ; Δ{}
      let _t1 = + i 1  ; Δ{}
      let _t2 = rtcall axion_array_get a i  ; Δ{}
      let _t2 = toFloat _t1  ; Δ{}
      let _t3 = + i 1  ; Δ{a2}
      let _t3 = rtcall axion_array_get a i  ; Δ{}
      let _t4 = *. _t2 _t3  ; Δ{}
      let _t5 = +. acc _t4  ; Δ{}
      let a2 = rtcall axion_array_set a i _t2  ; Δ{} · makes Array
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret a  ; Δ{}
      ret acc  ; Δ{}
      ret call dotF a _t1 _t5  ; Δ{}
      ret call fillF a2 _t3  ; Δ{a2} · moves{a2} · makes Array
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t0 = == i 4  ; Δ{}
    let _t0 = == i 4  ; Δ{}
    let _t1 = + i 1  ; Δ{}
    let _t1 = + i 1  ; Δ{}
    let _t2 = rtcall axion_array_get_nobc a i  ; Δ{}
    let _t2 = toFloat _t1  ; Δ{}
    let _t3 = + i 1  ; Δ{a2}
    let _t3 = rtcall axion_array_get_nobc a i  ; Δ{}
    let _t4 = *. _t2 _t3  ; Δ{}
    let _t5 = +. acc _t4  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let a2 = rtcall axion_array_set_nobc a i _t2  ; Δ{} · makes Array
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret a  ; Δ{}
    ret acc  ; Δ{}
    ret call dotF$bce a _t1 _t5  ; Δ{}
    ret call dotF$bce a i acc  ; Δ{}
    ret call fillF$bce a i  ; Δ{} · makes Array
    ret call fillF$bce a2 _t3  ; Δ{a2} · moves{a2} · makes Array
    ret if _t0 then
    ret if _t0 then
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t2 : String
  drop a : Array
  else
  else
  else
  else
  else
  let $bce1 = > i -1  ; Δ{}
  let $bce1 = > i -1  ; Δ{}
  let $bce10 = band $bce7 $bce9  ; Δ{}
  let $bce10 = band $bce7 $bce9  ; Δ{}
  let $bce11 = > 1 0  ; Δ{}
  let $bce11 = > 1 0  ; Δ{}
  let $bce12 = band $bce10 $bce11  ; Δ{}
  let $bce12 = band $bce10 $bce11  ; Δ{}
  let $bce13 = * 1 $bce11  ; Δ{}
  let $bce13 = * 1 $bce11  ; Δ{}
  let $bce14 = - 1 $bce11  ; Δ{}
  let $bce14 = - 1 $bce11  ; Δ{}
  let $bce15 = + $bce13 $bce14  ; Δ{}
  let $bce15 = + $bce13 $bce14  ; Δ{}
  let $bce16 = - $bce8 1  ; Δ{}
  let $bce16 = - $bce8 1  ; Δ{}
  let $bce17 = div $bce16 $bce15  ; Δ{}
  let $bce17 = div $bce16 $bce15  ; Δ{}
  let $bce18 = + $bce17 2  ; Δ{}
  let $bce18 = + $bce17 2  ; Δ{}
  let $bce19 = > $bce18 4  ; Δ{}
  let $bce19 = > $bce18 4  ; Δ{}
  let $bce2 = + 4 1  ; Δ{}
  let $bce2 = + 4 1  ; Δ{}
  let $bce20 = band $bce12 $bce19  ; Δ{}
  let $bce20 = band $bce12 $bce19  ; Δ{}
  let $bce3 = > $bce2 i  ; Δ{}
  let $bce3 = > $bce2 i  ; Δ{}
  let $bce4 = band $bce1 $bce3  ; Δ{}
  let $bce4 = band $bce1 $bce3  ; Δ{}
  let $bce5 = rtcall axion_array_len a  ; Δ{}
  let $bce5 = rtcall axion_array_len a  ; Δ{}
  let $bce6 = > 0 -1  ; Δ{}
  let $bce6 = > 0 -1  ; Δ{}
  let $bce7 = band $bce4 $bce6  ; Δ{}
  let $bce7 = band $bce4 $bce6  ; Δ{}
  let $bce8 = - $bce5 0  ; Δ{}
  let $bce8 = - $bce5 0  ; Δ{}
  let $bce9 = > $bce8 0  ; Δ{}
  let $bce9 = > $bce8 0  ; Δ{}
  let _d1000000 = putStrLn _t2  ; Δ{_t2}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = == i 4  ; Δ{}
  let _t0 = == i 4  ; Δ{}
  let _t0 = newArray 4 0f  ; Δ{} · makes Array
  let _t1 = call dotF a 0 0f  ; Δ{a}
  let _t2 = rtcall axion_show_float _t1  ; Δ{} · makes String
  let a = call fillF _t0 0  ; Δ{_t0} · moves{_t0} · makes Array
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret if $bce20 then
  ret if $bce20 then
  ret if _t0 then
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
dotF a i acc  =
dotF$bce a i acc  =
fillF a i  =
fillF$bce a i  =
main  =
