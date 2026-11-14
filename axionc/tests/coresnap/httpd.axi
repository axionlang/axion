














































































                              ret "application/octet-stream"  ; Δ{}
                              ret "application/pdf"  ; Δ{}
                            drop _t0 : String
                            drop _t0 : String
                            else
                            let _t27 = rtcall axion_str_cmp _t0 "pdf"  ; Δ{_t0}
                            let _t28 = == _t27 0  ; Δ{}
                            ret "application/wasm"  ; Δ{}
                            ret if _t28 then
                          drop _t0 : String
                          else
                          let _t25 = rtcall axion_str_cmp _t0 "wasm"  ; Δ{_t0}
                          let _t26 = == _t25 0  ; Δ{_t0}
                          ret "image/x-icon"  ; Δ{}
                          ret if _t26 then
                        drop _t0 : String
                        else
                        let _t23 = rtcall axion_str_cmp _t0 "ico"  ; Δ{_t0}
                        let _t24 = == _t23 0  ; Δ{_t0}
                        ret "image/gif"  ; Δ{}
                        ret if _t24 then
                      drop _t0 : String
                      else
                      let _t21 = rtcall axion_str_cmp _t0 "gif"  ; Δ{_t0}
                      let _t22 = == _t21 0  ; Δ{_t0}
                      ret "image/jpeg"  ; Δ{}
                      ret if _t22 then
                    drop _t0 : String
                    else
                    let _t19 = rtcall axion_str_cmp _t0 "jpeg"  ; Δ{_t0}
                    let _t20 = == _t19 0  ; Δ{_t0}
                    ret "image/jpeg"  ; Δ{}
                    ret if _t20 then
                  drop _t0 : String
                  drop _t9
                  drop _t9
                  drop m : String
                  else
                  let _t10 = con Req m p  ; Δ{m p} · moves{m p} · makes Req
                  let _t17 = rtcall axion_str_cmp _t0 "jpg"  ; Δ{_t0}
                  let _t18 = == _t17 0  ; Δ{_t0}
                  ret "image/png"  ; Δ{}
                  ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$Int$Req
                  ret con Right _t10  ; Δ{_t10} · moves{_t10} · makes Either$Int$Req
                  ret if _t18 then
                Left $bindErr ->
                Right p ->
                drop _t0 : String
                else
                let _t15 = rtcall axion_str_cmp _t0 "png"  ; Δ{_t0}
                let _t16 = == _t15 0  ; Δ{_t0}
                ret "image/svg+xml"  ; Δ{}
                ret if _t16 then
              drop _t0 : String
              drop _t3
              drop _t3
              drop _t6
              drop _t6
              drop _t7 : String
              drop _t8 : String
              drop d : String
              drop d : String
              drop m : String
              drop parts : List$String
              drop parts : List$String
              drop segs : List$String
              drop v : String
              else
              let _t13 = rtcall axion_str_cmp _t0 "svg"  ; Δ{_t0}
              let _t14 = == _t13 0  ; Δ{_t0}
              let _t4 = call hasSuffix "/" d  ; Δ{d segs slash}
              let _t5 = call joinSegs segs _t4  ; Δ{segs slash} · makes String
              let _t7 = call pick 1 parts  ; Δ{m parts} · makes String
              let _t8 = call stripQuery _t7  ; Δ{_t7 m} · makes String
              let _t9 = call cleanPath _t8  ; Δ{_t8 m} · makes Either$Int$String
              ret "text/plain; charset=utf-8"  ; Δ{}
              ret case _t9 of
              ret con Left $bindErr  ; Δ{$bindErr slash} · moves{$bindErr} · makes Either$Int$String
              ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$Int$Req
              ret con Right _t5  ; Δ{_t5 slash} · moves{_t5} · makes Either$Int$String
              ret if _t14 then
            Left $bindErr ->
            Left $bindErr ->
            Right segs ->
            Right v ->
            drop _t0 : String
            else
            let _t11 = rtcall axion_str_cmp _t0 "txt"  ; Δ{_t0}
            let _t12 = == _t11 0  ; Δ{_t0}
            ret "application/json"  ; Δ{}
            ret if _t12 then
          drop _t0 : String
          drop _t1
          drop _t1
          drop _t4
          drop _t4
          drop parts : List$String
          drop s : String
          else
          let _t10 = == _t9 0  ; Δ{_t0}
          let _t2 = call splitOn 47 d  ; Δ{d slash} · makes List$String
          let _t3 = call safeSegments _t2  ; Δ{_t2 d slash} · moves{_t2} · makes Either$Int$List$String
          let _t5 = call pick 2 parts  ; Δ{m parts} · makes String
          let _t5 = rtcall axion_str_cmp s "."  ; Δ{rest s}
          let _t6 = call knownVersion _t5  ; Δ{_t5 m parts} · moves{_t5} · makes Either$Int$String
          let _t7 = call safeSegments rest  ; Δ{rest s} · moves{rest} · makes Either$Int$List$String
          let _t9 = rtcall axion_str_cmp _t0 "json"  ; Δ{_t0}
          ret "text/javascript"  ; Δ{}
          ret 1  ; Δ{rest s}
          ret == _t5 0  ; Δ{rest s}
          ret call consRight s _t7  ; Δ{_t7 s} · moves{_t7 s} · makes Either$Int$List$String
          ret call safeSegments rest  ; Δ{rest} · moves{rest} · makes Either$Int$List$String
          ret case _t3 of
          ret case _t6 of
          ret con Left $bindErr  ; Δ{$bindErr slash} · moves{$bindErr} · makes Either$Int$String
          ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$Int$Req
          ret if _t10 then
        Left $bindErr ->
        Left $bindErr ->
        Right d ->
        Right m ->
        drop _t0 : String
        drop _t2 : String
        drop _t29 : String
        drop _t3 : String
        drop rest : List$String
        drop s : String
        else
        else
        else
        let _d1000000 = rtcall axion_strcat _t2 _t3  ; Δ{_t2 _t3} · makes String
        let _t1 = - n 1  ; Δ{}
        let _t2 = rtcall axion_strcat s "/"  ; Δ{} · makes String
        let _t20 = + i 3  ; Δ{}
        let _t21 = + i 1  ; Δ{}
        let _t22 = rtcall axion_str_at _t21 t  ; Δ{}
        let _t23 = call hexVal _t22  ; Δ{}
        let _t24 = * _t23 16  ; Δ{}
        let _t25 = + i 2  ; Δ{}
        let _t26 = rtcall axion_str_at _t25 t  ; Δ{}
        let _t27 = call hexVal _t26  ; Δ{}
        let _t28 = + _t24 _t27  ; Δ{}
        let _t29 = rtcall axion_chr _t28  ; Δ{} · makes String
        let _t3 = call joinWith rest  ; Δ{_t2} · makes String
        let _t3 = rtcall axion_str_cmp s ""  ; Δ{rest s}
        let _t30 = rtcall axion_strcat acc _t29  ; Δ{_t29} · makes String
        let _t4 = == _t3 0  ; Δ{rest s}
        let _t6 = if _t4 then
        let _t7 = rtcall axion_str_cmp _t0 "js"  ; Δ{_t0}
        let _t8 = == _t7 0  ; Δ{_t0}
        ret "text/css"  ; Δ{}
        ret - c 55  ; Δ{}
        ret -1  ; Δ{}
        ret 0  ; Δ{}
        ret 1  ; Δ{}
        ret == c 13  ; Δ{}
        ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
        ret call <=$Int c 70  ; Δ{}
        ret call percentDecode t _t20 _t30  ; Δ{_t30} · moves{_t30} · makes Either$Int$String
        ret call pick _t1 ys  ; Δ{} · makes String
        ret con Left 400  ; Δ{} · makes Either$Int$String
        ret con Left 403  ; Δ{} · makes Either$Int$List$String
        ret if _t6 then
        ret if _t8 then
        ret rtcall axion_strcat s ""  ; Δ{} · makes String
        ret rtcall axion_strcat y ""  ; Δ{} · makes String
      drop _t0
      drop _t0
      drop _t0 : String
      drop _t0 : String
      drop _t2
      drop _t2
      drop _t5 : String
      drop acc : String
      drop acc : String
      drop m
      drop m
      drop r
      drop r
      drop s : String
      drop segs
      drop segs
      else
      else
      else
      else
      else
      else
      else
      else
      let _d1000000 = rtcall axion_strcat s _t0  ; Δ{_t0} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _rcl2000000 = call decodeEscape t i acc  ; Δ{} · makes Either$Int$String
      let _t0 = == n 0  ; Δ{}
      let _t0 = call concatStr rest  ; Δ{} · makes String
      let _t0 = call length rest  ; Δ{}
      let _t0 = call length ys  ; Δ{}
      let _t0 = con Cons s xs  ; Δ{xs} · moves{xs} · makes List$String
      let _t0 = con Nil  ; Δ{} · makes List$String
      let _t1 = == _t0 0  ; Δ{}
      let _t1 = call percentDecode t 0 ""  ; Δ{slash} · makes Either$Int$String
      let _t1 = rtcall axion_str_cmp s ".."  ; Δ{rest s}
      let _t11 = + i 1  ; Δ{}
      let _t12 = rtcall axion_str_at _t11 t  ; Δ{}
      let _t13 = call hexVal _t12  ; Δ{}
      let _t14 = * _t13 16  ; Δ{}
      let _t15 = + i 2  ; Δ{}
      let _t16 = rtcall axion_str_at _t15 t  ; Δ{}
      let _t17 = call hexVal _t16  ; Δ{}
      let _t18 = + _t14 _t17  ; Δ{}
      let _t19 = == _t18 0  ; Δ{}
      let _t2 = == _t1 0  ; Δ{rest s}
      let _t2 = == c 10  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = call pick 0 parts  ; Δ{parts} · makes String
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = call >=$Int c 65  ; Δ{}
      let _t4 = call knownMethod _t3  ; Δ{_t3 parts} · moves{_t3} · makes Either$Int$String
      let _t4 = rtcall axion_str_at i s  ; Δ{}
      let _t4 = rtcall axion_str_at i t  ; Δ{}
      let _t5 = * acc 10  ; Δ{}
      let _t5 = + i 1  ; Δ{}
      let _t5 = if _t4 then
      let _t5 = rtcall axion_str_cmp _t0 "css"  ; Δ{_t0}
      let _t5 = rtcall axion_substr i 1 t  ; Δ{} · makes String
      let _t6 = == _t5 0  ; Δ{_t0}
      let _t6 = rtcall axion_str_at i s  ; Δ{}
      let _t6 = rtcall axion_strcat acc _t5  ; Δ{_t5} · makes String
      let _t7 = + i 2  ; Δ{}
      let _t7 = - _t6 48  ; Δ{}
      let _t8 = + _t5 _t7  ; Δ{}
      let _t8 = + i 1  ; Δ{}
      let _t8 = rtcall axion_str_at _t7 t  ; Δ{}
      let _t9 = call hexVal _t8  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret "Bad Request"  ; Δ{}
      ret "Forbidden"  ; Δ{}
      ret "HTTP Version Not Supported"  ; Δ{}
      ret "Internal Server Error"  ; Δ{}
      ret "Method Not Allowed"  ; Δ{}
      ret "Not Found"  ; Δ{}
      ret "OK"  ; Δ{}
      ret "Request Header Fields Too Large"  ; Δ{}
      ret "text/html; charset=utf-8"  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret + c 32  ; Δ{}
      ret - c 87  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 1  ; Δ{}
      ret 403  ; Δ{}
      ret 500  ; Δ{}
      ret < _t9 0  ; Δ{}
      ret == _t4 10  ; Δ{}
      ret == _t4 35  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _rcl2000000  ; Δ{_rcl2000000} · moves{_rcl2000000}
      ret c  ; Δ{}
      ret call <=$Int c 102  ; Δ{}
      ret call findChar c s _t3 n  ; Δ{}
      ret call findFrom s pat _t8  ; Δ{}
      ret call lastIndex c s _t4 i  ; Δ{}
      ret call lastIndex c s _t5 best  ; Δ{}
      ret call percentDecode t _t4 _t6  ; Δ{_t6} · moves{_t6} · makes Either$Int$String
      ret call readIntGo s _t4 _t8  ; Δ{} · makes Maybe$Int
      ret call wordEnd s _t3 n  ; Δ{}
      ret callclo f x  ; Δ{x} · moves{x}
      ret case _t1 of
      ret case _t4 of
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$Int$Req
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$Int$String
      ret con Left 400  ; Δ{} · makes Either$Int$String
      ret con Left e  ; Δ{e} · moves{e} · makes Either$Int$List$String
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret con Right _t0  ; Δ{_t0} · moves{_t0} · makes Either$Int$List$String
      ret con Right _t0  ; Δ{_t0} · moves{_t0} · makes Either$Int$List$String
      ret d  ; Δ{}
      ret i  ; Δ{}
      ret i  ; Δ{}
      ret i  ; Δ{}
      ret if _t0 then
      ret if _t1 then
      ret if _t19 then
      ret if _t2 then
      ret if _t2 then
      ret if _t5 then
      ret if _t6 then
    200 ->
    400 ->
    403 ->
    404 ->
    405 ->
    431 ->
    505 ->
    Cons s rest ->
    Cons s rest ->
    Cons s rest ->
    Cons y ys ->
    Cons y ys ->
    Just x ->
    Left $bindErr ->
    Left $bindErr ->
    Left e ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nothing ->
    Right parts ->
    Right slash ->
    Right xs ->
    _ ->
    drop _t0 : String
    drop _t3 : String
    drop _t5 : String
    drop _t5 : String
    drop _t7 : String
    drop m : String
    drop v : String
    drop ws : List$String
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
    let _d1000000 = rtcall axion_strcat _t3 _t5  ; Δ{_t3 _t5} · makes String
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
    let _dd1 = call axion_drop_Req _dd0  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + k 1  ; Δ{}
    let _t1 = == c 9  ; Δ{}
    let _t1 = call <=$Int c 90  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t10 = if _t6 then
    let _t2 = + i 1  ; Δ{}
    let _t2 = == _t1 c  ; Δ{}
    let _t2 = == e 13  ; Δ{}
    let _t2 = call >=$Int c 97  ; Δ{}
    let _t2 = call findFrom s "\n\n" 0  ; Δ{}
    let _t2 = call isSpace _t1  ; Δ{}
    let _t2 = call lastIndex 46 b 0 -1  ; Δ{}
    let _t2 = call length segs  ; Δ{_t1}
    let _t2 = call lowerChar _t1  ; Δ{}
    let _t2 = rtcall axion_str_at 0 t  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_at i t  ; Δ{}
    let _t2 = rtcall axion_str_at i t  ; Δ{}
    let _t2 = rtcall axion_str_cmp m "HEAD"  ; Δ{}
    let _t2 = rtcall axion_str_cmp v "HTTP/1.0"  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t3 = + _t2 1  ; Δ{}
    let _t3 = + i 1  ; Δ{}
    let _t3 = + j 1  ; Δ{_t1}
    let _t3 = - _t2 k  ; Δ{}
    let _t3 = == _t2 13  ; Δ{}
    let _t3 = == _t2 37  ; Δ{}
    let _t3 = == _t2 63  ; Δ{}
    let _t3 = == _t2 c  ; Δ{}
    let _t3 = call isDigit _t2  ; Δ{}
    let _t3 = call wordEnd s i n  ; Δ{}
    let _t3 = if _t2 then
    let _t3 = rtcall axion_chr _t2  ; Δ{} · makes String
    let _t3 = rtcall axion_str_cmp _t0 "htm"  ; Δ{_t0}
    let _t3 = rtcall axion_str_len s  ; Δ{}
    let _t4 = + i 1  ; Δ{_t3}
    let _t4 = - _t3 1  ; Δ{}
    let _t4 = == _t3 0  ; Δ{_t0}
    let _t4 = rtcall axion_str_at _t3 t  ; Δ{}
    let _t4 = rtcall axion_str_len b  ; Δ{}
    let _t4 = rtcall axion_str_len pat  ; Δ{}
    let _t4 = rtcall axion_str_len q  ; Δ{}
    let _t5 = - _t3 _t4  ; Δ{}
    let _t5 = call hexVal _t4  ; Δ{}
    let _t5 = call toLowerGo s _t4 n  ; Δ{_t3} · makes String
    let _t5 = rtcall axion_substr i _t4 s  ; Δ{} · makes String
    let _t6 = + i 1  ; Δ{}
    let _t6 = + i 1  ; Δ{}
    let _t6 = < _t5 0  ; Δ{}
    let _t6 = rtcall axion_str_cmp _t5 pat  ; Δ{_t5}
    let _t6 = rtcall axion_str_len q  ; Δ{}
    let _t7 = == _t6 0  ; Δ{}
    let _t7 = rtcall axion_substr _t5 _t6 s  ; Δ{} · makes String
    let _t8 = rtcall axion_str_cmp _t7 q  ; Δ{_t7}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret ""  ; Δ{_t1}
    ret ""  ; Δ{}
    ret ""  ; Δ{}
    ret "."  ; Δ{}
    ret "/"  ; Δ{_t1}
    ret "text/html; charset=utf-8"  ; Δ{}
    ret - c 48  ; Δ{}
    ret -1  ; Δ{}
    ret 0  ; Δ{_t1}
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
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 1  ; Δ{}
    ret 404  ; Δ{}
    ret == _t2 0  ; Δ{}
    ret == _t2 0  ; Δ{}
    ret == _t2 47  ; Δ{}
    ret == _t8 0  ; Δ{}
    ret == e 20  ; Δ{}
    ret == x y  ; Δ{}
    ret > _t2 0  ; Δ{_t1}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret best  ; Δ{}
    ret c  ; Δ{}
    ret call <=$Int c 57  ; Δ{}
    ret call <=$Int c 57  ; Δ{}
    ret call >=$Int _t2 0  ; Δ{}
    ret call consWord s i n _t3  ; Δ{} · makes List$String
    ret call cutAt t _t6  ; Δ{}
    ret call lineEnd s _t6  ; Δ{}
    ret call readIntGo s 0 0  ; Δ{} · makes Maybe$Int
    ret call splitFrom c s _t3 n  ; Δ{_t1} · makes List$String
    ret call wordsFrom s _t2 n  ; Δ{} · makes List$String
    ret call wordsStep s i n  ; Δ{} · makes List$String
    ret con Just acc  ; Δ{} · makes Maybe$Int
    ret con Left 400  ; Δ{} · makes Either$Int$Int
    ret con Left 400  ; Δ{} · makes Either$Int$List$String
    ret con Left 400  ; Δ{} · makes Either$Int$String
    ret con Left 405  ; Δ{} · makes Either$Int$String
    ret con Left 505  ; Δ{} · makes Either$Int$String
    ret con Nil  ; Δ{_t1} · makes List$String
    ret con Nil  ; Δ{} · makes List$String
    ret con Nothing  ; Δ{} · makes Maybe$Int
    ret con Right 0  ; Δ{} · makes Either$Int$Int
    ret con Right acc  ; Δ{} · makes Either$Int$String
    ret con Right m  ; Δ{} · makes Either$Int$String
    ret con Right v  ; Δ{} · makes Either$Int$String
    ret con Right ws  ; Δ{} · makes Either$Int$List$String
    ret i  ; Δ{}
    ret i  ; Δ{}
    ret i  ; Δ{}
    ret if _t1 then
    ret if _t1 then
    ret if _t10 then
    ret if _t2 then
    ret if _t2 then
    ret if _t2 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t4 then
    ret if _t7 then
    ret n  ; Δ{}
    ret rtcall axion_getenv "AXHTTPD_ROOT"  ; Δ{} · makes String
    ret rtcall axion_strcat p ""  ; Δ{_t0} · makes String
    ret rtcall axion_strcat p "index.html"  ; Δ{_t0} · makes String
    ret rtcall axion_strcat s ""  ; Δ{} · makes String
    ret rtcall axion_substr _t1 _t4 s  ; Δ{} · makes String
    ret rtcall axion_substr _t3 _t4 b  ; Δ{} · makes String
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t1 slash}
  ; Δ{_t1}
  ; Δ{_t1}
  ; Δ{_t1}
  ; Δ{_t2}
  ; Δ{_t3 d slash}
  ; Δ{_t4 parts}
  ; Δ{_t6 m parts}
  ; Δ{_t9 m}
  ; Δ{rest s}
  ; Δ{rest s}
  ; Δ{rest s}
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
  drop _t0
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t0 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t3 : String
  drop _t3 : String
  drop _t3 : String
  drop _t8 : List$String
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
  let _d1000000 = call concatStr _t8  ; Δ{_t8} · makes String
  let _d1000000 = call maybe d _t0 m  ; Δ{_t0}
  let _d1000000 = call toLower _t1  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t1 _t4  ; Δ{_t1} · makes String
  let _d1000000 = rtcall axion_strcat _t2 _t3  ; Δ{_t2 _t3} · makes String
  let _d1000000 = rtcall axion_strcat _t2 _t3  ; Δ{_t2 _t3} · makes String
  let _dd0 = band _p 1  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = + i 2  ; Δ{}
  let _t0 = - 0 1  ; Δ{}
  let _t0 = - j i  ; Δ{}
  let _t0 = - j i  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < k 0  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == c 32  ; Δ{}
  let _t0 = == e 2  ; Δ{}
  let _t0 = call >=$Int c 48  ; Δ{}
  let _t0 = call >=$Int c 48  ; Δ{}
  let _t0 = call >=$Int c 65  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call baseName path  ; Δ{} · makes String
  let _t0 = call cutAt t 0  ; Δ{}
  let _t0 = call docRoot 0  ; Δ{} · makes String
  let _t0 = call eq$Int x y  ; Δ{}
  let _t0 = call errorBody code  ; Δ{} · makes String
  let _t0 = call extension path  ; Δ{} · makes String
  let _t0 = call findChar c s i n  ; Δ{}
  let _t0 = call findFrom s "\r\n\r\n" 0  ; Δ{}
  let _t0 = call firstLine raw  ; Δ{} · makes String
  let _t0 = call joinWith segs  ; Δ{} · makes String
  let _t0 = call lastIndex 46 b 0 -1  ; Δ{}
  let _t0 = call length ws  ; Δ{}
  let _t0 = call lineEnd raw 0  ; Δ{}
  let _t0 = call mimeType path  ; Δ{} · makes String
  let _t0 = call startsWithSlash t  ; Δ{} · makes Either$Int$Int
  let _t0 = call statusLine code  ; Δ{} · makes String
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = rtcall axion_getenv "AXHTTPD_MAX"  ; Δ{} · makes String
  let _t0 = rtcall axion_getenv "AXHTTPD_PORT"  ; Δ{} · makes String
  let _t0 = rtcall axion_getenv "AXHTTPD_ROOT"  ; Δ{} · makes String
  let _t0 = rtcall axion_str_at i s  ; Δ{}
  let _t0 = rtcall axion_str_cmp m "GET"  ; Δ{}
  let _t0 = rtcall axion_str_cmp m "HEAD"  ; Δ{}
  let _t0 = rtcall axion_str_cmp v "HTTP/1.1"  ; Δ{}
  let _t0 = rtcall axion_str_len pat  ; Δ{}
  let _t0 = rtcall axion_str_len q  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len t  ; Δ{}
  let _t0 = rtcall axion_str_len t  ; Δ{}
  let _t0 = rtcall axion_str_len t  ; Δ{}
  let _t0 = showInt code  ; Δ{} · makes String
  let _t0 = showInt code  ; Δ{} · makes String
  let _t1 = + i _t0  ; Δ{}
  let _t1 = - _t0 off  ; Δ{}
  let _t1 = < _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 3  ; Δ{}
  let _t1 = > _t0 0  ; Δ{}
  let _t1 = call >=$Int _t0 0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call baseAfterDot _t0  ; Δ{_t0} · makes String
  let _t1 = call hasSuffix "/" p  ; Δ{_t0}
  let _t1 = call isSpace _t0  ; Δ{}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = call readInt _t0  ; Δ{_t0} · makes Maybe$Int
  let _t1 = call readInt _t0  ; Δ{_t0} · makes Maybe$Int
  let _t1 = call words _t0  ; Δ{_t0} · makes List$String
  let _t1 = if _t0 then
  let _t1 = if _t0 then
  let _t1 = rtcall axion_str_cmp _t0 "html"  ; Δ{_t0}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_str_len t  ; Δ{}
  let _t1 = rtcall axion_strcat "/" _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "HTTP/1.1 " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " "  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t1 = showInt len  ; Δ{_t0} · makes String
  let _t2 = < j n  ; Δ{_t1}
  let _t2 = == _t1 0  ; Δ{_t0}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = call >=$Int _t0 _t1  ; Δ{}
  let _t2 = call header code "text/plain; charset=utf-8" _t1  ; Δ{} · makes String
  let _t2 = call reason code  ; Δ{_t1} · makes String
  let _t2 = call threeWords _t1  ; Δ{_t1} · moves{_t1} · makes Either$Int$List$String
  let _t2 = call wordsFrom s j n  ; Δ{_t1} · makes List$String
  let _t2 = con Nil  ; Δ{_t0 _t1} · makes List$String
  let _t2 = if _t1 then
  let _t2 = rtcall axion_str_len s  ; Δ{}
  let _t2 = rtcall axion_strcat _t1 " "  ; Δ{_t1} · makes String
  let _t3 = > _t1 _t2  ; Δ{}
  let _t3 = call errorBody code  ; Δ{_t2} · makes String
  let _t3 = call reason code  ; Δ{_t2} · makes String
  let _t3 = con Cons "\r\nConnection: close\r\nServer: axhttpd\r\n\r\n" _t2  ; Δ{_t0 _t1 _t2} · moves{_t2} · makes List$String
  let _t3 = if _t1 then
  let _t3 = if _t1 then
  let _t3 = if _t1 then
  let _t3 = if dir then
  let _t3 = rtcall axion_strcat _t2 "\n"  ; Δ{_t1 _t2} · makes String
  let _t4 = con Cons _t1 _t3  ; Δ{_t0 _t1 _t3} · moves{_t1 _t3} · makes List$String
  let _t4 = if _t2 then
  let _t4 = if _t3 then
  let _t5 = con Cons "\r\nContent-Length: " _t4  ; Δ{_t0 _t4} · moves{_t4} · makes List$String
  let _t5 = if _t1 then
  let _t5 = if _t1 then
  let _t6 = con Cons ctype _t5  ; Δ{_t0 _t5} · moves{_t5} · makes List$String
  let _t7 = con Cons "\r\nContent-Type: " _t6  ; Δ{_t0 _t6} · moves{_t6} · makes List$String
  let _t8 = con Cons _t0 _t7  ; Δ{_t0 _t7} · moves{_t0 _t7} · makes List$String
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let sess$fa = &main$step  ; Δ{}
  let sess$res = rtcall axion_sess_run_par sess$sched sess$fa sess$root  ; Δ{}
  let sess$root = rtcall axion_sess_alloc sess$sched 24  ; Δ{}
  let sess$sched = rtcall axion_sess_new  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret 65536  ; Δ{}
  ret 8192  ; Δ{}
  ret == _t0 0  ; Δ{}
  ret == x y  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{}
  ret call baseAfter s _t1  ; Δ{} · makes String
  ret call consSplit c s i n _t0  ; Δ{} · makes List$String
  ret call fromMaybe -1 _t1  ; Δ{_t1} · moves{_t1}
  ret call fromMaybe 8080 _t1  ; Δ{_t1} · moves{_t1}
  ret call header 200 _t0 size  ; Δ{_t0} · moves{_t0} · makes String
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call splitFrom c s 0 _t0  ; Δ{} · makes List$String
  ret call toLowerGo s 0 _t0  ; Δ{} · makes String
  ret call wordsFrom s 0 _t0  ; Δ{} · makes List$String
  ret case _t0 of
  ret case _t2 of
  ret case code of
  ret case m of
  ret case r of
  ret case segs of
  ret case segs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret con Cons _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes List$String
  ret con Cons _t1 _t4  ; Δ{_t1} · moves{_t1} · makes List$String
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
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t1 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t3 then
  ret if _t3 then
  ret if _t3 then
  ret if _t3 then
  ret if _t5 then
  ret if _t5 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_substr 0 _t0 raw  ; Δ{} · makes String
  ret rtcall axion_substr 0 _t0 t  ; Δ{} · makes String
  ret rtcall axion_substr off _t1 s  ; Δ{} · makes String
  ret sess$res  ; Δ{}
  ret x  ; Δ{}
/=$Int x y  =
<=$Int x y  =
>=$Int x y  =
axion_drop_Array _p  =
axion_drop_Either$Int _p  =
axion_drop_Either$Int$Int _p  =
axion_drop_Either$Int$List$String _p  =
axion_drop_Either$Int$Req _p  =
axion_drop_Either$Int$String _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
axion_drop_Maybe$Int _p  =
axion_drop_Req _p  =
baseAfter s k  =
baseAfterDot b  =
baseName s  =
chunkSize d  =
cleanPath t  =
concatStr xs  =
consRight s r  =
consSplit c s i n j  =
consWord s i n j  =
cutAt t i  =
decodeEscape t i acc  =
docRoot d  =
eq$Int x y  =
errnoStatus e  =
errorBody code  =
errorResponse code  =
extension path  =
filePath p  =
findChar c s i n  =
findFrom s pat i  =
firstLine raw  =
from s off  =
fromMaybe d m  =
hasSuffix q s  =
headDone s  =
header code ctype len  =
hexVal c  =
isDigit c  =
isHead m  =
isSpace c  =
joinSegs segs dir  =
joinWith segs  =
knownMethod m  =
knownVersion v  =
lam$0 [env ]x  =
lastIndex c s i best  =
le$Int x y  =
length xs  =
lineEnd s i  =
listenPort d  =
lowerChar c  =
main  =
maxConns d  =
maxHead d  =
maybe d f m  =
mimeType path  =
okHeader path size  =
parseReq raw  =
percentDecode t i acc  =
pick n xs  =
readInt s  =
readIntGo s i acc  =
reason code  =
safeSegments segs  =
splitFrom c s i n  =
splitOn c s  =
startsWithSlash t  =
statusLine code  =
stripQuery t  =
threeWords ws  =
toLower s  =
toLowerGo s i n  =
wordEnd s i n  =
words s  =
wordsFrom s i n  =
wordsStep s i n  =
