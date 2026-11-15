














              drop _t34 : String
              drop v4 : List$String
              let _d1000000 = putStrLn _t34  ; Δ{_t34}
              let _t27 = showInt 123  ; Δ{} · makes String
              let _t28 = con Nil  ; Δ{_t27} · makes List$String
              let _t29 = con Cons "" _t28  ; Δ{_t27 _t28} · moves{_t28} · makes List$String
              let _t30 = con Cons _t27 _t29  ; Δ{_t27 _t29} · moves{_t27 _t29} · makes List$String
              let _t31 = call sumWith$$hoflam12 v4  ; Δ{v4}
              let _t32 = call length v4  ; Δ{v4}
              let _t33 = + _t31 _t32  ; Δ{}
              let _t34 = showInt _t33  ; Δ{} · makes String
              let v4 = con Cons "ab" _t30  ; Δ{_t30} · moves{_t30} · makes List$String
              ret _d1000000  ; Δ{}
            _ ->
          drop _t25 : String
          drop v3 : List$String
          let _t18 = showInt 123  ; Δ{} · makes String
          let _t19 = con Nil  ; Δ{_t18} · makes List$String
          let _t20 = con Cons "" _t19  ; Δ{_t18 _t19} · moves{_t19} · makes List$String
          let _t21 = con Cons _t18 _t20  ; Δ{_t18 _t20} · moves{_t18 _t20} · makes List$String
          let _t22 = call sumWith$$hoflam10 v3  ; Δ{v3}
          let _t23 = call length v3  ; Δ{v3}
          let _t24 = + _t22 _t23  ; Δ{}
          let _t25 = showInt _t24  ; Δ{} · makes String
          let _t26 = putStrLn _t25  ; Δ{_t25}
          let v3 = con Cons "ab" _t21  ; Δ{_t21} · moves{_t21} · makes List$String
          ret case _t26 of
        _ ->
      drop _t16 : String
      drop v2 : List$String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = call hoflam10 x  ; Δ{}
      let _t0 = call hoflam12 x  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = call myLen x  ; Δ{}
      let _t0 = call strLen$fn x  ; Δ{}
      let _t1 = call sumWith$$hoflam10 rest  ; Δ{}
      let _t1 = call sumWith$$hoflam12 rest  ; Δ{}
      let _t1 = call sumWith$$myLen rest  ; Δ{}
      let _t1 = call sumWith$$strLen$fn rest  ; Δ{}
      let _t10 = con Nil  ; Δ{_t9} · makes List$String
      let _t11 = con Cons "" _t10  ; Δ{_t10 _t9} · moves{_t10} · makes List$String
      let _t12 = con Cons _t9 _t11  ; Δ{_t11 _t9} · moves{_t11 _t9} · makes List$String
      let _t13 = call sumWith$$myLen v2  ; Δ{v2}
      let _t14 = call length v2  ; Δ{v2}
      let _t15 = + _t13 _t14  ; Δ{}
      let _t16 = showInt _t15  ; Δ{} · makes String
      let _t17 = putStrLn _t16  ; Δ{_t16}
      let _t9 = showInt 123  ; Δ{} · makes String
      let v2 = con Cons "ab" _t12  ; Δ{_t12} · moves{_t12} · makes List$String
      ret + 1 _t0  ; Δ{}
      ret + _t0 _t1  ; Δ{}
      ret + _t0 _t1  ; Δ{}
      ret + _t0 _t1  ; Δ{}
      ret + _t0 _t1  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t17 of
    Cons x rest ->
    Cons x rest ->
    Cons x rest ->
    Cons x rest ->
    Cons y ys ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    _ ->
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
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
  drop _t0 : String
  drop _t0 : String
  drop _t7 : String
  drop v1 : List$String
  else
  else
  let $aliascopy0 = rtcall axion_strcat x ""  ; Δ{} · makes String
  let _d1000000 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _d1000000 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = call idG$String s  ; Δ{} · makes String
  let _t0 = rtcall axion_strcat s "!"  ; Δ{} · makes String
  let _t0 = showInt 123  ; Δ{} · makes String
  let _t1 = con Nil  ; Δ{_t0} · makes List$String
  let _t2 = con Cons "" _t1  ; Δ{_t0 _t1} · moves{_t1} · makes List$String
  let _t3 = con Cons _t0 _t2  ; Δ{_t0 _t2} · moves{_t0 _t2} · makes List$String
  let _t4 = call sumWith$$strLen$fn v1  ; Δ{v1}
  let _t5 = call length v1  ; Δ{v1}
  let _t6 = + _t4 _t5  ; Δ{}
  let _t7 = showInt _t6  ; Δ{} · makes String
  let _t8 = putStrLn _t7  ; Δ{_t7}
  let v1 = con Cons "ab" _t3  ; Δ{_t3} · moves{_t3} · makes List$String
  ret $aliascopy0  ; Δ{$aliascopy0} · moves{$aliascopy0}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret case _t8 of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_str_len s  ; Δ{}
  ret rtcall axion_str_len x0  ; Δ{}
  ret x  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
hoflam10 s  =
hoflam12 s  =
idG x  =
idG$String x  =
length xs  =
main  =
myLen s  =
strLen$fn x0  =
sumWith$$hoflam10 xs  =
sumWith$$hoflam12 xs  =
sumWith$$myLen xs  =
sumWith$$strLen$fn xs  =
