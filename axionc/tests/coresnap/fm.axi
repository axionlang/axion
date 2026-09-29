











































                        ret call loop cwd sel clip  ; Δ{}
                        ret putStr "\n"  ; Δ{}
                      else
                      let _t29 = rtcall axion_str_cmp key ""  ; Δ{}
                      let _t30 = == _t29 0  ; Δ{}
                      ret if _t30 then
                      ret putStr "\n"  ; Δ{}
                    else
                    let _t27 = rtcall axion_str_cmp key "q"  ; Δ{}
                    let _t28 = == _t27 0  ; Δ{}
                    ret call doPaste cwd sel clip  ; Δ{}
                    ret if _t28 then
                  drop _t23 : String
                  drop _t24 : String
                  else
                  let _d1000001 = call loop cwd sel _t24  ; Δ{_t24}
                  let _t23 = call entryAt cwd sel  ; Δ{} · makes String
                  let _t24 = call </> cwd _t23  ; Δ{_t23} · makes String
                  let _t25 = rtcall axion_str_cmp key "p"  ; Δ{}
                  let _t26 = == _t25 0  ; Δ{}
                  ret _d1000001  ; Δ{}
                  ret if _t26 then
                else
                let _t21 = rtcall axion_str_cmp key "c"  ; Δ{}
                let _t22 = == _t21 0  ; Δ{}
                ret call doMkdir cwd sel clip  ; Δ{}
                ret if _t22 then
              else
              let _t19 = rtcall axion_str_cmp key "m"  ; Δ{}
              let _t20 = == _t19 0  ; Δ{}
              ret call doRename cwd sel clip  ; Δ{}
              ret if _t20 then
            else
            let _t17 = rtcall axion_str_cmp key "r"  ; Δ{}
            let _t18 = == _t17 0  ; Δ{}
            let _t4 = con Cons z les  ; Δ{_t2 z} · moves{z}
            let _t5 = con Cons z gre  ; Δ{_t2 z} · moves{z}
            ret call doDelete cwd sel clip  ; Δ{}
            ret if _t18 then
            ret tuple _t4 gre  ; Δ{_t2} · makes heap
            ret tuple les _t5  ; Δ{_t2} · makes heap
          drop _t0 : tuple$List$String$List$String skip{0 1}
          drop _t14 : String
          drop _t2 : tuple$List$String$List$String skip{0 1}
          drop _t3 : String
          else
          else
          let _d1000000 = call loop _t14 0 clip  ; Δ{_t14}
          let _d1000000 = call step cwd sel clip _t3  ; Δ{_t3}
          let _t1 = call sort$String les  ; Δ{_t0 y} · makes List$String
          let _t14 = call dirName cwd  ; Δ{} · makes String
          let _t15 = rtcall axion_str_cmp key "d"  ; Δ{}
          let _t16 = == _t15 0  ; Δ{}
          let _t2 = call sort$String gre  ; Δ{_t0 _t1 y} · makes List$String
          let _t3 = call le$String z pivot  ; Δ{_t2 z}
          let _t3 = con Cons y _t2  ; Δ{_t0 _t1 _t2 y} · moves{_t2 y}
          let _t3 = rtcall axion_read_key 0  ; Δ{} · makes String
          let _t4 = call nEntries cwd  ; Δ{}
          let _t5 = call clampSel sel _t4  ; Δ{}
          ret _d1000000  ; Δ{}
          ret _d1000000  ; Δ{}
          ret call append _t1 _t3  ; Δ{_t0 _t1} · moves{_t1} · makes List
          ret call loop cwd _t5 clip  ; Δ{}
          ret call loop cwd sel clip  ; Δ{}
          ret if _t16 then
          ret if _t3 then
        (les, gre) ->
        (les, gre) ->
        _ ->
        _ ->
        _ ->
        drop y : String
        else
        let _t1 = - i 1  ; Δ{}
        let _t1 = call filter$$notDot ys  ; Δ{y ys} · moves{ys} · makes List$String
        let _t12 = rtcall axion_str_cmp key "h"  ; Δ{}
        let _t13 = == _t12 0  ; Δ{}
        ret - n 1  ; Δ{}
        ret call dup y  ; Δ{} · makes String
        ret call enter cwd sel clip  ; Δ{}
        ret call filter$$notDot ys  ; Δ{ys} · moves{ys} · makes List$String
        ret call pick _t1 ys  ; Δ{} · makes String
        ret con Cons y _t1  ; Δ{_t1 y} · moves{_t1 y} · makes List$String
        ret i  ; Δ{}
        ret if _t13 then
      drop _t0 : String
      drop _t1 : String
      drop _t1 : String
      drop _t2 : String
      drop _t2 : String
      drop _t4 : String
      drop _t4 : String
      drop _t5 : String
      drop _t5 : String
      drop _t6 : String
      drop _t7 : String
      drop _t7 : String
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs
      drop xs : List$String
      drop ys
      drop ys
      else
      else
      else
      else
      let _d1000000 = rtcall axion_strcat "'\\''" _t4  ; Δ{_t4} · makes String
      let _d1000000 = rtcall axion_strcat _t0 _t2  ; Δ{_t0 _t2} · makes String
      let _d1000001 = rtcall axion_strcat _t5 _t7  ; Δ{_t5 _t7} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$String _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
      let _t0 = == i 0  ; Δ{}
      let _t0 = call append zs ys  ; Δ{z zs} · moves{zs} · makes List
      let _t0 = call length ys  ; Δ{}
      let _t0 = call notDot y  ; Δ{y ys}
      let _t0 = call partitionLe$String y ys  ; Δ{y ys} · moves{ys} · makes tuple$List$String$List$String
      let _t0 = call rowLine y i sel  ; Δ{} · makes String
      let _t0 = con Nil  ; Δ{}
      let _t1 = + i 1  ; Δ{_t0}
      let _t1 = call render cwd sel  ; Δ{} · makes String
      let _t1 = con Nil  ; Δ{}
      let _t1 = rtcall axion_read_line 0  ; Δ{} · makes String
      let _t10 = rtcall axion_str_cmp key "l"  ; Δ{}
      let _t11 = == _t10 0  ; Δ{}
      let _t2 = call </> cwd _t1  ; Δ{_t1} · makes String
      let _t2 = call >=$Int i n  ; Δ{}
      let _t2 = call partitionLe$String pivot zs  ; Δ{z zs} · moves{zs} · makes tuple$List$String$List$String
      let _t2 = call renderRows ys _t1 sel  ; Δ{_t0} · makes String
      let _t2 = putStr _t1  ; Δ{_t1}
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = rtcall axion_mkdir_p _t2  ; Δ{_t2}
      let _t4 = + i 1  ; Δ{}
      let _t4 = call shEsc s _t3 n  ; Δ{} · makes String
      let _t4 = rtcall axion_read_line 0  ; Δ{} · makes String
      let _t5 = + i 1  ; Δ{}
      let _t5 = call entryAt cwd sel  ; Δ{_t4} · makes String
      let _t5 = call nEntries cwd  ; Δ{}
      let _t5 = rtcall axion_substr i 1 s  ; Δ{} · makes String
      let _t6 = + i 1  ; Δ{_t5}
      let _t6 = call </> cwd _t5  ; Δ{_t4 _t5} · makes String
      let _t6 = call clampSel sel _t5  ; Δ{}
      let _t6 = call nEntries cwd  ; Δ{}
      let _t7 = - sel 1  ; Δ{}
      let _t7 = call </> cwd _t4  ; Δ{_t4 _t6} · makes String
      let _t7 = call clampSel sel _t6  ; Δ{}
      let _t7 = call shEsc s _t6 n  ; Δ{_t5} · makes String
      let _t8 = call nEntries cwd  ; Δ{}
      let _t8 = rtcall axion_rename _t6 _t7  ; Δ{_t6 _t7}
      let _t9 = call clampSel _t7 _t8  ; Δ{}
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret + 1 _t0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret call findChar c s _t3 n  ; Δ{}
      ret call lastIndex c s _t4 i  ; Δ{}
      ret call lastIndex c s _t5 best  ; Δ{}
      ret call loop cwd _t6 clip  ; Δ{}
      ret call loop cwd _t7 clip  ; Δ{}
      ret call loop cwd _t9 clip  ; Δ{}
      ret case _t0 of
      ret case _t2 of
      ret case _t2 of
      ret case _t3 of
      ret case _t8 of
      ret con Cons z _t0  ; Δ{_t0 z} · moves{_t0 z}
      ret con Nil  ; Δ{}
      ret con Nil  ; Δ{} · makes List$String
      ret i  ; Δ{}
      ret if _t0 then
      ret if _t0 then
      ret if _t11 then
      ret if _t2 then
      ret tuple _t0 _t1  ; Δ{} · makes heap
      ret ys  ; Δ{}
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons y ys ->
    Cons z zs ->
    Cons z zs ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    _ ->
    _ ->
    _ ->
    _ ->
    _ ->
    drop _t0 : String
    drop _t3 : String
    drop _t4 : String
    drop _t4 : String
    drop _t7 : String
    else
    else
    else
    else
    else
    else
    else
    let _d1000000 = call loop _t4 0 clip  ; Δ{_t4}
    let _d1000000 = rtcall axion_strcat a _t0  ; Δ{_t0} · makes String
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd4 = == _tag 1  ; Δ{}
    let _dd5 = if _dd4 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t0 = rtcall axion_strcat "/" b  ; Δ{} · makes String
    let _t1 = < i 0  ; Δ{}
    let _t1 = call findChar 10 s i n  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t1 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = + sel 1  ; Δ{}
    let _t2 = == _t1 39  ; Δ{}
    let _t2 = == _t1 c  ; Δ{}
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_cmp x y  ; Δ{}
    let _t3 = == _t2 c  ; Δ{}
    let _t3 = call entryAt cwd sel  ; Δ{} · makes String
    let _t3 = call nEntries cwd  ; Δ{}
    let _t3 = rtcall axion_str_len p  ; Δ{}
    let _t3 = rtcall axion_str_len s  ; Δ{}
    let _t4 = call </> cwd _t3  ; Δ{_t3} · makes String
    let _t4 = call clampSel _t2 _t3  ; Δ{}
    let _t4 = rtcall axion_str_len q  ; Δ{}
    let _t4 = rtcall axion_substr 0 _t3 s  ; Δ{} · makes String
    let _t5 = - _t3 _t4  ; Δ{}
    let _t5 = rtcall axion_str_cmp _t4 p  ; Δ{_t4}
    let _t5 = rtcall axion_str_cmp key "k"  ; Δ{}
    let _t6 = == _t5 0  ; Δ{}
    let _t6 = rtcall axion_str_len q  ; Δ{}
    let _t7 = rtcall axion_substr _t5 _t6 s  ; Δ{} · makes String
    let _t8 = rtcall axion_str_cmp _t7 q  ; Δ{_t7}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "  "  ; Δ{}
    ret ""  ; Δ{}
    ret "."  ; Δ{}
    ret "."  ; Δ{}
    ret "> "  ; Δ{}
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
    ret == _t2 0  ; Δ{}
    ret == _t5 0  ; Δ{}
    ret == _t8 0  ; Δ{}
    ret == x y  ; Δ{}
    ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
    ret _d1000000  ; Δ{}
    ret a  ; Δ{}
    ret best  ; Δ{}
    ret call consLine s i n _t1  ; Δ{} · makes List$String
    ret call loop cwd _t4 clip  ; Δ{}
    ret call loop cwd sel clip  ; Δ{}
    ret con Nil  ; Δ{} · makes List$String
    ret if _t1 then
    ret if _t2 then
    ret if _t2 then
    ret if _t3 then
    ret if _t6 then
    ret n  ; Δ{}
    ret rtcall axion_strcat a b  ; Δ{} · makes String
    ret rtcall axion_substr 0 k s  ; Δ{} · makes String
  ; Δ{_t0 y}
  ; Δ{_t2 z}
  ; Δ{_t2 z}
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
  drop _t0 : List$String
  drop _t0 : List$String
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
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t1 : String
  drop _t2 : List$String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t2 : String
  drop _t3 : String
  drop _t3 : String
  drop _t3 : String
  drop _t4 : String
  drop _t4 : String
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
  let _d1000000 = call length _t0  ; Δ{_t0}
  let _d1000000 = call loop _t1 0 ""  ; Δ{_t1}
  let _d1000000 = call pick sel _t0  ; Δ{_t0} · makes String
  let _d1000000 = rtcall axion_strcat "'" _t2  ; Δ{_t2} · makes String
  let _d1000000 = rtcall axion_strcat _t1 _t2  ; Δ{_t2} · makes String
  let _d1000000 = rtcall axion_strcat _t1 _t4  ; Δ{_t1 _t4} · makes String
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _t0 = - 0 1  ; Δ{}
  let _t0 = - j i  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < i n  ; Δ{}
  let _t0 = < k 0  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == i sel  ; Δ{}
  let _t0 = == n 0  ; Δ{}
  let _t0 = call >=$Int i n  ; Δ{}
  let _t0 = call entriesOf cwd  ; Δ{} · makes List$String
  let _t0 = call entriesOf dir  ; Δ{} · makes List$String
  let _t0 = call entryAt cwd sel  ; Δ{} · makes String
  let _t0 = call entryAt cwd sel  ; Δ{} · makes String
  let _t0 = call entryAt cwd sel  ; Δ{} · makes String
  let _t0 = call hasPrefix "." name  ; Δ{}
  let _t0 = call shQuote clip  ; Δ{} · makes String
  let _t0 = call shQuote p  ; Δ{} · makes String
  let _t0 = putStr "\nmkdir: "  ; Δ{}
  let _t0 = rtcall axion_getarg 0  ; Δ{} · makes String
  let _t0 = rtcall axion_readdir dir  ; Δ{} · makes String
  let _t0 = rtcall axion_str_cmp key "j"  ; Δ{}
  let _t0 = rtcall axion_str_cmp x y  ; Δ{}
  let _t0 = rtcall axion_str_len a  ; Δ{}
  let _t0 = rtcall axion_str_len p  ; Δ{}
  let _t0 = rtcall axion_str_len q  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_strcat cwd " ==\n"  ; Δ{} · makes String
  let _t0 = rtcall axion_system "clear 2>/dev/null || true"  ; Δ{}
  let _t1 = < _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = call </> cwd _t0  ; Δ{_t0} · makes String
  let _t1 = call </> cwd _t0  ; Δ{_t0} · makes String
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call hasSuffix "/" a  ; Δ{}
  let _t1 = call lastIndex 47 s 0 _t0  ; Δ{}
  let _t1 = call lines _t0  ; Δ{_t0} · makes List$String
  let _t1 = call shEsc s 0 _t0  ; Δ{} · makes String
  let _t1 = call startDir _t0  ; Δ{_t0} · moves{_t0} · makes String
  let _t1 = if _t0 then
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_str_len s  ; Δ{}
  let _t1 = rtcall axion_strcat "== " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "cp -r -- " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat "test -d " _t0  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_strcat _t0 " to: "  ; Δ{_t0} · makes String
  let _t1 = rtcall axion_substr i _t0 s  ; Δ{} · makes String
  let _t2 = + j 1  ; Δ{_t1}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = > _t0 _t1  ; Δ{}
  let _t2 = call entriesOf cwd  ; Δ{_t1} · makes List$String
  let _t2 = call filter$$notDot _t1  ; Δ{_t1} · moves{_t1} · makes List$String
  let _t2 = call isDir _t1  ; Δ{_t1}
  let _t2 = call shQuote _t1  ; Δ{_t1} · makes String
  let _t2 = call shQuote cwd  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat "\nrename " _t1  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat _t1 "'"  ; Δ{_t1} · makes String
  let _t2 = rtcall axion_strcat name "\n"  ; Δ{} · makes String
  let _t2 = rtcall axion_system _t1  ; Δ{_t1}
  let _t3 = call linesFrom s _t2 n  ; Δ{_t1} · makes List$String
  let _t3 = call renderRows _t2 0 sel  ; Δ{_t1 _t2} · makes String
  let _t3 = putStr _t2  ; Δ{_t2}
  let _t3 = rtcall axion_strcat " " _t2  ; Δ{_t1 _t2} · makes String
  let _t3 = rtcall axion_strcat "rm -rf -- " _t2  ; Δ{_t2} · makes String
  let _t4 = rtcall axion_strcat _t1 _t3  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_strcat _t3 "-- j/k move  l enter  h up  d del  r rename  m mkdir  c yank  p paste  q quit --\n"  ; Δ{_t1 _t3} · makes String
  let _t4 = rtcall axion_system _t3  ; Δ{_t3}
  let _t5 = rtcall axion_system _t4  ; Δ{_t4}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret == _t2 0  ; Δ{}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call dirBefore s _t1  ; Δ{} · makes String
  ret call le$Int y x  ; Δ{}
  ret call linesFrom s 0 _t0  ; Δ{} · makes List$String
  ret call not _t0  ; Δ{}
  ret call sort$String _t2  ; Δ{_t2} · moves{_t2} · makes List$String
  ret case _t0 of
  ret case _t0 of
  ret case _t3 of
  ret case _t4 of
  ret case _t5 of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case xs of
  ret case ys of
  ret con Cons _t1 _t3  ; Δ{_t1 _t3} · moves{_t1 _t3} · makes List$String
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
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_substr 0 _t0 s  ; Δ{} · makes String
</> a b  =
>=$Int x y  =
append xs ys  =
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$String _p  =
clampSel i n  =
consLine s i n j  =
dirBefore s k  =
dirName s  =
doDelete cwd sel clip  =
doMkdir cwd sel clip  =
doPaste cwd sel clip  =
doRename cwd sel clip  =
dup s  =
enter cwd sel clip  =
entriesOf dir  =
entryAt cwd sel  =
filter$$notDot xs  =
findChar c s i n  =
hasPrefix p s  =
hasSuffix q s  =
isDir p  =
lastIndex c s i best  =
le$Int x y  =
le$String x y  =
length xs  =
lines s  =
linesFrom s i n  =
loop cwd sel clip  =
main  =
nEntries dir  =
not b  =
notDot name  =
partitionLe$String pivot ys  =
pick i xs  =
render cwd sel  =
renderRows xs i sel  =
rowLine name i sel  =
shEsc s i n  =
shQuote s  =
sort$String xs  =
startDir a  =
step cwd sel clip key  =
