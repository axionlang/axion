




































                                drop acc : List$Member
                                drop key : String
                                let _t18 = con Member key val  ; Δ{kp vp} · makes Member
                                let _t19 = con Cons _t18 acc  ; Δ{_t18 kp vp} · moves{_t18} · makes List$Member
                                let _t20 = call reverse$Member _t19  ; Δ{_t19 kp vp} · moves{_t19} · makes List$Member
                                let _t21 = con JObj _t20  ; Δ{_t20 kp vp} · moves{_t20} · makes Json
                                let _t22 = + m 1  ; Δ{_t21 kp vp}
                                let _t23 = tuple _t21 _t22  ; Δ{_t21 kp vp} · moves{_t21} · makes heap
                                ret con Left "expected , or } in object"  ; Δ{kp vp} · makes Either$String$tuple2$Json$Int
                                ret con Right _t23  ; Δ{_t23 kp vp} · moves{_t23} · makes Either$String$tuple2$Json$Int
                              else
                              let _t14 = + m 1  ; Δ{kp vp}
                              let _t15 = con Member key val  ; Δ{kp vp} · makes Member
                              let _t16 = con Cons _t15 acc  ; Δ{_t15 kp vp} · moves{_t15} · makes List$Member
                              let _t17 = == c 125  ; Δ{kp vp}
                              ret call parseObj s _t14 _t16  ; Δ{_t16 kp vp} · moves{_t16} · makes Either$String$tuple2$Json$Int
                              ret if _t17 then
                            drop vp : tuple2$Json$Int skip{0}
                            else
                            let _t13 = == c 44  ; Δ{kp vp}
                            let c = rtcall axion_str_at m s  ; Δ{kp vp}
                            let m = call skipWs s k2  ; Δ{kp vp}
                            ret if _t13 then
                          (val, k2) ->
                        drop _t12
                        drop _t12
                        drop acc : List$Member
                        drop key : String
                        ret case vp of
                        ret con Left e  ; Δ{e kp} · moves{e} · makes Either$String$tuple2$Json$Int
                      Left e ->
                      Right vp ->
                    drop acc : List$Member
                    drop key : String
                    let _t11 = + c1 1  ; Δ{kp}
                    let _t12 = call parseVal s _t11  ; Δ{kp} · makes Either$String$tuple2$Json$Int
                    ret case _t12 of
                    ret con Left "expected : in object"  ; Δ{kp} · makes Either$String$tuple2$Json$Int
                  drop _t26 : String
                  drop acc : List$Member
                  drop kv
                  drop kv
                  else
                  let _t10 = == _t9 58  ; Δ{kp}
                  let _t24 = + i 1  ; Δ{}
                  let _t25 = con Nil  ; Δ{} · makes List$Member
                  let _t26 = showInt i  ; Δ{} · makes String
                  let _t27 = rtcall axion_strcat "unexpected char at index " _t26  ; Δ{_t26} · makes String
                  let _t9 = rtcall axion_str_at c1 s  ; Δ{kp}
                  let c1 = call skipWs s k  ; Δ{kp}
                  ret call parseObj s _t24 _t25  ; Δ{_t25} · moves{_t25} · makes Either$String$tuple2$Json$Int
                  ret con Left "object key must be a string"  ; Δ{kp} · makes Either$String$tuple2$Json$Int
                  ret con Left _t27  ; Δ{_t27} · moves{_t27} · makes Either$String$tuple2$Json$Int
                  ret if _t10 then
                JStr key ->
                drop acc : List$Json
                else
                let _t11 = con Cons v acc  ; Δ{pr} · makes List$Json
                let _t12 = call reverse$Json _t11  ; Δ{_t11 pr} · moves{_t11} · makes List$Json
                let _t13 = con JArr _t12  ; Δ{_t12 pr} · moves{_t12} · makes Json
                let _t14 = + m 1  ; Δ{_t13 pr}
                let _t15 = tuple _t13 _t14  ; Δ{_t13 pr} · moves{_t13} · makes heap
                let _t21 = + i 1  ; Δ{}
                let _t22 = con Nil  ; Δ{} · makes List$Json
                let _t23 = == c 123  ; Δ{}
                other ->
                ret call parseArr s _t21 _t22  ; Δ{_t22} · moves{_t22} · makes Either$String$tuple2$Json$Int
                ret con Left "expected , or ] in array"  ; Δ{pr} · makes Either$String$tuple2$Json$Int
                ret con Right _t15  ; Δ{_t15 pr} · moves{_t15} · makes Either$String$tuple2$Json$Int
                ret if _t23 then
              drop _t0 : String
              drop _t1 : String
              drop _t2 : String
              drop kp : tuple2$Json$Int skip{0}
              else
              else
              let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
              let _t0 = call showMember k val  ; Δ{} · makes String
              let _t1 = call showObj rest  ; Δ{_t0} · makes String
              let _t10 = == c 93  ; Δ{pr}
              let _t2 = rtcall axion_strcat "," _t1  ; Δ{_t0 _t1} · makes String
              let _t20 = == c 91  ; Δ{}
              let _t8 = + m 1  ; Δ{pr}
              let _t9 = con Cons v acc  ; Δ{pr} · makes List$Json
              ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
              ret call parseArr s _t8 _t9  ; Δ{_t9 pr} · moves{_t9} · makes Either$String$tuple2$Json$Int
              ret call parseNum s i  ; Δ{} · makes Either$String$tuple2$Json$Int
              ret call showMember k val  ; Δ{} · makes String
              ret case kv of
              ret if _t10 then
              ret if _t20 then
            (kv, k) ->
            Cons q qs ->
            Nil ->
            drop pr : tuple2$Json$Int skip{0}
            else
            else
            let _t19 = call isDigitCh c  ; Δ{}
            let _t7 = == c 44  ; Δ{pr}
            let c = rtcall axion_str_at m s  ; Δ{pr}
            let m = call skipWs s k  ; Δ{pr}
            ret call parseNum s i  ; Δ{} · makes Either$String$tuple2$Json$Int
            ret if _t19 then
            ret if _t7 then
          (v, k) ->
          drop _t0 : String
          drop _t1 : String
          drop _t2 : String
          drop _t8
          drop _t8
          drop acc : List$Member
          drop pr : tuple2$Json$Int skip{0}
          else
          let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
          let _t0 = call showJson y  ; Δ{} · makes String
          let _t1 = call showArr ys  ; Δ{_t0} · makes String
          let _t13 = 0  ; Δ{}
          let _t14 = con JBool _t13  ; Δ{} · makes Json
          let _t15 = + i 5  ; Δ{_t14}
          let _t16 = tuple _t14 _t15  ; Δ{_t14} · moves{_t14} · makes heap
          let _t18 = == c 45  ; Δ{}
          let _t2 = rtcall axion_strcat "," _t1  ; Δ{_t0 _t1} · makes String
          ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
          ret call parseStr s i  ; Δ{} · makes Either$String$tuple2$Json$Int
          ret call showJson y  ; Δ{} · makes String
          ret case kp of
          ret case rest of
          ret con Left "bad literal"  ; Δ{} · makes Either$String$tuple2$Json$Int
          ret con Left e  ; Δ{e} · moves{e} · makes Either$String$tuple2$Json$Int
          ret con Right _t16  ; Δ{_t16} · moves{_t16} · makes Either$String$tuple2$Json$Int
          ret con Right v  ; Δ{pr} · makes Either$String$Json
          ret if _t18 then
        (v, _) ->
        Cons z zs ->
        Left e ->
        Member k val ->
        Nil ->
        Right kp ->
        drop _t6
        drop _t6
        drop acc : List$Json
        else
        else
        let _t10 = tuple _t8 _t9  ; Δ{_t8} · moves{_t8} · makes heap
        let _t12 = call litMatch s i "false" 0  ; Δ{}
        let _t17 = == c 34  ; Δ{}
        let _t7 = 1  ; Δ{}
        let _t8 = con JBool _t7  ; Δ{} · makes Json
        let _t9 = + i 4  ; Δ{_t8}
        ret "false"  ; Δ{}
        ret "true"  ; Δ{}
        ret 1  ; Δ{}
        ret == c 13  ; Δ{}
        ret case pr of
        ret con Left "bad literal"  ; Δ{} · makes Either$String$tuple2$Json$Int
        ret con Left e  ; Δ{e} · moves{e} · makes Either$String$tuple2$Json$Int
        ret con Right _t10  ; Δ{_t10} · moves{_t10} · makes Either$String$tuple2$Json$Int
        ret if _t12 then
        ret if _t17 then
      Left e ->
      Right pr ->
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0 : String
      drop _t1 : String
      drop _t2 : String
      drop _t3 : String
      drop _t4 : String
      drop acc : List$Member
      drop e : String
      drop v : Json
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs : List$Json
      drop xs : List$Member
      else
      else
      else
      else
      let _d1000000 = rtcall axion_strcat "ERROR: " e  ; Δ{e} · makes String
      let _d1000000 = rtcall axion_strcat "\"" _t0  ; Δ{_t0} · makes String
      let _d1000001 = call showJson v  ; Δ{v} · makes String
      let _d1000001 = rtcall axion_strcat "[" _t2  ; Δ{_t2} · makes String
      let _d1000002 = rtcall axion_strcat "{" _t4  ; Δ{_t4} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+8  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Json _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Member _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Member _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_Json _dd2  ; Δ{}
      let _dd3 = call axion_drop_Member _dd2  ; Δ{}
      let _dd4 = loadraw _p+8  ; Δ{}
      let _dd5 = call axion_drop_List$Json _dd4  ; Δ{}
      let _dd8 = loadraw _p+8  ; Δ{}
      let _dd9 = rtcall axion_str_drop _dd8  ; Δ{}
      let _t0 = call append$Json zs ys  ; Δ{z zs} · moves{zs} · makes List$Json
      let _t0 = call append$Member zs ys  ; Δ{z zs} · moves{zs} · makes List$Member
      let _t0 = call reverse$Json ys  ; Δ{y ys} · moves{ys} · makes List$Json
      let _t0 = call reverse$Member ys  ; Δ{y ys} · moves{ys} · makes List$Member
      let _t0 = rtcall axion_strcat s "\""  ; Δ{} · makes String
      let _t1 = call showArr xs  ; Δ{} · makes String
      let _t1 = con Nil  ; Δ{_t0 y}
      let _t1 = con Nil  ; Δ{_t0 y}
      let _t11 = == c 102  ; Δ{}
      let _t2 = == c 10  ; Δ{}
      let _t2 = con Cons y _t1  ; Δ{_t0 y} · moves{y}
      let _t2 = con Cons y _t1  ; Δ{_t0 y} · moves{y}
      let _t2 = con JNull  ; Δ{} · makes Json
      let _t2 = rtcall axion_strcat _t1 "]"  ; Δ{_t1} · makes String
      let _t3 = + i 4  ; Δ{_t2}
      let _t3 = call showObj ms  ; Δ{} · makes String
      let _t4 = rtcall axion_strcat _t3 "}"  ; Δ{_t3} · makes String
      let _t4 = tuple _t2 _t3  ; Δ{_t2} · moves{_t2} · makes heap
      let _t5 = + i 1  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t6 = + li 1  ; Δ{}
      let _t6 = call litMatch s i "true" 0  ; Δ{}
      let _t8 = call parseStr s j  ; Δ{} · makes Either$String$tuple2$Json$Int
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret "null"  ; Δ{}
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
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret _d1000002  ; Δ{_d1000002} · moves{_d1000002}
      ret call append$Json _t0 _t2  ; Δ{_t0} · moves{_t0} · makes List$Json
      ret call append$Member _t0 _t2  ; Δ{_t0} · moves{_t0} · makes List$Member
      ret call litMatch s _t5 lit _t6  ; Δ{}
      ret call strEnd s _t5  ; Δ{}
      ret case _t8 of
      ret case p of
      ret case pr of
      ret case ys of
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Left "bad literal"  ; Δ{} · makes Either$String$tuple2$Json$Int
      ret con Left "expected string key in object"  ; Δ{} · makes Either$String$tuple2$Json$Int
      ret con Left e  ; Δ{e} · moves{e} · makes Either$String$Json
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{}
      ret con Right _t4  ; Δ{_t4} · moves{_t4} · makes Either$String$tuple2$Json$Int
      ret i  ; Δ{}
      ret if _t11 then
      ret if _t2 then
      ret if _t6 then
      ret if b then
      ret rtcall axion_show_float n  ; Δ{} · makes String
      ret ys  ; Δ{}
      ret ys  ; Δ{}
    Cons p rest ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
    Cons z zs ->
    JArr xs ->
    JBool b ->
    JNull ->
    JNum n ->
    JObj ms ->
    JStr s ->
    Left e ->
    Left e ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Right pr ->
    Right v ->
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
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = call axion_drop_Json _dd0  ; Δ{}
    let _dd1 = call axion_drop_tuple2$Json$Int _dd0  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd10 = == _tag 3  ; Δ{}
    let _dd11 = if _dd10 then
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 5  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dd5 = rtcall axion_str_drop _dd4  ; Δ{}
    let _dd5 = rtcall axion_str_drop _dd4  ; Δ{}
    let _dd6 = == _tag 4  ; Δ{}
    let _dd7 = if _dd6 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = == c 9  ; Δ{}
    let _t1 = call litMatch s i "null" 0  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = + i 1  ; Δ{}
    let _t2 = + j 1  ; Δ{}
    let _t2 = call reverse$Json acc  ; Δ{} · makes List$Json
    let _t2 = call reverse$Member acc  ; Δ{} · makes List$Member
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t3 = *. acc 10f  ; Δ{}
    let _t3 = + i 1  ; Δ{}
    let _t3 = + j 1  ; Δ{}
    let _t3 = - 0 1  ; Δ{}
    let _t3 = con JArr _t2  ; Δ{_t2} · moves{_t2} · makes Json
    let _t3 = con JObj _t2  ; Δ{_t2} · moves{_t2} · makes Json
    let _t3 = rtcall axion_str_at i s  ; Δ{}
    let _t3 = rtcall axion_str_at li lit  ; Δ{}
    let _t4 = + j 1  ; Δ{_t3}
    let _t4 = + j 1  ; Δ{_t3}
    let _t4 = - _t3 48  ; Δ{}
    let _t4 = - e i  ; Δ{}
    let _t4 = == _t2 _t3  ; Δ{}
    let _t4 = == _t2 _t3  ; Δ{}
    let _t4 = rtcall axion_str_at i s  ; Δ{}
    let _t5 = - _t4 1  ; Δ{}
    let _t5 = - _t4 48  ; Δ{}
    let _t5 = == c 116  ; Δ{}
    let _t5 = toFloat _t4  ; Δ{}
    let _t5 = tuple _t3 _t4  ; Δ{_t3} · moves{_t3} · makes heap
    let _t5 = tuple _t3 _t4  ; Δ{_t3} · moves{_t3} · makes heap
    let _t6 = *. _t5 place  ; Δ{}
    let _t6 = call parseVal s j  ; Δ{} · makes Either$String$tuple2$Json$Int
    let _t6 = rtcall axion_str_at j s  ; Δ{}
    let _t6 = rtcall axion_substr _t3 _t5 s  ; Δ{} · makes String
    let _t6 = toFloat _t5  ; Δ{}
    let _t7 = +. _t3 _t6  ; Δ{}
    let _t7 = +. acc _t6  ; Δ{}
    let _t7 = == _t6 34  ; Δ{}
    let _t7 = con JStr _t6  ; Δ{_t6} · moves{_t6} · makes Json
    let _t8 = + e 1  ; Δ{_t7}
    let _t8 = /. place 10f  ; Δ{}
    let _t9 = tuple _t7 _t8  ; Δ{_t7} · moves{_t7} · makes heap
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret + i 1  ; Δ{}
    ret -. 0f mag  ; Δ{}
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
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0f  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret == x y  ; Δ{}
    ret acc  ; Δ{}
    ret acc  ; Δ{}
    ret call <=$Int c 57  ; Δ{}
    ret call pfFrac s _t2 0f 0.1f  ; Δ{}
    ret call pfFrac s _t2 _t7 _t8  ; Δ{}
    ret call pfIntEnd s _t2  ; Δ{}
    ret call pfIntEnd s _t3  ; Δ{}
    ret call pfIntGo s _t2 _t7  ; Δ{}
    ret call skipWs s _t2  ; Δ{}
    ret case _t6 of
    ret con Left "unterminated string"  ; Δ{} · makes Either$String$tuple2$Json$Int
    ret con Right _t5  ; Δ{_t5} · moves{_t5} · makes Either$String$tuple2$Json$Int
    ret con Right _t5  ; Δ{_t5} · moves{_t5} · makes Either$String$tuple2$Json$Int
    ret con Right _t9  ; Δ{_t9} · moves{_t9} · makes Either$String$tuple2$Json$Int
    ret i  ; Δ{}
    ret i  ; Δ{}
    ret i  ; Δ{}
    ret i  ; Δ{}
    ret if _t1 then
    ret if _t1 then
    ret if _t4 then
    ret if _t4 then
    ret if _t5 then
    ret if _t7 then
    ret j  ; Δ{}
    ret mag  ; Δ{}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t12 kp}
  ; Δ{_t6}
  ; Δ{_t8}
  ; Δ{kp vp}
  ; Δ{kp vp}
  ; Δ{kp vp}
  ; Δ{kp}
  ; Δ{kp}
  ; Δ{kp}
  ; Δ{pr}
  ; Δ{pr}
  ; Δ{pr}
  ; Δ{pr}
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
  drop _t0 : String
  drop _t0 : String
  drop _t1 : String
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
  let _d1000000 = putStrLn _t0  ; Δ{_t0}
  let _d1000000 = rtcall axion_strcat "\"" _t2  ; Δ{_t2} · makes String
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_Json _dd0  ; Δ{}
  let _dd1 = call axion_drop_Json _dd0  ; Δ{}
  let _dd12 = band _p 1  ; Δ{}
  let _dd13 = if _dd12 then
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = == _tag 0  ; Δ{}
  let _dd6 = == _tag 0  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = + i 1  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == c 110  ; Δ{}
  let _t0 = == c 32  ; Δ{}
  let _t0 = call >=$Int c 48  ; Δ{}
  let _t0 = call parseJson src  ; Δ{} · makes Either$String$Json
  let _t0 = call parseVal s 0  ; Δ{} · makes Either$String$tuple2$Json$Int
  let _t0 = call roundtrip "{\"name\":\"ax\",\"ok\":true,\"xs\":[1,2,null],\"pi\":3.5}"  ; Δ{} · makes String
  let _t0 = call showJson val  ; Δ{} · makes String
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_at j s  ; Δ{}
  let _t0 = rtcall axion_str_at j s  ; Δ{}
  let _t0 = rtcall axion_str_len lit  ; Δ{}
  let _t1 = == _t0 125  ; Δ{}
  let _t1 = == _t0 34  ; Δ{}
  let _t1 = == _t0 93  ; Δ{}
  let _t1 = call >=$Int li _t0  ; Δ{}
  let _t1 = call isDigitCh _t0  ; Δ{}
  let _t1 = call isDigitCh _t0  ; Δ{}
  let _t1 = call isDigitCh _t0  ; Δ{}
  let _t1 = call isWsCh _t0  ; Δ{}
  let _t1 = rtcall axion_str_at e s  ; Δ{}
  let _t1 = rtcall axion_str_at j s  ; Δ{}
  let _t1 = rtcall axion_strcat "\":" _t0  ; Δ{_t0} · makes String
  let _t2 = == _t1 34  ; Δ{}
  let _t2 = rtcall axion_strcat k _t1  ; Δ{_t1} · makes String
  let _t4 = if neg then
  let _t5 = con JNum _t4  ; Δ{} · makes Json
  let _t6 = tuple _t5 k  ; Δ{_t5} · moves{_t5} · makes heap
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let c = rtcall axion_str_at i s  ; Δ{}
  let e = call strEnd s _t0  ; Δ{}
  let fp = if hasFrac then
  let hasFrac = == _t1 46  ; Δ{}
  let i = call skipWs s i0  ; Δ{}
  let i0 = if neg then
  let ip = call pfIntGo s i0 0f  ; Δ{}
  let j = call pfIntEnd s i0  ; Δ{}
  let j = call skipWs s i  ; Δ{}
  let j = call skipWs s i  ; Δ{}
  let k = if hasFrac then
  let mag = +. ip fp  ; Δ{}
  let neg = == _t0 45  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{}
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret case _t0 of
  ret case _t0 of
  ret case ms of
  ret case v of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Right _t6  ; Δ{_t6} · moves{_t6} · makes Either$String$tuple2$Json$Int
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t2 then
  ret rtcall axion_array_free _p  ; Δ{}
<=$Int x y  =
>=$Int x y  =
append$Json xs ys  =
append$Member xs ys  =
axion_drop_Array _p  =
axion_drop_Either$String _p  =
axion_drop_Either$String$Json _p  =
axion_drop_Either$String$tuple2$Json$Int _p  =
axion_drop_Json _p  =
axion_drop_List _p  =
axion_drop_List$Json _p  =
axion_drop_List$Member _p  =
axion_drop_Member _p  =
axion_drop_tuple2$Json$Int _p  =
isDigitCh c  =
isWsCh c  =
le$Int x y  =
litMatch s i lit li  =
main  =
parseArr s i acc  =
parseJson s  =
parseNum s i  =
parseObj s i acc  =
parseStr s i  =
parseVal s i0  =
pfFrac s i acc place  =
pfIntEnd s i  =
pfIntGo s i acc  =
reverse$Json xs  =
reverse$Member xs  =
roundtrip src  =
showArr xs  =
showJson v  =
showMember k val  =
showObj ms  =
skipWs s i  =
strEnd s i  =
