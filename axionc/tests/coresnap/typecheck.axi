





















































                                          drop _t5
                                          drop _t5
                                          drop _t5
                                          drop _t5
                                          let _t6 = con NInt  ; Δ{$bind7001 $bind7001$1 $bind7001$2 $bind7001$3 st6} · makes Node
                                          let _t6 = tuple st6 tt  ; Δ{$bind8331 $bind8331$1 $bind8331$2 $bind8331$3 st6} · moves{st6} · makes heap
                                          let _t7 = call addNode st6 _t6  ; Δ{$bind7001 $bind7001$1 $bind7001$2 $bind7001$3 _t6 st6} · moves{_t6 st6} · makes tuple2$St$Int
                                          ret con Left $bindErr  ; Δ{$bind7001 $bind7001$1 $bind7001$2 $bind7001$3 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
                                          ret con Left $bindErr  ; Δ{$bind8331 $bind8331$1 $bind8331$2 $bind8331$3 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
                                          ret con Right _t6  ; Δ{$bind8331 $bind8331$1 $bind8331$2 $bind8331$3 _t6} · moves{_t6} · makes Either$String$tuple2$St$Int
                                          ret con Right _t7  ; Δ{$bind7001 $bind7001$1 $bind7001$2 $bind7001$3 _t7} · moves{_t7} · makes Either$String$tuple2$St$Int
                                        Left $bindErr ->
                                        Left $bindErr ->
                                        Right st6 ->
                                        Right st6 ->
                                      drop $bind7001$3 : tuple2$St$Int skip{0}
                                      drop $bind8331$3 : tuple2$St$Int skip{0}
                                      drop _t4
                                      drop _t4
                                      let _t5 = call stUnify st5 tb i2  ; Δ{$bind7001 $bind7001$1 $bind7001$2 $bind7001$3} · makes Either$String$St
                                      let _t5 = call stUnify st5 tt te  ; Δ{$bind8331 $bind8331$1 $bind8331$2 $bind8331$3} · makes Either$String$St
                                      let _t5 = tuple st5 tr  ; Δ{$bind7647 $bind7647$1 $bind7647$2 $bind7647$3 st5} · moves{st5} · makes heap
                                      ret case _t5 of
                                      ret case _t5 of
                                      ret con Left $bindErr  ; Δ{$bind7647 $bind7647$1 $bind7647$2 $bind7647$3 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
                                      ret con Right _t5  ; Δ{$bind7647 $bind7647$1 $bind7647$2 $bind7647$3 _t5} · moves{_t5} · makes Either$String$tuple2$St$Int
                                    (st5, i2) ->
                                    (st5, te) ->
                                    Left $bindErr ->
                                    Right st5 ->
                                  drop $bind7647$3 : tuple2$St$Int skip{0}
                                  drop _t4
                                  drop _t4
                                  drop _t4
                                  drop _t4
                                  let _t4 = call stUnify st4 tf tfun  ; Δ{$bind7647 $bind7647$1 $bind7647$2 $bind7647$3} · makes Either$String$St
                                  ret case $bind7001$3 of
                                  ret case $bind8331$3 of
                                  ret case _t4 of
                                  ret con Left $bindErr  ; Δ{$bind7001 $bind7001$1 $bind7001$2 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
                                  ret con Left $bindErr  ; Δ{$bind8331 $bind8331$1 $bind8331$2 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
                                (st4, tfun) ->
                                Left $bindErr ->
                                Left $bindErr ->
                                Right $bind7001$3 ->
                                Right $bind8331$3 ->
                              drop $bind7001$2 : tuple2$St$Int skip{0}
                              drop $bind8331$2 : tuple2$St$Int skip{0}
                              drop _t3
                              drop _t3
                              let _t4 = call infer st4 env el  ; Δ{$bind8331 $bind8331$1 $bind8331$2} · makes Either$String$tuple2$St$Int
                              let _t4 = call intNode st4  ; Δ{$bind7001 $bind7001$1 $bind7001$2} · makes Either$String$tuple2$St$Int
                              ret case $bind7647$3 of
                              ret case _t4 of
                              ret case _t4 of
                              ret con Left $bindErr  ; Δ{$bind7647 $bind7647$1 $bind7647$2 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
                            (st4, tb) ->
                            (st4, tt) ->
                            Left $bindErr ->
                            Right $bind7647$3 ->
                          drop $bind7647$2 : tuple2$St$Int skip{0}
                          drop _t3
                          drop _t3
                          drop _t3
                          drop _t3
                          let _t3 = call funNode st3 ta tr  ; Δ{$bind7647 $bind7647$1 $bind7647$2} · makes Either$String$tuple2$St$Int
                          ret case $bind7001$2 of
                          ret case $bind8331$2 of
                          ret case _t3 of
                          ret con Left $bindErr  ; Δ{$bind7001 $bind7001$1 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
                          ret con Left $bindErr  ; Δ{$bind8331 $bind8331$1 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
                        (st3, tr) ->
                        Left $bindErr ->
                        Left $bindErr ->
                        Right $bind7001$2 ->
                        Right $bind8331$2 ->
                      drop _t15 : Expr
                      drop _t16 : String
                      drop _t2
                      drop _t2
                      drop _t2
                      drop _t2
                      drop _t2
                      drop _t2
                      let _d1000000 = putStrLn _t16  ; Δ{_t16}
                      let _t15 = call p6  ; Δ{} · makes Expr
                      let _t16 = call typeOf _t15  ; Δ{_t15} · makes String
                      let _t3 = call infer st3 env b  ; Δ{$bind7001 $bind7001$1 st3} · moves{st3} · makes Either$String$tuple2$St$Int
                      let _t3 = call infer st3 env t  ; Δ{$bind8331 $bind8331$1 st3} · moves{st3} · makes Either$String$tuple2$St$Int
                      ret _d1000000  ; Δ{}
                      ret case $bind7647$2 of
                      ret case _t3 of
                      ret case _t3 of
                      ret con Left $bindErr  ; Δ{$bind7001 $bind7001$1 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
                      ret con Left $bindErr  ; Δ{$bind7647 $bind7647$1 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
                      ret con Left $bindErr  ; Δ{$bind8331 $bind8331$1 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
                    Left $bindErr ->
                    Left $bindErr ->
                    Left $bindErr ->
                    Right $bind7647$2 ->
                    Right st3 ->
                    Right st3 ->
                    _ ->
                  drop $bind7001$1 : tuple2$St$Int skip{0}
                  drop $bind7647$1 : tuple2$St$Int skip{0}
                  drop $bind8331$1 : tuple2$St$Int skip{0}
                  drop _t12 : Expr
                  drop _t13 : String
                  let _t12 = call p5  ; Δ{} · makes Expr
                  let _t13 = call typeOf _t12  ; Δ{_t12} · makes String
                  let _t14 = putStrLn _t13  ; Δ{_t13}
                  let _t2 = call freshVarE st2  ; Δ{$bind7647 $bind7647$1} · makes Either$String$tuple2$St$Int
                  let _t2 = call stUnify st2 ta i1  ; Δ{$bind7001 $bind7001$1} · makes Either$String$St
                  let _t2 = call stUnify st2 tc ic  ; Δ{$bind8331 $bind8331$1} · makes Either$String$St
                  ret case _t14 of
                  ret case _t2 of
                  ret case _t2 of
                  ret case _t2 of
                (st2, i1) ->
                (st2, ic) ->
                (st2, ta) ->
                _ ->
              drop $bind7428 : tuple2$St$Int skip{0}
              drop _t1
              drop _t1
              drop _t1
              drop _t1
              drop _t1
              drop _t1
              drop _t10 : String
              drop _t9 : Expr
              drop st
              drop store : List$tuple2$Int$Node
              drop sub : List$tuple2$Int$Int
              let _d1000001 = call showType store sub i  ; Δ{res} · makes String
              let _t10 = call typeOf _t9  ; Δ{_t9} · makes String
              let _t11 = putStrLn _t10  ; Δ{_t10}
              let _t6 = con NFun tx tbody  ; Δ{$bind7428 _t0} · makes Node
              let _t7 = call addNode st2 _t6  ; Δ{$bind7428 _t0 _t6} · moves{_t6} · makes tuple2$St$Int
              let _t9 = call p4  ; Δ{} · makes Expr
              ret _d1000001  ; Δ{_d1000001 res} · moves{_d1000001}
              ret case $bind7001$1 of
              ret case $bind7647$1 of
              ret case $bind8331$1 of
              ret case _t11 of
              ret con Left $bindErr  ; Δ{$bind7001 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
              ret con Left $bindErr  ; Δ{$bind7647 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
              ret con Left $bindErr  ; Δ{$bind8331 $bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
              ret con Right _t7  ; Δ{$bind7428 _t0 _t7} · moves{_t7} · makes Either$String$tuple2$St$Int
            (st2, tbody) ->
            Left $bindErr ->
            Left $bindErr ->
            Left $bindErr ->
            Right $bind7001$1 ->
            Right $bind7647$1 ->
            Right $bind8331$1 ->
            St store sub c ->
            _ ->
            ret call copyNode nd  ; Δ{} · makes Node
            ret call envLook x rest  ; Δ{} · makes Either$String$Int
            ret call getNode rest i  ; Δ{} · makes Node
            ret call lookupI n rest  ; Δ{} · makes Maybe$Int
            ret con Just v  ; Δ{} · makes Maybe$Int
            ret con Right v  ; Δ{} · makes Either$String$Int
          drop $bind7001 : tuple2$St$Int skip{0}
          drop $bind7647 : tuple2$St$Int skip{0}
          drop $bind8129 : tuple2$St$Int skip{0}
          drop $bind8331 : tuple2$St$Int skip{0}
          drop _t0
          drop _t0
          drop _t1
          drop _t1
          drop _t4 : List$tuple2$String$Int
          drop _t5
          drop _t5
          drop _t6 : Expr
          drop _t7 : String
          drop res : tuple2$St$Int skip{0}
          drop store : List$tuple2$Int$Node
          else
          else
          else
          let _d1000000 = call infer st1 _t4 body  ; Δ{$bind8129 _t4} · makes Either$String$tuple2$St$Int
          let _t0 = == k i  ; Δ{}
          let _t0 = == k n  ; Δ{}
          let _t0 = call copyStr k  ; Δ{} · makes String
          let _t1 = call copyStr x  ; Δ{$bind8129} · makes String
          let _t1 = call infer st1 env a  ; Δ{$bind7647} · makes Either$String$tuple2$St$Int
          let _t1 = call intNode st1  ; Δ{$bind7001} · makes Either$String$tuple2$St$Int
          let _t1 = call intNode st1  ; Δ{$bind8331} · makes Either$String$tuple2$St$Int
          let _t1 = con St store sub2 c  ; Δ{store sub2} · moves{store sub2} · makes St
          let _t1 = rtcall axion_str_cmp k x  ; Δ{}
          let _t1 = tuple _t0 v  ; Δ{_t0} · moves{_t0} · makes heap
          let _t2 = == _t1 0  ; Δ{}
          let _t2 = call copyEnv rest  ; Δ{_t1} · makes List$tuple2$String$Int
          let _t2 = tuple _t1 t1  ; Δ{$bind8129 _t1} · moves{_t1} · makes heap
          let _t3 = call copyEnv env  ; Δ{$bind8129 _t2} · makes List$tuple2$String$Int
          let _t4 = con Cons _t2 _t3  ; Δ{$bind8129 _t2 _t3} · moves{_t2 _t3} · makes List$tuple2$String$Int
          let _t6 = call p3  ; Δ{} · makes Expr
          let _t7 = call typeOf _t6  ; Δ{_t6} · makes String
          let _t8 = putStrLn _t7  ; Δ{_t7}
          ret _d1000000  ; Δ{$bind8129 _d1000000} · moves{_d1000000}
          ret call unify store s1 a2 b2  ; Δ{s1} · moves{s1} · makes Either$String$List$tuple2$Int$Int
          ret case $bind7428 of
          ret case _t1 of
          ret case _t1 of
          ret case _t1 of
          ret case _t8 of
          ret case st of
          ret con Cons _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes List$tuple2$String$Int
          ret con Left $bindErr  ; Δ{$bindErr _t0} · moves{$bindErr} · makes Either$String$tuple2$St$Int
          ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$List$tuple2$Int$Int
          ret con Left m  ; Δ{m} · moves{m} · makes Either$String$St
          ret con Right _t1  ; Δ{_t1} · moves{_t1} · makes Either$String$St
          ret if _t0 then
          ret if _t0 then
          ret if _t2 then
        (k, nd) ->
        (k, v) ->
        (k, v) ->
        (k, v) ->
        (st, i) ->
        (st1, t1) ->
        (st1, ta) ->
        (st1, tc) ->
        (st1, tf) ->
        Left $bindErr ->
        Left $bindErr ->
        Left m ->
        Right $bind7428 ->
        Right s1 ->
        Right sub2 ->
        _ ->
        drop _t0 : Node
        drop _t0 : Node
        ret 1  ; Δ{}
        ret call occurs store sub v b  ; Δ{}
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0
      drop _t0 : Node
      drop _t0 : Node
      drop _t0 : Node
      drop _t0 : tuple2$St$Int skip{0}
      drop _t1 : String
      drop _t2 : String
      drop _t3 : Expr
      drop _t3 : String
      drop _t4
      drop _t4
      drop _t4 : List$tuple2$String$Int
      drop _t4 : String
      drop _t4 : String
      drop _t5 : String
      drop _t6 : String
      drop m : String
      drop st
      drop st
      drop st
      drop st
      drop st : St
      drop sub : List$tuple2$Int$Int
      drop sub : List$tuple2$Int$Int
      drop sub : List$tuple2$Int$Int
      else
      let _d1000000 = rtcall axion_strcat "t" _t1  ; Δ{_t1} · makes String
      let _d1000000 = rtcall axion_strcat "type error: " m  ; Δ{m} · makes String
      let _d1000001 = rtcall axion_strcat "(" _t6  ; Δ{_t6} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple2$Int$Int _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple2$Int$Node _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple2$String$Int _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_tuple2$Int$Int _dd2  ; Δ{}
      let _dd3 = call axion_drop_tuple2$Int$Node _dd2  ; Δ{}
      let _dd3 = call axion_drop_tuple2$String$Int _dd2  ; Δ{}
      let _t0 = call unify store sub a b  ; Δ{store sub} · moves{sub} · makes Either$String$List$tuple2$Int$Int
      let _t0 = con NInt  ; Δ{} · makes Node
      let _t0 = con NVar c  ; Δ{store sub} · makes Node
      let _t0 = rtcall axion_strcat "unbound variable: " x  ; Δ{} · makes String
      let _t0 = tuple c nd  ; Δ{store sub} · makes heap
      let _t1 = call addNode st _t0  ; Δ{_t0} · moves{_t0} · makes tuple2$St$Int
      let _t1 = call copyStr x  ; Δ{_t0} · makes String
      let _t1 = call occurs store sub v a  ; Δ{_t0}
      let _t1 = call unify store sub a1 b1  ; Δ{} · makes Either$String$List$tuple2$Int$Int
      let _t1 = con Cons _t0 store  ; Δ{_t0 store sub} · moves{_t0 store} · makes List$tuple2$Int$Node
      let _t1 = showInt v  ; Δ{} · makes String
      let _t1 = tuple c _t0  ; Δ{_t0 store sub} · moves{_t0} · makes heap
      let _t1 = tuple st i  ; Δ{i} · moves{i} · makes heap
      let _t1 = tuple v a  ; Δ{} · makes heap
      let _t2 = + c 1  ; Δ{_t1 sub}
      let _t2 = call showType store sub a  ; Δ{} · makes String
      let _t2 = con Cons _t1 store  ; Δ{_t1 store sub} · moves{_t1 store} · makes List$tuple2$Int$Node
      let _t2 = con Cons _t1 sub  ; Δ{_t1} · moves{_t1} · makes List$tuple2$Int$Int
      let _t2 = tuple _t1 tx  ; Δ{_t0 _t1} · moves{_t1} · makes heap
      let _t3 = + c 1  ; Δ{_t2 sub}
      let _t3 = call copyEnv env  ; Δ{_t0 _t2} · makes List$tuple2$String$Int
      let _t3 = call p2  ; Δ{} · makes Expr
      let _t3 = call showType store sub b  ; Δ{_t2} · makes String
      let _t3 = con St _t1 sub _t2  ; Δ{_t1 sub} · moves{_t1 sub} · makes St
      let _t4 = call typeOf _t3  ; Δ{_t3} · makes String
      let _t4 = con Cons _t2 _t3  ; Δ{_t0 _t2 _t3} · moves{_t2 _t3} · makes List$tuple2$String$Int
      let _t4 = con St _t2 sub _t3  ; Δ{_t2 sub} · moves{_t2 sub} · makes St
      let _t4 = rtcall axion_strcat _t3 ")"  ; Δ{_t2 _t3} · makes String
      let _t5 = call infer st1 _t4 body  ; Δ{_t0 _t4} · makes Either$String$tuple2$St$Int
      let _t5 = putStrLn _t4  ; Δ{_t4}
      let _t5 = rtcall axion_strcat " -> " _t4  ; Δ{_t2 _t4} · makes String
      let _t6 = rtcall axion_strcat _t2 _t5  ; Δ{_t2 _t5} · makes String
      ret "Int"  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret == v w  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret call bindV store sub v afun  ; Δ{} · makes Either$String$List$tuple2$Int$Int
      ret call bindV store sub v b  ; Δ{} · makes Either$String$List$tuple2$Int$Int
      ret call inferApp st env f a  ; Δ{} · makes Either$String$tuple2$St$Int
      ret call inferArith st env a b  ; Δ{} · makes Either$String$tuple2$St$Int
      ret call inferArith st env a b  ; Δ{} · makes Either$String$tuple2$St$Int
      ret call inferArith st env a b  ; Δ{} · makes Either$String$tuple2$St$Int
      ret call inferIf st env c t el  ; Δ{} · makes Either$String$tuple2$St$Int
      ret call inferLam st env x body  ; Δ{} · makes Either$String$tuple2$St$Int
      ret call inferLet st env x rhs body  ; Δ{} · makes Either$String$tuple2$St$Int
      ret call inferVar st env x  ; Δ{} · makes Either$String$tuple2$St$Int
      ret call resolve store sub j  ; Δ{j} · moves{j}
      ret call resolveVar store sub i v  ; Δ{}
      ret call unifyFun store sub a a1 a2 b  ; Δ{} · makes Either$String$List$tuple2$Int$Int
      ret call unifyInt store sub a b  ; Δ{} · makes Either$String$List$tuple2$Int$Int
      ret case $bind7001 of
      ret case $bind7647 of
      ret case $bind8129 of
      ret case $bind8331 of
      ret case _t0 of
      ret case _t1 of
      ret case _t5 of
      ret case _t5 of
      ret case kv of
      ret case kv of
      ret case kv of
      ret case kv of
      ret case res of
      ret con Left "cannot unify Int with a function type"  ; Δ{} · makes Either$String$List$tuple2$Int$Int
      ret con Left "cannot unify a function type with Int"  ; Δ{} · makes Either$String$List$tuple2$Int$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple2$St$Int
      ret con Left _t0  ; Δ{_t0} · moves{_t0} · makes Either$String$Int
      ret con Left m  ; Δ{m} · moves{m} · makes Either$String$tuple2$St$Int
      ret con NFun a b  ; Δ{} · makes Node
      ret con NInt  ; Δ{} · makes Node
      ret con NInt  ; Δ{} · makes Node
      ret con NVar v  ; Δ{} · makes Node
      ret con Nil  ; Δ{} · makes List$tuple2$String$Int
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret con Right _t1  ; Δ{_t1} · moves{_t1} · makes Either$String$tuple2$St$Int
      ret con Right _t1  ; Δ{_t1} · moves{_t1} · makes Either$String$tuple2$St$Int
      ret con Right _t2  ; Δ{_t2} · moves{_t2} · makes Either$String$List$tuple2$Int$Int
      ret con Right sub  ; Δ{} · makes Either$String$List$tuple2$Int$Int
      ret i  ; Δ{}
      ret i  ; Δ{}
      ret i  ; Δ{}
      ret if _t1 then
      ret store  ; Δ{store} · moves{store}
      ret tuple _t3 c  ; Δ{_t3} · moves{_t3} · makes heap
      ret tuple _t4 c  ; Δ{_t4} · moves{_t4} · makes heap
    (st1, tx) ->
    Add a b ->
    App f a ->
    Cons kv rest ->
    Cons kv rest ->
    Cons kv rest ->
    Cons kv rest ->
    Eq a b ->
    If c t el ->
    Just j ->
    Lam x body ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left m ->
    Left m ->
    Let x rhs body ->
    Mul a b ->
    NFun a b ->
    NFun a b ->
    NFun a b ->
    NFun a b ->
    NFun a1 a2 ->
    NFun b1 b2 ->
    NFun x y ->
    NInt ->
    NInt ->
    NInt ->
    NInt ->
    NInt ->
    NInt ->
    NInt ->
    NVar v ->
    NVar v ->
    NVar v ->
    NVar v ->
    NVar v ->
    NVar v ->
    NVar w ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nothing ->
    Num n ->
    Right $bind7001 ->
    Right $bind7647 ->
    Right $bind8129 ->
    Right $bind8331 ->
    Right i ->
    Right res ->
    St store sub c ->
    St store sub c ->
    St store sub c ->
    St store sub c ->
    Var x ->
    _ ->
    drop sub : List$tuple2$Int$Int
    else
    else
    else
    else
    let _dd0 = loadraw _p+24  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = call axion_drop_Expr _dd0  ; Δ{}
    let _dd1 = call axion_drop_List$tuple2$Int$Int _dd0  ; Δ{}
    let _dd1 = call axion_drop_St _dd0  ; Δ{}
    let _dd1 = call axion_drop_tuple2$St$Int _dd0  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
    let _dd10 = loadraw _p+16  ; Δ{}
    let _dd11 = call axion_drop_Expr _dd10  ; Δ{}
    let _dd12 = loadraw _p+8  ; Δ{}
    let _dd13 = rtcall axion_str_drop _dd12  ; Δ{}
    let _dd16 = loadraw _p+16  ; Δ{}
    let _dd17 = call axion_drop_Expr _dd16  ; Δ{}
    let _dd18 = loadraw _p+8  ; Δ{}
    let _dd19 = call axion_drop_Expr _dd18  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = loadraw _p+16  ; Δ{}
    let _dd22 = loadraw _p+16  ; Δ{}
    let _dd23 = call axion_drop_Expr _dd22  ; Δ{}
    let _dd24 = loadraw _p+8  ; Δ{}
    let _dd25 = rtcall axion_str_drop _dd24  ; Δ{}
    let _dd28 = loadraw _p+16  ; Δ{}
    let _dd29 = call axion_drop_Expr _dd28  ; Δ{}
    let _dd3 = call axion_drop_Expr _dd2  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd30 = loadraw _p+8  ; Δ{}
    let _dd31 = call axion_drop_Expr _dd30  ; Δ{}
    let _dd34 = loadraw _p+16  ; Δ{}
    let _dd35 = call axion_drop_Expr _dd34  ; Δ{}
    let _dd36 = loadraw _p+8  ; Δ{}
    let _dd37 = call axion_drop_Expr _dd36  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = == _tag 1  ; Δ{}
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd40 = loadraw _p+16  ; Δ{}
    let _dd41 = call axion_drop_Expr _dd40  ; Δ{}
    let _dd42 = loadraw _p+8  ; Δ{}
    let _dd43 = call axion_drop_Expr _dd42  ; Δ{}
    let _dd46 = loadraw _p+8  ; Δ{}
    let _dd47 = rtcall axion_str_drop _dd46  ; Δ{}
    let _dd5 = call axion_drop_Expr _dd4  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dd5 = rtcall axion_str_drop _dd4  ; Δ{}
    let _dd5 = rtcall axion_str_drop _dd4  ; Δ{}
    let _dd5 = rtcall axion_str_drop _dd4  ; Δ{}
    let _dd8 = loadraw _p+24  ; Δ{}
    let _dd9 = call axion_drop_Expr _dd8  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = tuple v t  ; Δ{} · makes heap
    let _t2 = con Cons _t1 sub  ; Δ{_t1} · moves{_t1} · makes List$tuple2$Int$Int
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
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
    ret con Left "occurs check: infinite type"  ; Δ{} · makes Either$String$List$tuple2$Int$Int
    ret con Right _t2  ; Δ{_t2} · moves{_t2} · makes Either$String$List$tuple2$Int$Int
  ; Δ{$bind7001 $bind7001$1 $bind7001$2 $bind7001$3 _t5}
  ; Δ{$bind7001 $bind7001$1 $bind7001$2 $bind7001$3}
  ; Δ{$bind7001 $bind7001$1 $bind7001$2 _t4}
  ; Δ{$bind7001 $bind7001$1 $bind7001$2}
  ; Δ{$bind7001 $bind7001$1 _t2}
  ; Δ{$bind7001 $bind7001$1 _t3}
  ; Δ{$bind7001 $bind7001$1}
  ; Δ{$bind7001 _t1}
  ; Δ{$bind7001}
  ; Δ{$bind7428 _t0}
  ; Δ{$bind7647 $bind7647$1 $bind7647$2 $bind7647$3 _t4}
  ; Δ{$bind7647 $bind7647$1 $bind7647$2 $bind7647$3}
  ; Δ{$bind7647 $bind7647$1 $bind7647$2 _t3}
  ; Δ{$bind7647 $bind7647$1 $bind7647$2}
  ; Δ{$bind7647 $bind7647$1 _t2}
  ; Δ{$bind7647 $bind7647$1}
  ; Δ{$bind7647 _t1}
  ; Δ{$bind7647}
  ; Δ{$bind8129}
  ; Δ{$bind8331 $bind8331$1 $bind8331$2 $bind8331$3 _t5}
  ; Δ{$bind8331 $bind8331$1 $bind8331$2 $bind8331$3}
  ; Δ{$bind8331 $bind8331$1 $bind8331$2 _t4}
  ; Δ{$bind8331 $bind8331$1 $bind8331$2}
  ; Δ{$bind8331 $bind8331$1 _t2}
  ; Δ{$bind8331 $bind8331$1 _t3}
  ; Δ{$bind8331 $bind8331$1}
  ; Δ{$bind8331 _t1}
  ; Δ{$bind8331}
  ; Δ{_t0 _t5}
  ; Δ{_t0 store}
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
  ; Δ{_t1}
  ; Δ{_t4}
  ; Δ{res}
  ; Δ{res}
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
  drop _t0 : Expr
  drop _t1 : String
  drop _t3 : List$tuple2$String$Int
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
  let _dd0 = band _p 1  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_List$tuple2$Int$Int _dd0  ; Δ{}
  let _dd1 = call axion_drop_St _dd0  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd1 = rtcall axion_free _dd0  ; Δ{}
  let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
  let _dd14 = == _tag 7  ; Δ{}
  let _dd15 = if _dd14 then
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd20 = == _tag 6  ; Δ{}
  let _dd21 = if _dd20 then
  let _dd26 = == _tag 5  ; Δ{}
  let _dd27 = if _dd26 then
  let _dd3 = call axion_drop_List$tuple2$Int$Node _dd2  ; Δ{}
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd32 = == _tag 4  ; Δ{}
  let _dd33 = if _dd32 then
  let _dd38 = == _tag 3  ; Δ{}
  let _dd39 = if _dd38 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd44 = == _tag 2  ; Δ{}
  let _dd45 = if _dd44 then
  let _dd48 = == _tag 1  ; Δ{}
  let _dd49 = if _dd48 then
  let _dd5 = if _dd4 then
  let _dd6 = == _tag 0  ; Δ{}
  let _dd6 = == _tag 0  ; Δ{}
  let _dd6 = == _tag 0  ; Δ{}
  let _dd6 = == _tag 8  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dd7 = if _dd6 then
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _dfree = rtcall axion_free _p  ; Δ{}
  let _t0 = call envLook x env  ; Δ{} · makes Either$String$Int
  let _t0 = call freshVar st  ; Δ{} · makes tuple2$St$Int
  let _t0 = call freshVar st  ; Δ{} · makes tuple2$St$Int
  let _t0 = call getNode store a  ; Δ{} · makes Node
  let _t0 = call getNode store b  ; Δ{} · makes Node
  let _t0 = call getNode store b  ; Δ{} · makes Node
  let _t0 = call getNode store i  ; Δ{} · makes Node
  let _t0 = call getNode store r  ; Δ{} · makes Node
  let _t0 = call getNode store r  ; Δ{} · makes Node
  let _t0 = call infer st env a  ; Δ{} · makes Either$String$tuple2$St$Int
  let _t0 = call infer st env c  ; Δ{} · makes Either$String$tuple2$St$Int
  let _t0 = call infer st env f  ; Δ{} · makes Either$String$tuple2$St$Int
  let _t0 = call infer st env rhs  ; Δ{} · makes Either$String$tuple2$St$Int
  let _t0 = call lookupI v sub  ; Δ{} · makes Maybe$Int
  let _t0 = call occurs store sub v t  ; Δ{}
  let _t0 = call p1  ; Δ{} · makes Expr
  let _t0 = call resolve store sub a  ; Δ{}
  let _t0 = con NFun a b  ; Δ{} · makes Node
  let _t0 = con NInt  ; Δ{} · makes Node
  let _t0 = con Nil  ; Δ{} · makes List$tuple2$Int$Node
  let _t0 = con Num 1  ; Δ{} · makes Expr
  let _t0 = con Num 1  ; Δ{} · makes Expr
  let _t0 = con Num 1  ; Δ{} · makes Expr
  let _t0 = con Var "f"  ; Δ{} · makes Expr
  let _t0 = con Var "x"  ; Δ{} · makes Expr
  let _t0 = con Var "x"  ; Δ{} · makes Expr
  let _t1 = call addNode st _t0  ; Δ{_t0} · moves{_t0} · makes tuple2$St$Int
  let _t1 = call addNode st _t0  ; Δ{_t0} · moves{_t0} · makes tuple2$St$Int
  let _t1 = call resolve store sub b  ; Δ{}
  let _t1 = call typeOf _t0  ; Δ{_t0} · makes String
  let _t1 = con Nil  ; Δ{_t0} · makes List$tuple2$Int$Int
  let _t1 = con Num 1  ; Δ{_t0} · makes Expr
  let _t1 = con Num 2  ; Δ{_t0} · makes Expr
  let _t1 = con Var "f"  ; Δ{_t0} · makes Expr
  let _t1 = con Var "x"  ; Δ{_t0} · makes Expr
  let _t1 = con Var "y"  ; Δ{_t0} · makes Expr
  let _t10 = con Mul _t8 _t9  ; Δ{_t6 _t7 _t8 _t9} · moves{_t8 _t9} · makes Expr
  let _t11 = con Lam "n" _t10  ; Δ{_t10 _t6 _t7} · moves{_t10} · makes Expr
  let _t12 = con App _t7 _t11  ; Δ{_t11 _t6 _t7} · moves{_t11 _t7} · makes Expr
  let _t13 = con Num 3  ; Δ{_t12 _t6} · makes Expr
  let _t14 = con App _t12 _t13  ; Δ{_t12 _t13 _t6} · moves{_t12 _t13} · makes Expr
  let _t2 = con Add _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes Expr
  let _t2 = con Eq _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes Expr
  let _t2 = con Lam "x" _t1  ; Δ{_t0 _t1} · moves{_t1} · makes Expr
  let _t2 = con St _t0 _t1 0  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes St
  let _t2 = con Var "x"  ; Δ{_t0 _t1} · makes Expr
  let _t2 = putStrLn _t1  ; Δ{_t1}
  let _t3 = con App _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t1 _t2} · makes Expr
  let _t3 = con Lam "y" _t2  ; Δ{_t2} · moves{_t2} · makes Expr
  let _t3 = con Nil  ; Δ{_t2} · makes List$tuple2$String$Int
  let _t3 = con Num 10  ; Δ{_t2} · makes Expr
  let _t4 = call infer _t2 _t3 e  ; Δ{_t2 _t3} · moves{_t2} · makes Either$String$tuple2$St$Int
  let _t4 = con App _t0 _t3  ; Δ{_t0 _t3} · moves{_t0 _t3} · makes Expr
  let _t4 = con Num 20  ; Δ{_t2 _t3} · makes Expr
  let _t5 = con Lam "x" _t4  ; Δ{_t4} · moves{_t4} · makes Expr
  let _t6 = con Lam "f" _t5  ; Δ{_t5} · moves{_t5} · makes Expr
  let _t7 = con Var "twice"  ; Δ{_t6} · makes Expr
  let _t8 = con Var "n"  ; Δ{_t6 _t7} · makes Expr
  let _t9 = con Var "n"  ; Δ{_t6 _t7 _t8} · makes Expr
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let r = call resolve store sub i  ; Δ{}
  let r = call resolve store sub i  ; Δ{}
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
  ret call unifyR store sub _t0 _t1  ; Δ{} · makes Either$String$List$tuple2$Int$Int
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t2 of
  ret case _t4 of
  ret case e of
  ret case env of
  ret case env of
  ret case n of
  ret case st of
  ret case st of
  ret case st of
  ret case st of
  ret case store of
  ret case sub of
  ret con Add _t0 _t2  ; Δ{_t0 _t2} · moves{_t0 _t2} · makes Expr
  ret con App _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes Expr
  ret con If _t2 _t3 _t4  ; Δ{_t2 _t3 _t4} · moves{_t2 _t3 _t4} · makes Expr
  ret con Lam "x" _t0  ; Δ{_t0} · moves{_t0} · makes Expr
  ret con Lam "x" _t3  ; Δ{_t3} · moves{_t3} · makes Expr
  ret con Let "twice" _t6 _t14  ; Δ{_t14 _t6} · moves{_t14 _t6} · makes Expr
  ret con Right _t0  ; Δ{_t0} · moves{_t0} · makes Either$String$tuple2$St$Int
  ret con Right _t1  ; Δ{_t1} · moves{_t1} · makes Either$String$tuple2$St$Int
  ret con Right _t1  ; Δ{_t1} · moves{_t1} · makes Either$String$tuple2$St$Int
  ret if _t0 then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_strcat s ""  ; Δ{} · makes String
addNode st nd  =
axion_drop_Array _p  =
axion_drop_Either$String _p  =
axion_drop_Either$String$Int _p  =
axion_drop_Either$String$List$tuple2$Int$Int _p  =
axion_drop_Either$String$St _p  =
axion_drop_Either$String$tuple2$St$Int _p  =
axion_drop_Expr _p  =
axion_drop_List _p  =
axion_drop_List$tuple2$Int$Int _p  =
axion_drop_List$tuple2$Int$Node _p  =
axion_drop_List$tuple2$String$Int _p  =
axion_drop_Maybe$Int _p  =
axion_drop_St _p  =
axion_drop_tuple2$Int$Int _p  =
axion_drop_tuple2$Int$Node _p  =
axion_drop_tuple2$St$Int _p  =
axion_drop_tuple2$String$Int _p  =
bindV store sub v t  =
copyEnv env  =
copyNode n  =
copyStr s  =
envLook x env  =
freshVar st  =
freshVarE st  =
funNode st a b  =
getNode store i  =
infer st env e  =
inferApp st env f a  =
inferArith st env a b  =
inferIf st env c t el  =
inferLam st env x body  =
inferLet st env x rhs body  =
inferVar st env x  =
intNode st  =
lookupI n sub  =
main  =
occurs store sub v i  =
p1  =
p2  =
p3  =
p4  =
p5  =
p6  =
resolve store sub i  =
resolveVar store sub i v  =
showType store sub i  =
stStore st  =
stUnify st a b  =
typeOf e  =
unify store sub a b  =
unifyFun store sub afun a1 a2 b  =
unifyInt store sub a b  =
unifyR store sub a b  =
