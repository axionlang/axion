









              drop _t6 : String
              let _d1000000 = putStrLn _t6  ; Δ{_t6}
              let _t6 = call withIndex "/d.css"  ; Δ{} · makes String
              ret _d1000000  ; Δ{}
            _ ->
            drop p : String
            drop p : String
            let _d1000000 = rtcall axion_strcat p "index.html"  ; Δ{p} · makes String
            let _d1000001 = rtcall axion_strcat p ""  ; Δ{p} · makes String
            ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
            ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
          drop _t2 : String
          drop _t4 : String
          drop m : String
          drop r
          else
          let _rcl2000000 = rtcall axion_strcat "root" _t2  ; Δ{} · makes String
          let _t1 = call hasSuffix "/" p  ; Δ{p}
          let _t2 = if _t1 then
          let _t4 = call withIndex "/c/"  ; Δ{} · makes String
          let _t5 = putStrLn _t4  ; Δ{_t4}
          ret _rcl2000000  ; Δ{_rcl2000000} · moves{_rcl2000000}
          ret case _t5 of
        Req m p ->
        _ ->
      drop _t0
      drop _t0
      drop _t2 : String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t2 = call reqFile "/b.txt"  ; Δ{} · makes String
      let _t3 = putStrLn _t2  ; Δ{_t2}
      ret ""  ; Δ{code}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t3 of
      ret case r of
    Left code ->
    Right r ->
    _ ->
    drop _t7 : String
    drop p : String
    drop p : String
    drop raw : String
    else
    let _d1000000 = rtcall axion_strcat p "index.html"  ; Δ{p} · makes String
    let _d1000001 = rtcall axion_strcat p ""  ; Δ{p} · makes String
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = call axion_drop_Req _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t2 = con Req "GET" raw  ; Δ{} · makes Req
    let _t3 = rtcall axion_str_len s  ; Δ{}
    let _t4 = rtcall axion_str_len q  ; Δ{}
    let _t5 = - _t3 _t4  ; Δ{}
    let _t6 = rtcall axion_str_len q  ; Δ{}
    let _t7 = rtcall axion_substr _t5 _t6 s  ; Δ{} · makes String
    let _t8 = rtcall axion_str_cmp _t7 q  ; Δ{_t7}
    let _tag = loadraw _p+0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret == _t8 0  ; Δ{}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
    ret con Left 400  ; Δ{} · makes Either$Int$Req
    ret con Right _t2  ; Δ{_t2} · moves{_t2} · makes Either$Int$Req
  ; Δ{_t0}
  ; Δ{p}
  ; Δ{p}
  ; Δ{r}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  drop _t0 : String
  drop _t1 : String
  else
  else
  else
  else
  else
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _rcl2000001 = rtcall axion_strcat "root" _t1  ; Δ{} · makes String
  let _t0 = call hasSuffix "/" p  ; Δ{p}
  let _t0 = call parse raw  ; Δ{} · makes Either$Int$Req
  let _t0 = call reqFile "/a/"  ; Δ{} · makes String
  let _t0 = rtcall axion_str_len q  ; Δ{}
  let _t0 = rtcall axion_str_len raw  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = if _t0 then
  let _t1 = putStrLn _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let p = rtcall axion_strcat raw ""  ; Δ{} · makes String
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _rcl2000001  ; Δ{_rcl2000001} · moves{_rcl2000001}
  ret case _t0 of
  ret case _t1 of
  ret if _t1 then
  ret if _t2 then
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_Either$Int _p  =
axion_drop_Either$Int$Req _p  =
axion_drop_List _p  =
axion_drop_Req _p  =
hasSuffix q s  =
main  =
parse raw  =
reqFile raw  =
withIndex raw  =
