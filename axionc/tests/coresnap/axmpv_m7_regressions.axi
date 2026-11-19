









                  drop _t23 : P
                  drop _t25 : String
                  drop _t26 : P
                  drop _t28 : String
                  drop _t29 : P
                  drop _t31 : String
                  drop _t32 : String
                  drop _t33 : String
                  drop _t34 : String
                  drop _t35 : String
                  let _d1000000 = putStrLn _t35  ; Δ{_t35}
                  let _t23 = record P { v = 0 s = "abc"}  ; Δ{} · makes P
                  let _t24 = call j _t23 5  ; Δ{_t23}
                  let _t25 = showInt _t24  ; Δ{} · makes String
                  let _t26 = record P { v = 0 s = "abc"}  ; Δ{_t25} · makes P
                  let _t27 = call j _t26 0  ; Δ{_t25 _t26}
                  let _t28 = showInt _t27  ; Δ{_t25} · makes String
                  let _t29 = record P { v = 2 s = "abc"}  ; Δ{_t25 _t28} · makes P
                  let _t30 = call j _t29 0  ; Δ{_t25 _t28 _t29}
                  let _t31 = showInt _t30  ; Δ{_t25 _t28} · makes String
                  let _t32 = rtcall axion_strcat " " _t31  ; Δ{_t25 _t28 _t31} · makes String
                  let _t33 = rtcall axion_strcat _t28 _t32  ; Δ{_t25 _t28 _t32} · makes String
                  let _t34 = rtcall axion_strcat " " _t33  ; Δ{_t25 _t33} · makes String
                  let _t35 = rtcall axion_strcat _t25 _t34  ; Δ{_t25 _t34} · makes String
                  ret _d1000000  ; Δ{}
                _ ->
              let _t22 = call say 0  ; Δ{}
              ret case _t22 of
            _ ->
          let _t21 = call say 3  ; Δ{}
          ret case _t21 of
        _ ->
      drop _t14 : String
      drop _t15 : String
      drop _t16 : String
      drop _t17 : String
      drop _t18 : String
      drop _t19 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t14 = call h 5  ; Δ{} · makes String
      let _t15 = call h 42  ; Δ{_t14} · makes String
      let _t16 = rtcall axion_strcat _t15 "]"  ; Δ{_t14 _t15} · makes String
      let _t17 = rtcall axion_strcat "][" _t16  ; Δ{_t14 _t16} · makes String
      let _t18 = rtcall axion_strcat _t14 _t17  ; Δ{_t14 _t17} · makes String
      let _t19 = rtcall axion_strcat "[" _t18  ; Δ{_t18} · makes String
      let _t20 = putStrLn _t19  ; Δ{_t19}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t20 of
    _ ->
    drop _t1 : String
    drop _t3 : P skip{1}
    drop _t4 : String
    drop name : String
    drop p : P
    drop p : P skip{1}
    else
    let $aliascopy0 = call axion_copy_P p  ; Δ{} · makes P
    let $updfield1 = field s p  ; Δ{}
    let $updfield1 = field s p0  ; Δ{}
    let $updfield1c0 = rtcall axion_strcat $updfield1 ""  ; Δ{} · makes String
    let $updfield1c0 = rtcall axion_strcat $updfield1 ""  ; Δ{} · makes String
    let _d1000000 = call use _t3  ; Δ{_t3}
    let _d1000000 = rtcall axion_strcat "n=" _t1  ; Δ{_t1} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _rcl2000001 = rtcall axion_str_len _t4  ; Δ{}
    let _t1 = showInt k  ; Δ{} · makes String
    let _t3 = update p { v = 9}  ; Δ{} · makes heap
    let _t4 = field s p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret ""  ; Δ{}
    ret $aliascopy0  ; Δ{$aliascopy0} · moves{$aliascopy0}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret _d1000000  ; Δ{_t3}
    ret _rcl2000001  ; Δ{}
    ret call axion_copy_P p0  ; Δ{} · makes P
    ret call axion_copy_P p1  ; Δ{} · makes P
    ret call bump p1  ; Δ{} · makes P
    ret name  ; Δ{name} · moves{name}
    ret rtcall axion_strcat "none" ""  ; Δ{} · makes String
    ret update p { v = 0 s = $updfield1c0}  ; Δ{$updfield1c0} · moves{$updfield1c0} · makes heap
    ret update p0 { v = k s = $updfield1c0}  ; Δ{$updfield1c0} · moves{$updfield1c0} · makes heap
  ; Δ{name}
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
  drop _t0 : P
  drop _t0 : String
  drop _t10 : String
  drop _t11 : String
  drop _t12 : String
  drop _t2 : String
  drop _t2 : String
  drop _t3 : P
  drop _t5 : String
  drop _t6 : P
  drop _t8 : String
  drop _t9 : String
  drop p2 : P
  else
  else
  else
  else
  else
  else
  else
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _rcl2000000 = rtcall axion_eputs _t2  ; Δ{}
  let _t0 = > k 0  ; Δ{}
  let _t0 = > k 0  ; Δ{}
  let _t0 = > k 1  ; Δ{}
  let _t0 = field v p  ; Δ{}
  let _t0 = field v q  ; Δ{}
  let _t0 = record P { v = 5 s = "ab"}  ; Δ{} · makes P
  let _t0 = showInt k  ; Δ{} · makes String
  let _t1 = > _t0 2  ; Δ{}
  let _t1 = > n 2  ; Δ{name}
  let _t1 = call g _t0 1  ; Δ{_t0}
  let _t1 = field s q  ; Δ{}
  let _t1 = field v p  ; Δ{}
  let _t1 = field v p2  ; Δ{}
  let _t10 = rtcall axion_strcat _t5 _t9  ; Δ{_t2 _t5 _t9} · makes String
  let _t11 = rtcall axion_strcat " " _t10  ; Δ{_t10 _t2} · makes String
  let _t12 = rtcall axion_strcat _t2 _t11  ; Δ{_t11 _t2} · makes String
  let _t13 = putStrLn _t12  ; Δ{_t12}
  let _t2 = > _t1 0  ; Δ{}
  let _t2 = field v p1  ; Δ{}
  let _t2 = if _t0 then
  let _t2 = rtcall axion_str_len _t1  ; Δ{}
  let _t2 = showInt _t1  ; Δ{} · makes String
  let _t3 = + _t1 _t2  ; Δ{}
  let _t3 = record P { v = 1 s = "ab"}  ; Δ{_t2} · makes P
  let _t4 = call g _t3 1  ; Δ{_t2 _t3}
  let _t4 = field s p1  ; Δ{}
  let _t5 = rtcall axion_str_len _t4  ; Δ{}
  let _t5 = showInt _t4  ; Δ{_t2} · makes String
  let _t6 = record P { v = 5 s = "ab"}  ; Δ{_t2 _t5} · makes P
  let _t7 = call g _t6 0  ; Δ{_t2 _t5 _t6}
  let _t8 = showInt _t7  ; Δ{_t2 _t5} · makes String
  let _t9 = rtcall axion_strcat " " _t8  ; Δ{_t2 _t5 _t8} · makes String
  let n = ffi strlen name  ; Δ{name}
  let name = rtcall axion_strcat "f" _t0  ; Δ{_t0} · makes String
  let p = if _t0 then
  let p2 = if _t0 then
  ret + _t0 _t2  ; Δ{}
  ret + _t3 _t5  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _rcl2000000  ; Δ{}
  ret case _t13 of
  ret if _t1 then
  ret if _t1 then
  ret if _t2 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_P _p  =
bump p  =
g p1 k  =
h k  =
j p0 k  =
main  =
say k  =
use q  =
