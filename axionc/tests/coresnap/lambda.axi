
































































































                          drop _t12 : String
                          let _d1000000 = putStrLn _t12  ; Δ{_t12}
                          let _t12 = call run "(1 + 2"  ; Δ{} · makes String
                          ret _d1000000  ; Δ{}
                        _ ->
                      drop _t10 : String
                      let _t10 = call run "nope + 1"  ; Δ{} · makes String
                      let _t11 = putStrLn _t10  ; Δ{_t10}
                      ret case _t11 of
                    _ ->
                  drop _t3
                  drop _t3
                  drop _t8 : String
                  let _t4 = call applyOp op na nb  ; Δ{na nb}
                  let _t5 = con IntV _t4  ; Δ{na nb} · makes Value
                  let _t8 = call run "let x = 5 in x * x"  ; Δ{} · makes String
                  let _t9 = putStrLn _t8  ; Δ{_t8}
                  ret case _t9 of
                  ret con Left $bindErr  ; Δ{$bindErr na} · moves{$bindErr} · makes Either$String$Value
                  ret con Right _t5  ; Δ{_t5 na nb} · moves{_t5} · makes Either$String$Value
                Left $bindErr ->
                Right nb ->
                _ ->
              drop _t2
              drop _t2
              drop _t6 : String
              drop vb : Value
              let _t3 = call asInt vb  ; Δ{na vb} · makes Either$String$Int
              let _t6 = call run "if 1 < 2 then 10 else 20"  ; Δ{} · makes String
              let _t7 = putStrLn _t6  ; Δ{_t6}
              ret case _t3 of
              ret case _t7 of
              ret con Left $bindErr  ; Δ{$bindErr na} · moves{$bindErr} · makes Either$String$Value
            Left $bindErr ->
            Right vb ->
            _ ->
            let _t3 = call copyValue val  ; Δ{} · makes Value
            ret 0  ; Δ{}
            ret 0  ; Δ{}
            ret 1  ; Δ{}
            ret 1  ; Δ{}
            ret call envLookup k rest  ; Δ{} · makes Either$String$Value
            ret call eval env el  ; Δ{nc} · makes Either$String$Value
            ret call eval env t  ; Δ{nc} · makes Either$String$Value
            ret con Left "trailing tokens after expression"  ; Δ{$bind14755} · makes Either$String$Expr
            ret con Right _t3  ; Δ{_t3} · moves{_t3} · makes Either$String$Value
            ret con Right e  ; Δ{$bind14755} · makes Either$String$Expr
          drop $bind10005 : tuple$Expr$Int skip{0}
          drop $bind10190 : tuple$Expr$Int skip{0}
          drop $bind10481 : tuple$Expr$Int skip{0}
          drop $bind11899 : tuple$Expr$Int skip{0}
          drop $bind12776 : tuple$Expr$Int skip{0}
          drop $bind13356 : tuple$Expr$Int skip{0}
          drop $bind13717 : tuple$Expr$Int skip{0}
          drop $bind13907 : tuple$Expr$Int skip{0}
          drop $bind14226 : tuple$Expr$Int skip{0}
          drop $bind14574 : tuple$Expr$Int skip{0}
          drop $bind14755 : tuple$Expr$Int skip{0}
          drop $bind8418 : tuple$Expr$Int skip{0}
          drop $bind8802 : tuple$Expr$Int skip{0}
          drop $bind9148 : tuple$Expr$Int skip{0}
          drop $bind9528 : tuple$Expr$Int skip{0}
          drop $bind9690 : tuple$Expr$Int skip{0}
          drop _t0
          drop _t0
          drop _t1
          drop _t1
          drop _t1
          drop _t1
          drop _t2 : List$tuple$String$Value
          drop _t4 : String
          drop body : Expr
          drop body : Expr
          drop cenv : List$tuple$String$Value
          drop p : String
          else
          else
          else
          else
          else
          let _d1000000 = call eval _t2 body  ; Δ{_t2 body} · makes Either$String$Value
          let _t0 = call copyStr k  ; Δ{} · makes String
          let _t1 = call copyValue val  ; Δ{_t0} · makes Value
          let _t1 = call kindAt toks p  ; Δ{$bind14755}
          let _t1 = con App l r  ; Δ{$bind10481} · makes Expr
          let _t1 = con If c tb eb  ; Δ{$bind14574} · makes Expr
          let _t1 = con Lam nm body  ; Δ{$bind12776} · makes Expr
          let _t1 = con Let nm rhs body  ; Δ{$bind13717} · makes Expr
          let _t1 = rtcall axion_str_cmp key k  ; Δ{}
          let _t1 = tuple p arg  ; Δ{arg body cenv p} · moves{arg p} · makes heap
          let _t11 = - j i  ; Δ{}
          let _t12 = rtcall axion_substr i _t11 s  ; Δ{} · makes String
          let _t13 = con TName _t12  ; Δ{_t12} · moves{_t12} · makes Tok
          let _t14 = con Cons _t13 acc  ; Δ{_t13} · moves{_t13} · makes List$Tok
          let _t2 = == _t1 0  ; Δ{}
          let _t2 = == _t1 3  ; Δ{$bind14755}
          let _t2 = == nc 0  ; Δ{nc}
          let _t2 = call eval env b  ; Δ{na} · makes Either$String$Value
          let _t2 = call mkBin op l r  ; Δ{$bind8802} · makes Expr
          let _t2 = call mkBin op l r  ; Δ{$bind9528} · makes Expr
          let _t2 = con Cons _t1 cenv  ; Δ{_t1 body cenv} · moves{_t1 cenv} · makes List$tuple$String$Value
          let _t2 = con Mul l r  ; Δ{$bind10005} · makes Expr
          let _t2 = tuple _t0 _t1  ; Δ{_t0 _t1} · moves{_t0 _t1} · makes heap
          let _t2 = tuple _t1 p1  ; Δ{$bind12776 _t1} · moves{_t1} · makes heap
          let _t2 = tuple _t1 p1  ; Δ{$bind13717 _t1} · moves{_t1} · makes heap
          let _t2 = tuple _t1 p1  ; Δ{$bind14574 _t1} · moves{_t1} · makes heap
          let _t3 = call copyEnv rest  ; Δ{_t2} · makes List$tuple$String$Value
          let _t3 = tuple _t2 p2  ; Δ{$bind8802 _t2} · moves{_t2} · makes heap
          let _t4 = == x y  ; Δ{}
          let _t4 = call run "let twice = \\f -> \\x -> f (f x) in twice (\\n -> n * n) 3"  ; Δ{} · makes String
          let _t5 = < x y  ; Δ{}
          let _t5 = putStrLn _t4  ; Δ{_t4}
          let _t8 = rtcall axion_str_cmp x "else"  ; Δ{}
          let j = call scanWhile s i 1  ; Δ{}
          ret 1  ; Δ{}
          ret == _t8 0  ; Δ{}
          ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
          ret call expectWord toks ")" e p1  ; Δ{$bind11899} · makes Either$String$tuple$Expr$Int
          ret call pAddLoop toks _t2 p2  ; Δ{$bind9528 _t2} · moves{_t2} · makes Either$String$tuple$Expr$Int
          ret call pAddLoop toks l p1  ; Δ{$bind9148} · makes Either$String$tuple$Expr$Int
          ret call pAppLoop toks _t1 p2  ; Δ{$bind10481 _t1} · moves{_t1} · makes Either$String$tuple$Expr$Int
          ret call pAppLoop toks l p1  ; Δ{$bind10190} · makes Either$String$tuple$Expr$Int
          ret call pCmpAfter toks l p1  ; Δ{$bind8418} · makes Either$String$tuple$Expr$Int
          ret call pIfElse toks c tb p1  ; Δ{$bind14226} · makes Either$String$tuple$Expr$Int
          ret call pIfThen toks c p1  ; Δ{$bind13907} · makes Either$String$tuple$Expr$Int
          ret call pLetIn toks nm rhs p1  ; Δ{$bind13356} · makes Either$String$tuple$Expr$Int
          ret call pMulLoop toks _t2 p2  ; Δ{$bind10005 _t2} · moves{_t2} · makes Either$String$tuple$Expr$Int
          ret call pMulLoop toks l p1  ; Δ{$bind9690} · makes Either$String$tuple$Expr$Int
          ret call tokLoop s j _t14  ; Δ{_t14} · moves{_t14} · makes List$Tok
          ret call tokSym s i c acc  ; Δ{} · makes List$Tok
          ret case _t2 of
          ret case _t5 of
          ret con Cons _t2 _t3  ; Δ{_t2 _t3} · moves{_t2 _t3} · makes List$tuple$String$Value
          ret con Eq l r  ; Δ{} · makes Expr
          ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$Value
          ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$Value
          ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$Value
          ret con Lt l r  ; Δ{} · makes Expr
          ret con Right _t2  ; Δ{$bind12776 _t2} · moves{_t2} · makes Either$String$tuple$Expr$Int
          ret con Right _t2  ; Δ{$bind13717 _t2} · moves{_t2} · makes Either$String$tuple$Expr$Int
          ret con Right _t2  ; Δ{$bind14574 _t2} · moves{_t2} · makes Either$String$tuple$Expr$Int
          ret con Right _t3  ; Δ{$bind8802 _t3} · moves{_t3} · makes Either$String$tuple$Expr$Int
          ret if _t2 then
          ret if _t2 then
          ret if _t2 then
          ret if _t4 then
          ret if _t5 then
        (body, p1) ->
        (body, p1) ->
        (c, p1) ->
        (e, p) ->
        (e, p1) ->
        (eb, p1) ->
        (k, val) ->
        (key, val) ->
        (l, p1) ->
        (l, p1) ->
        (l, p1) ->
        (l, p1) ->
        (r, p2) ->
        (r, p2) ->
        (r, p2) ->
        (r, p2) ->
        (rhs, p1) ->
        (tb, p1) ->
        Left $bindErr ->
        Left $bindErr ->
        Left $bindErr ->
        Right arg ->
        Right na ->
        Right nc ->
        _ ->
        drop _t5 : String
        drop _t6 : String
        else
        else
        else
        else
        let _t1 = - i 1  ; Δ{}
        let _t1 = - i 1  ; Δ{}
        let _t1 = - i 1  ; Δ{}
        let _t10 = call isAlphaCh c  ; Δ{}
        let _t15 = + i 1  ; Δ{}
        let _t16 = rtcall axion_str_at _t15 s  ; Δ{}
        let _t3 = == op 3  ; Δ{}
        let _t3 = == op 3  ; Δ{}
        let _t5 = - j i  ; Δ{}
        let _t5 = call wordAt toks p  ; Δ{} · makes String
        let _t6 = rtcall axion_str_cmp _t5 "("  ; Δ{_t5}
        let _t6 = rtcall axion_str_cmp x "then"  ; Δ{}
        let _t6 = rtcall axion_substr i _t5 s  ; Δ{} · makes String
        let _t7 = == _t6 0  ; Δ{}
        let _t7 = call readIntOr _t6  ; Δ{_t6}
        let _t8 = con TNum _t7  ; Δ{} · makes Tok
        let _t9 = con Cons _t8 acc  ; Δ{_t8} · moves{_t8} · makes List$Tok
        let j = call scanWhile s i 0  ; Δ{}
        ret * x y  ; Δ{}
        ret 0  ; Δ{}
        ret 0  ; Δ{}
        ret 1  ; Δ{}
        ret 1  ; Δ{}
        ret == _t16 61  ; Δ{}
        ret == _t6 0  ; Δ{}
        ret == c 13  ; Δ{}
        ret call kindAt rest _t1  ; Δ{}
        ret call numAt rest _t1  ; Δ{}
        ret call pAtomSym toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
        ret call tokKind t  ; Δ{}
        ret call tokLoop s j _t9  ; Δ{_t9} · moves{_t9} · makes List$Tok
        ret call tokNum t  ; Δ{}
        ret call tokWord t  ; Δ{} · makes String
        ret call wordAt rest _t1  ; Δ{} · makes String
        ret con Left "unexpected end of input"  ; Δ{} · makes Either$String$tuple$Expr$Int
        ret con Mul l r  ; Δ{} · makes Expr
        ret if _t10 then
        ret if _t3 then
        ret if _t3 then
        ret if _t7 then
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
      drop _t1
      drop _t1
      drop _t1
      drop _t1
      drop _t1
      drop _t1
      drop _t1
      drop _t1
      drop _t2 : String
      drop _t2 : String
      drop _t4 : List$tuple$String$Value
      drop _t8 : String
      drop c : Expr
      drop c : Expr
      drop e : Expr
      drop fv
      drop fv
      drop l : Expr
      drop l : Expr
      drop l : Expr
      drop l : Expr
      drop m
      drop m
      drop msg : String
      drop msg : String
      drop rhs : Expr
      drop tb : Expr
      drop ts
      drop ts
      drop v : Value
      drop va : Value
      drop vc : Value
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
      let _d1000000 = call eval _t4 body  ; Δ{_t4} · makes Either$String$Value
      let _d1000000 = rtcall axion_strcat "eval error: " msg  ; Δ{msg} · makes String
      let _d1000000 = rtcall axion_strcat "parse error: " msg  ; Δ{msg} · makes String
      let _d1000001 = call runEval e  ; Δ{e} · makes String
      let _d1000001 = call showValue v  ; Δ{v} · makes String
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Tok _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$tuple$String$Value _dd0  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd2 = loadraw _p+8  ; Δ{}
      let _dd3 = call axion_drop_Tok _dd2  ; Δ{}
      let _dd3 = call axion_drop_tuple$String$Value _dd2  ; Δ{}
      let _t0 = == i 0  ; Δ{}
      let _t0 = == i 0  ; Δ{}
      let _t0 = == i 0  ; Δ{}
      let _t0 = call copyStr p  ; Δ{} · makes String
      let _t0 = call copyStr x  ; Δ{} · makes String
      let _t0 = call eval env a  ; Δ{body cenv p} · makes Either$String$Value
      let _t0 = con Cons t acc  ; Δ{rest t} · moves{t} · makes List$Tok
      let _t0 = con IntV n  ; Δ{} · makes Value
      let _t0 = rtcall axion_strcat "unbound variable: " k  ; Δ{} · makes String
      let _t1 = call asInt va  ; Δ{va} · makes Either$String$Int
      let _t1 = call asInt vc  ; Δ{vc} · makes Either$String$Int
      let _t1 = call copyExpr a  ; Δ{} · makes Expr
      let _t1 = call copyExpr b  ; Δ{_t0} · makes Expr
      let _t1 = call copyStr p  ; Δ{} · makes String
      let _t1 = call copyStr x  ; Δ{v} · makes String
      let _t10 = + p 1  ; Δ{_t9}
      let _t10 = call copyExpr b  ; Δ{_t9} · makes Expr
      let _t11 = call copyStr x  ; Δ{} · makes String
      let _t11 = tuple _t9 _t10  ; Δ{_t9} · moves{_t9} · makes heap
      let _t12 = + i 1  ; Δ{}
      let _t12 = call copyExpr b  ; Δ{_t11} · makes Expr
      let _t13 = call copyExpr f  ; Δ{} · makes Expr
      let _t13 = rtcall axion_str_len s  ; Δ{}
      let _t14 = < _t12 _t13  ; Δ{}
      let _t14 = call copyExpr a  ; Δ{_t13} · makes Expr
      let _t15 = call copyStr x  ; Δ{} · makes String
      let _t16 = call copyExpr a  ; Δ{_t15} · makes Expr
      let _t17 = call copyExpr b  ; Δ{_t15 _t16} · makes Expr
      let _t18 = + i 2  ; Δ{}
      let _t18 = call copyExpr c  ; Δ{} · makes Expr
      let _t19 = call copyExpr t  ; Δ{_t18} · makes Expr
      let _t19 = rtcall axion_strcat "=" "="  ; Δ{} · makes String
      let _t2 = == c 10  ; Δ{}
      let _t2 = == op 2  ; Δ{}
      let _t2 = == op 2  ; Δ{}
      let _t2 = call copyEnv env  ; Δ{_t0 _t1} · makes List$tuple$String$Value
      let _t2 = call copyExpr b  ; Δ{_t1} · makes Expr
      let _t2 = call copyExpr body  ; Δ{_t1} · makes Expr
      let _t2 = call run "let add = \\x -> \\y -> x + y in add 3 4"  ; Δ{} · makes String
      let _t2 = call wordAt toks p  ; Δ{} · makes String
      let _t2 = tuple _t1 v  ; Δ{_t1 v} · moves{_t1 v} · makes heap
      let _t20 = call copyExpr el  ; Δ{_t18 _t19} · makes Expr
      let _t20 = con TSym _t19  ; Δ{_t19} · moves{_t19} · makes Tok
      let _t21 = con Cons _t20 acc  ; Δ{_t20} · moves{_t20} · makes List$Tok
      let _t22 = + i 1  ; Δ{}
      let _t23 = rtcall axion_chr c  ; Δ{} · makes String
      let _t24 = con TSym _t23  ; Δ{_t23} · moves{_t23} · makes Tok
      let _t25 = con Cons _t24 acc  ; Δ{_t24} · moves{_t24} · makes List$Tok
      let _t3 = + i 1  ; Δ{}
      let _t3 = + i 1  ; Δ{}
      let _t3 = call copyEnv env  ; Δ{_t1 _t2} · makes List$tuple$String$Value
      let _t3 = call copyEnv env  ; Δ{_t2} · makes List$tuple$String$Value
      let _t3 = call copyExpr a  ; Δ{} · makes Expr
      let _t3 = call isKeyword _t2  ; Δ{_t2}
      let _t3 = putStrLn _t2  ; Δ{_t2}
      let _t4 = + i 1  ; Δ{}
      let _t4 = + i 1  ; Δ{}
      let _t4 = == k 2  ; Δ{}
      let _t4 = call copyExpr b  ; Δ{_t3} · makes Expr
      let _t4 = call isDigitCh c  ; Δ{}
      let _t4 = con CloV _t1 _t2 _t3  ; Δ{_t1 _t2 _t3} · moves{_t1 _t2 _t3} · makes Value
      let _t4 = con Cons _t2 _t3  ; Δ{_t2 _t3} · moves{_t2 _t3} · makes List$tuple$String$Value
      let _t4 = rtcall axion_str_cmp x "if"  ; Δ{}
      let _t4 = tuple l p  ; Δ{} · makes heap
      let _t4 = tuple l p  ; Δ{} · makes heap
      let _t5 = * acc 10  ; Δ{}
      let _t5 = == _t4 0  ; Δ{}
      let _t5 = call copyExpr a  ; Δ{} · makes Expr
      let _t5 = rtcall axion_str_at _t4 s  ; Δ{}
      let _t6 = == k 2  ; Δ{}
      let _t6 = call copyExpr b  ; Δ{_t5} · makes Expr
      let _t6 = rtcall axion_str_at i s  ; Δ{}
      let _t7 = + p 1  ; Δ{}
      let _t7 = + p 1  ; Δ{}
      let _t7 = - _t6 48  ; Δ{}
      let _t7 = call copyExpr a  ; Δ{} · makes Expr
      let _t8 = + _t5 _t7  ; Δ{}
      let _t8 = call copyExpr b  ; Δ{_t7} · makes Expr
      let _t8 = call wordAt toks p  ; Δ{} · makes String
      let _t8 = call wordAt toks p  ; Δ{} · makes String
      let _t9 = call copyExpr a  ; Δ{} · makes Expr
      let _t9 = con Var _t8  ; Δ{_t8} · moves{_t8} · makes Expr
      let _t9 = rtcall axion_strcat "unexpected symbol: " _t8  ; Δ{_t8} · makes String
      ret ""  ; Δ{}
      ret ""  ; Δ{}
      ret "<closure>"  ; Δ{}
      ret - x y  ; Δ{}
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
      ret 2  ; Δ{}
      ret 3  ; Δ{}
      ret == _t5 62  ; Δ{}
      ret == c 95  ; Δ{}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret _d1000001  ; Δ{_d1000001} · moves{_d1000001}
      ret acc  ; Δ{}
      ret call <=$Int c 90  ; Δ{}
      ret call applyClo fv env a  ; Δ{fv} · moves{fv} · makes Either$String$Value
      ret call copyStr x  ; Δ{} · makes String
      ret call copyStr x  ; Δ{} · makes String
      ret call envLookup x env  ; Δ{} · makes Either$String$Value
      ret call evalApp env f a  ; Δ{} · makes Either$String$Value
      ret call evalArith env a b 0  ; Δ{} · makes Either$String$Value
      ret call evalArith env a b 1  ; Δ{} · makes Either$String$Value
      ret call evalArith env a b 2  ; Δ{} · makes Either$String$Value
      ret call evalArith env a b 3  ; Δ{} · makes Either$String$Value
      ret call evalArith env a b 4  ; Δ{} · makes Either$String$Value
      ret call evalIf env c t el  ; Δ{} · makes Either$String$Value
      ret call evalLet env x rhs body  ; Δ{} · makes Either$String$Value
      ret call isAlnumCh c  ; Δ{}
      ret call isDigitCh c  ; Δ{}
      ret call not _t3  ; Δ{}
      ret call pAddStep toks 1 l p  ; Δ{} · makes Either$String$tuple$Expr$Int
      ret call pAtomName toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
      ret call pCmpTail toks 4 l p  ; Δ{} · makes Either$String$tuple$Expr$Int
      ret call pIf toks _t7  ; Δ{} · makes Either$String$tuple$Expr$Int
      ret call pLam toks _t7  ; Δ{} · makes Either$String$tuple$Expr$Int
      ret call readIntGo s _t4 _t8  ; Δ{} · makes Maybe$Int
      ret call revToksGo rest _t0  ; Δ{_t0 rest} · moves{_t0 rest} · makes List$Tok
      ret call scanWhile s _t3 kind  ; Δ{}
      ret call tokLoop s _t18 _t21  ; Δ{_t21} · moves{_t21} · makes List$Tok
      ret call tokLoop s _t22 _t25  ; Δ{_t25} · moves{_t25} · makes List$Tok
      ret call tokLoop s _t3 acc  ; Δ{} · makes List$Tok
      ret callclo f x  ; Δ{x} · moves{x}
      ret case $bind10005 of
      ret case $bind10190 of
      ret case $bind10481 of
      ret case $bind11899 of
      ret case $bind12776 of
      ret case $bind13356 of
      ret case $bind13717 of
      ret case $bind13907 of
      ret case $bind14226 of
      ret case $bind14574 of
      ret case $bind14755 of
      ret case $bind8418 of
      ret case $bind8802 of
      ret case $bind9148 of
      ret case $bind9528 of
      ret case $bind9690 of
      ret case _t0 of
      ret case _t1 of
      ret case _t1 of
      ret case _t3 of
      ret case kv of
      ret case kv of
      ret con Add _t1 _t2  ; Δ{_t1 _t2} · moves{_t1 _t2} · makes Expr
      ret con App _t13 _t14  ; Δ{_t13 _t14} · moves{_t13 _t14} · makes Expr
      ret con CloV _t0 _t1 _t2  ; Δ{_t0 _t1 _t2} · moves{_t0 _t1 _t2} · makes Value
      ret con Eq _t7 _t8  ; Δ{_t7 _t8} · moves{_t7 _t8} · makes Expr
      ret con If _t18 _t19 _t20  ; Δ{_t18 _t19 _t20} · moves{_t18 _t19 _t20} · makes Expr
      ret con IntV n  ; Δ{} · makes Value
      ret con Lam _t11 _t12  ; Δ{_t11 _t12} · moves{_t11 _t12} · makes Expr
      ret con Left "cannot apply a number as a function"  ; Δ{} · makes Either$String$Value
      ret con Left "expected a number, got a function"  ; Δ{} · makes Either$String$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$Expr
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$Value
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$Value
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$Value
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$Value
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left $bindErr  ; Δ{$bindErr} · moves{$bindErr} · makes Either$String$tuple$Expr$Int
      ret con Left _t0  ; Δ{_t0} · moves{_t0} · makes Either$String$Value
      ret con Left _t9  ; Δ{_t9} · moves{_t9} · makes Either$String$tuple$Expr$Int
      ret con Let _t15 _t16 _t17  ; Δ{_t15 _t16 _t17} · moves{_t15 _t16 _t17} · makes Expr
      ret con Lt _t9 _t10  ; Δ{_t10 _t9} · moves{_t10 _t9} · makes Expr
      ret con Mul _t5 _t6  ; Δ{_t5 _t6} · moves{_t5 _t6} · makes Expr
      ret con Nil  ; Δ{} · makes List$tuple$String$Value
      ret con Nothing  ; Δ{} · makes Maybe$Int
      ret con Num n  ; Δ{} · makes Expr
      ret con Right _t0  ; Δ{_t0} · moves{_t0} · makes Either$String$Value
      ret con Right _t11  ; Δ{_t11} · moves{_t11} · makes Either$String$tuple$Expr$Int
      ret con Right _t4  ; Δ{_t4} · moves{_t4} · makes Either$String$Value
      ret con Right _t4  ; Δ{_t4} · moves{_t4} · makes Either$String$tuple$Expr$Int
      ret con Right _t4  ; Δ{_t4} · moves{_t4} · makes Either$String$tuple$Expr$Int
      ret con Right n  ; Δ{} · makes Either$String$Int
      ret con Sub _t3 _t4  ; Δ{_t3 _t4} · moves{_t3 _t4} · makes Expr
      ret con Sub l r  ; Δ{} · makes Expr
      ret con Var _t0  ; Δ{_t0} · moves{_t0} · makes Expr
      ret d  ; Δ{}
      ret i  ; Δ{}
      ret if _t0 then
      ret if _t0 then
      ret if _t0 then
      ret if _t14 then
      ret if _t2 then
      ret if _t2 then
      ret if _t2 then
      ret if _t4 then
      ret if _t4 then
      ret if _t5 then
      ret if _t6 then
      ret n  ; Δ{}
      ret showInt n  ; Δ{} · makes String
    Add a b ->
    Add a b ->
    App f a ->
    App f a ->
    CloV p b env ->
    CloV p b env ->
    CloV p b env ->
    CloV p body cenv ->
    Cons kv rest ->
    Cons kv rest ->
    Cons t rest ->
    Cons t rest ->
    Cons t rest ->
    Cons t rest ->
    Eq a b ->
    Eq a b ->
    If c t el ->
    If c t el ->
    IntV n ->
    IntV n ->
    IntV n ->
    IntV n ->
    Just x ->
    Lam p body ->
    Lam x b ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left $bindErr ->
    Left msg ->
    Left msg ->
    Let x a b ->
    Let x rhs body ->
    Lt a b ->
    Lt a b ->
    Mul a b ->
    Mul a b ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nil ->
    Nothing ->
    Num n ->
    Num n ->
    Right $bind10005 ->
    Right $bind10190 ->
    Right $bind10481 ->
    Right $bind11899 ->
    Right $bind12776 ->
    Right $bind13356 ->
    Right $bind13717 ->
    Right $bind13907 ->
    Right $bind14226 ->
    Right $bind14574 ->
    Right $bind14755 ->
    Right $bind8418 ->
    Right $bind8802 ->
    Right $bind9148 ->
    Right $bind9528 ->
    Right $bind9690 ->
    Right e ->
    Right fv ->
    Right v ->
    Right v ->
    Right va ->
    Right vc ->
    Sub a b ->
    Sub a b ->
    TName x ->
    TName x ->
    TName x ->
    TNum n ->
    TNum n ->
    TNum n ->
    TSym x ->
    TSym x ->
    TSym x ->
    Var x ->
    Var x ->
    _ ->
    drop _t3 : String
    drop _t4 : String
    drop _t4 : String
    drop c : Expr
    drop c : Expr
    drop e : Expr
    drop rhs : Expr
    drop s : String
    drop s : String
    drop s : String
    drop s : String
    drop tb : Expr
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
    let _d1000000 = putStrLn _t3  ; Δ{_t3}
    let _dd0 = loadraw _p+24  ; Δ{}
    let _dd0 = loadraw _p+24  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd0 = loadraw _p+8  ; Δ{}
    let _dd1 = call axion_drop_Expr _dd0  ; Δ{}
    let _dd1 = call axion_drop_Expr _dd0  ; Δ{}
    let _dd1 = call axion_drop_List$tuple$String$Value _dd0  ; Δ{}
    let _dd1 = call axion_drop_Value _dd0  ; Δ{}
    let _dd1 = call axion_drop_tuple$Expr$Int _dd0  ; Δ{}
    let _dd1 = rtcall axion_str_drop _dd0  ; Δ{}
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
    let _dd2 = loadraw _p+16  ; Δ{}
    let _dd22 = loadraw _p+16  ; Δ{}
    let _dd23 = call axion_drop_Expr _dd22  ; Δ{}
    let _dd24 = loadraw _p+8  ; Δ{}
    let _dd25 = rtcall axion_str_drop _dd24  ; Δ{}
    let _dd28 = loadraw _p+16  ; Δ{}
    let _dd29 = call axion_drop_Expr _dd28  ; Δ{}
    let _dd3 = call axion_drop_Expr _dd2  ; Δ{}
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
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd4 = loadraw _p+8  ; Δ{}
    let _dd40 = loadraw _p+16  ; Δ{}
    let _dd41 = call axion_drop_Expr _dd40  ; Δ{}
    let _dd42 = loadraw _p+8  ; Δ{}
    let _dd43 = call axion_drop_Expr _dd42  ; Δ{}
    let _dd46 = loadraw _p+16  ; Δ{}
    let _dd47 = call axion_drop_Expr _dd46  ; Δ{}
    let _dd48 = loadraw _p+8  ; Δ{}
    let _dd49 = call axion_drop_Expr _dd48  ; Δ{}
    let _dd5 = call axion_drop_Expr _dd4  ; Δ{}
    let _dd5 = if _dd4 then
    let _dd5 = if _dd4 then
    let _dd5 = rtcall axion_str_drop _dd4  ; Δ{}
    let _dd5 = rtcall axion_str_drop _dd4  ; Δ{}
    let _dd5 = rtcall axion_str_drop _dd4  ; Δ{}
    let _dd5 = rtcall axion_str_drop _dd4  ; Δ{}
    let _dd5 = rtcall axion_str_drop _dd4  ; Δ{}
    let _dd52 = loadraw _p+16  ; Δ{}
    let _dd53 = call axion_drop_Expr _dd52  ; Δ{}
    let _dd54 = loadraw _p+8  ; Δ{}
    let _dd55 = call axion_drop_Expr _dd54  ; Δ{}
    let _dd58 = loadraw _p+8  ; Δ{}
    let _dd59 = rtcall axion_str_drop _dd58  ; Δ{}
    let _dd8 = loadraw _p+24  ; Δ{}
    let _dd9 = call axion_drop_Expr _dd8  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + i 1  ; Δ{}
    let _t1 = == c 9  ; Δ{}
    let _t1 = == k 1  ; Δ{}
    let _t1 = == op 1  ; Δ{}
    let _t1 = == op 1  ; Δ{}
    let _t1 = call numAt toks p  ; Δ{}
    let _t1 = tuple l p  ; Δ{} · makes heap
    let _t10 = con Cons _t9 acc  ; Δ{_t9} · moves{_t9} · makes List$Tok
    let _t11 = == c 61  ; Δ{}
    let _t17 = if _t11 then
    let _t2 = == kind 0  ; Δ{}
    let _t2 = call >=$Int c 65  ; Δ{}
    let _t2 = call demo  ; Δ{}
    let _t2 = call isSpaceCh c  ; Δ{}
    let _t2 = call wordAt toks p  ; Δ{} · makes String
    let _t2 = call wordAt toks p  ; Δ{} · makes String
    let _t2 = con Num _t1  ; Δ{} · makes Expr
    let _t2 = rtcall axion_str_at i s  ; Δ{}
    let _t2 = rtcall axion_str_cmp s "-"  ; Δ{s}
    let _t2 = rtcall axion_str_cmp s "<"  ; Δ{s}
    let _t2 = rtcall axion_str_cmp x "in"  ; Δ{}
    let _t2 = rtcall axion_str_len s  ; Δ{}
    let _t2 = tuple l p  ; Δ{} · makes heap
    let _t3 = + p 1  ; Δ{_t2}
    let _t3 = + p 1  ; Δ{_t2}
    let _t3 = + p 1  ; Δ{_t2}
    let _t3 = + p 1  ; Δ{}
    let _t3 = + p 1  ; Δ{}
    let _t3 = + p 1  ; Δ{}
    let _t3 = + p 1  ; Δ{}
    let _t3 = + p 1  ; Δ{}
    let _t3 = + p 1  ; Δ{}
    let _t3 = + p 1  ; Δ{}
    let _t3 = + p 1  ; Δ{}
    let _t3 = < _t1 _t2  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _t3 = call isDigit _t2  ; Δ{}
    let _t3 = call run arg  ; Δ{} · makes String
    let _t3 = if _t2 then
    let _t4 = call wordAt toks p  ; Δ{} · makes String
    let _t4 = call wordAt toks p  ; Δ{} · makes String
    let _t4 = tuple _t2 _t3  ; Δ{_t2} · moves{_t2} · makes heap
    let _t4 = tuple e _t3  ; Δ{} · makes heap
    let _t5 = == k 1  ; Δ{}
    let _t5 = rtcall axion_str_cmp _t4 "\\"  ; Δ{_t4}
    let _t5 = rtcall axion_str_cmp _t4 "if"  ; Δ{_t4}
    let _t5 = rtcall axion_strcat "expected " want  ; Δ{} · makes String
    let _t6 = == _t5 0  ; Δ{}
    let _t6 = == _t5 0  ; Δ{}
    let _t7 = + i 2  ; Δ{}
    let _t8 = rtcall axion_strcat "-" ">"  ; Δ{} · makes String
    let _t9 = con TSym _t8  ; Δ{_t8} · moves{_t8} · makes Tok
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let c = rtcall axion_str_at i s  ; Δ{}
    let c = rtcall axion_str_at i s  ; Δ{}
    let ok = if _t2 then
    ret + x y  ; Δ{}
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
    ret == x y  ; Δ{}
    ret _d1000000  ; Δ{}
    ret _t2  ; Δ{}
    ret call <=$Int c 122  ; Δ{}
    ret call <=$Int c 57  ; Δ{}
    ret call <=$Int c 57  ; Δ{}
    ret call isDigitCh c  ; Δ{}
    ret call pAddStep toks 0 l p  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret call pAppStep toks l p  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret call pCmpTail toks 3 l p  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret call pIfElseB toks c tb _t3  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret call pIfThenB toks c _t3  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret call pLamBody toks _t2 _t3  ; Δ{_t2} · moves{_t2} · makes Either$String$tuple$Expr$Int
    ret call pLamFinish toks nm _t3  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret call pLet toks _t3  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret call pLetBody toks nm rhs _t3  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret call pLetEq toks _t2 _t3  ; Δ{_t2} · moves{_t2} · makes Either$String$tuple$Expr$Int
    ret call pLetRhs toks nm _t3  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret call pMulStep toks l p  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret call pParen toks _t3  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret call readIntGo s 0 0  ; Δ{} · makes Maybe$Int
    ret call reverseToks acc  ; Δ{} · makes List$Tok
    ret call tokLoop s _t7 _t10  ; Δ{_t10} · moves{_t10} · makes List$Tok
    ret con Add l r  ; Δ{} · makes Expr
    ret con Just acc  ; Δ{} · makes Maybe$Int
    ret con Left "expected '->' in lambda"  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret con Left "expected '=' in let"  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret con Left "expected 'else'"  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret con Left "expected 'in' in let"  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret con Left "expected 'then'"  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret con Left "expected a name after 'let'"  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret con Left "expected a parameter name after '\\'"  ; Δ{} · makes Either$String$tuple$Expr$Int
    ret con Left _t5  ; Δ{_t5} · moves{_t5} · makes Either$String$tuple$Expr$Int
    ret con Nothing  ; Δ{} · makes Maybe$Int
    ret con Right _t1  ; Δ{_t1} · moves{_t1} · makes Either$String$tuple$Expr$Int
    ret con Right _t2  ; Δ{_t2} · moves{_t2} · makes Either$String$tuple$Expr$Int
    ret con Right _t4  ; Δ{_t4} · moves{_t4} · makes Either$String$tuple$Expr$Int
    ret con Right _t4  ; Δ{_t4} · moves{_t4} · makes Either$String$tuple$Expr$Int
    ret i  ; Δ{}
    ret if _t1 then
    ret if _t1 then
    ret if _t1 then
    ret if _t1 then
    ret if _t17 then
    ret if _t2 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t3 then
    ret if _t5 then
    ret if _t6 then
    ret if _t6 then
    ret if ok then
  ; Δ{$bind10005}
  ; Δ{$bind10190}
  ; Δ{$bind10481}
  ; Δ{$bind11899}
  ; Δ{$bind12776}
  ; Δ{$bind13356}
  ; Δ{$bind13717}
  ; Δ{$bind13907}
  ; Δ{$bind14226}
  ; Δ{$bind14574}
  ; Δ{$bind14755}
  ; Δ{$bind14755}
  ; Δ{$bind8418}
  ; Δ{$bind8802}
  ; Δ{$bind9148}
  ; Δ{$bind9528}
  ; Δ{$bind9690}
  ; Δ{_t0 body cenv p}
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
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t0}
  ; Δ{_t1}
  ; Δ{_t1}
  ; Δ{_t1}
  ; Δ{_t1}
  ; Δ{_t1}
  ; Δ{_t1}
  ; Δ{_t2 na}
  ; Δ{_t3 na}
  ; Δ{nc}
  ; Δ{s}
  ; Δ{s}
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
  drop _t0 : List$Tok
  drop _t0 : List$tuple$String$Value
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
  drop s : String
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
  let _d1000000 = call dispatch _t0  ; Δ{_t0}
  let _d1000000 = call maybe d _t0 m  ; Δ{_t0}
  let _d1000000 = call runToks _t0  ; Δ{_t0} · makes String
  let _dd0 = band _p 1  ; Δ{}
  let _dd0 = loadraw _p+0  ; Δ{}
  let _dd0 = loadraw _p+8  ; Δ{}
  let _dd1 = call axion_drop_Expr _dd0  ; Δ{}
  let _dd1 = call axion_drop_Value _dd0  ; Δ{}
  let _dd1 = if _dd0 then
  let _dd14 = == _tag 9  ; Δ{}
  let _dd15 = if _dd14 then
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 0  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = == _tag 1  ; Δ{}
  let _dd2 = == _tag 2  ; Δ{}
  let _dd2 = loadraw _p+0  ; Δ{}
  let _dd20 = == _tag 8  ; Δ{}
  let _dd21 = if _dd20 then
  let _dd26 = == _tag 7  ; Δ{}
  let _dd27 = if _dd26 then
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = if _dd2 then
  let _dd3 = rtcall axion_str_drop _dd2  ; Δ{}
  let _dd32 = == _tag 6  ; Δ{}
  let _dd33 = if _dd32 then
  let _dd38 = == _tag 5  ; Δ{}
  let _dd39 = if _dd38 then
  let _dd4 = band _p 1  ; Δ{}
  let _dd44 = == _tag 4  ; Δ{}
  let _dd45 = if _dd44 then
  let _dd5 = if _dd4 then
  let _dd50 = == _tag 3  ; Δ{}
  let _dd51 = if _dd50 then
  let _dd56 = == _tag 2  ; Δ{}
  let _dd57 = if _dd56 then
  let _dd6 = == _tag 0  ; Δ{}
  let _dd6 = == _tag 0  ; Δ{}
  let _dd6 = == _tag 0  ; Δ{}
  let _dd6 = == _tag 1  ; Δ{}
  let _dd6 = == _tag 1  ; Δ{}
  let _dd6 = == _tag 10  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd6 = band _p 1  ; Δ{}
  let _dd60 = == _tag 1  ; Δ{}
  let _dd61 = if _dd60 then
  let _dd7 = if _dd6 then
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
  let _t0 = + p 1  ; Δ{}
  let _t0 = + p 1  ; Δ{}
  let _t0 = + p 1  ; Δ{}
  let _t0 = < x y  ; Δ{}
  let _t0 = == c 32  ; Δ{}
  let _t0 = == c 45  ; Δ{}
  let _t0 = == k 0  ; Δ{}
  let _t0 = == k 0  ; Δ{}
  let _t0 = == op 0  ; Δ{}
  let _t0 = == op 0  ; Δ{}
  let _t0 = call >=$Int c 48  ; Δ{}
  let _t0 = call >=$Int c 48  ; Δ{}
  let _t0 = call >=$Int c 97  ; Δ{}
  let _t0 = call eval env a  ; Δ{} · makes Either$String$Value
  let _t0 = call eval env c  ; Δ{} · makes Either$String$Value
  let _t0 = call eval env f  ; Δ{} · makes Either$String$Value
  let _t0 = call eval env rhs  ; Δ{} · makes Either$String$Value
  let _t0 = call isAlphaCh c  ; Δ{}
  let _t0 = call kindAt toks p  ; Δ{}
  let _t0 = call kindAt toks p  ; Δ{}
  let _t0 = call pAdd toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t0 = call pApp toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t0 = call pAtom toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t0 = call pAtom toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t0 = call pExpr toks 0  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t0 = call pExpr toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t0 = call pExpr toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t0 = call pExpr toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t0 = call pExpr toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t0 = call pExpr toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t0 = call pExpr toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t0 = call pExpr toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t0 = call pMul toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t0 = call parseAt toks  ; Δ{} · makes Either$String$Expr
  let _t0 = call readInt s  ; Δ{} · makes Maybe$Int
  let _t0 = call run "1 + 2 * 3"  ; Δ{} · makes String
  let _t0 = call startsAtomAt toks p  ; Δ{}
  let _t0 = call tokenize src  ; Δ{} · makes List$Tok
  let _t0 = call wordAt toks p  ; Δ{} · makes String
  let _t0 = call wordAt toks p  ; Δ{} · makes String
  let _t0 = call wordAt toks p  ; Δ{} · makes String
  let _t0 = call wordAt toks p  ; Δ{} · makes String
  let _t0 = call wordAt toks p  ; Δ{} · makes String
  let _t0 = call wordAt toks p  ; Δ{} · makes String
  let _t0 = call wordAt toks p  ; Δ{} · makes String
  let _t0 = call wordAt toks p  ; Δ{} · makes String
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t0 = con Nil  ; Δ{} · makes List$Tok
  let _t0 = con Nil  ; Δ{} · makes List$Tok
  let _t0 = con Nil  ; Δ{} · makes List$tuple$String$Value
  let _t0 = rtcall axion_getarg 0  ; Δ{} · makes String
  let _t0 = rtcall axion_str_cmp s "*"  ; Δ{s}
  let _t0 = rtcall axion_str_cmp s "+"  ; Δ{s}
  let _t0 = rtcall axion_str_cmp s "=="  ; Δ{s}
  let _t0 = rtcall axion_str_cmp x "let"  ; Δ{}
  let _t0 = rtcall axion_str_len arg  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t0 = rtcall axion_str_len s  ; Δ{}
  let _t1 = == _t0 0  ; Δ{s}
  let _t1 = == _t0 0  ; Δ{s}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 0  ; Δ{}
  let _t1 = == _t0 1  ; Δ{}
  let _t1 = == _t0 1  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call >=$Int i _t0  ; Δ{}
  let _t1 = call eval _t0 e  ; Δ{_t0} · makes Either$String$Value
  let _t1 = call pAdd toks _t0  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t1 = call pApp toks _t0  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t1 = call pMul toks _t0  ; Δ{} · makes Either$String$tuple$Expr$Int
  let _t1 = if _t0 then
  let _t1 = putStrLn _t0  ; Δ{_t0}
  let _t1 = rtcall axion_str_cmp _t0 "("  ; Δ{_t0}
  let _t1 = rtcall axion_str_cmp _t0 "->"  ; Δ{_t0}
  let _t1 = rtcall axion_str_cmp _t0 "="  ; Δ{_t0}
  let _t1 = rtcall axion_str_cmp _t0 "else"  ; Δ{_t0}
  let _t1 = rtcall axion_str_cmp _t0 "in"  ; Δ{_t0}
  let _t1 = rtcall axion_str_cmp _t0 "let"  ; Δ{_t0}
  let _t1 = rtcall axion_str_cmp _t0 "then"  ; Δ{_t0}
  let _t1 = rtcall axion_str_cmp _t0 want  ; Δ{_t0}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = == _t1 0  ; Δ{}
  let _t2 = == _t1 0  ; Δ{}
  let _t6 = if _t0 then
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let _tag = loadraw _p+0  ; Δ{}
  let k = call kindAt toks p  ; Δ{}
  let k = call kindAt toks p  ; Δ{}
  let s = call wordAt toks p  ; Δ{} · makes String
  let s = call wordAt toks p  ; Δ{} · makes String
  let s = call wordAt toks p  ; Δ{} · makes String
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
  ret _d1000000  ; Δ{_d1000000} · moves{_d1000000}
  ret _d1000000  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call fromMaybe 0 _t0  ; Δ{_t0} · moves{_t0}
  ret call le$Int x y  ; Δ{}
  ret call le$Int y x  ; Δ{}
  ret call pCmp toks p  ; Δ{} · makes Either$String$tuple$Expr$Int
  ret call revToksGo ts _t0  ; Δ{_t0} · moves{_t0} · makes List$Tok
  ret call tokLoop s 0 _t0  ; Δ{_t0} · moves{_t0} · makes List$Tok
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
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t0 of
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case _t1 of
  ret case e of
  ret case e of
  ret case env of
  ret case env of
  ret case fv of
  ret case m of
  ret case t of
  ret case t of
  ret case t of
  ret case toks of
  ret case toks of
  ret case toks of
  ret case ts of
  ret case v of
  ret case v of
  ret case v of
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
  ret if _t1 then
  ret if _t1 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t2 then
  ret if _t6 then
  ret if b then
  ret rtcall axion_array_free _p  ; Δ{}
  ret rtcall axion_strcat s ""  ; Δ{} · makes String
  ret x  ; Δ{}
<=$Int x y  =
>=$Int x y  =
applyClo fv env a  =
applyOp op x y  =
asInt v  =
axion_drop_Array _p  =
axion_drop_Either$String _p  =
axion_drop_Either$String$Expr _p  =
axion_drop_Either$String$Int _p  =
axion_drop_Either$String$Value _p  =
axion_drop_Either$String$tuple$Expr$Int _p  =
axion_drop_Expr _p  =
axion_drop_List _p  =
axion_drop_List$Tok _p  =
axion_drop_List$tuple$String$Value _p  =
axion_drop_Maybe$Int _p  =
axion_drop_Tok _p  =
axion_drop_Value _p  =
axion_drop_tuple$Expr$Int _p  =
axion_drop_tuple$String$Value _p  =
copyEnv env  =
copyExpr e  =
copyStr s  =
copyValue v  =
demo  =
dispatch arg  =
envLookup k env  =
eval env e  =
evalApp env f a  =
evalArith env a b op  =
evalIf env c t el  =
evalLet env x rhs body  =
expectWord toks want e p  =
fromMaybe d m  =
isAlnumCh c  =
isAlphaCh c  =
isDigit c  =
isDigitCh c  =
isKeyword x  =
isSpaceCh c  =
kindAt toks i  =
lam$0 [env ]x  =
le$Int x y  =
main  =
maybe d f m  =
mkBin op l r  =
not b  =
numAt toks i  =
pAdd toks p  =
pAddLoop toks l p  =
pAddStep toks op l p  =
pApp toks p  =
pAppLoop toks l p  =
pAppStep toks l p  =
pAtom toks p  =
pAtomName toks p  =
pAtomSym toks p  =
pCmp toks p  =
pCmpAfter toks l p  =
pCmpTail toks op l p  =
pExpr toks p  =
pIf toks p  =
pIfElse toks c tb p  =
pIfElseB toks c tb p  =
pIfThen toks c p  =
pIfThenB toks c p  =
pLam toks p  =
pLamBody toks nm p  =
pLamFinish toks nm p  =
pLet toks p  =
pLetBody toks nm rhs p  =
pLetEq toks nm p  =
pLetIn toks nm rhs p  =
pLetRhs toks nm p  =
pMul toks p  =
pMulLoop toks l p  =
pMulStep toks l p  =
pParen toks p  =
parseAt toks  =
readInt s  =
readIntGo s i acc  =
readIntOr s  =
revToksGo ts acc  =
reverseToks ts  =
run src  =
runEval e  =
runToks toks  =
scanWhile s i kind  =
showValue v  =
startsAtomAt toks p  =
tokKind t  =
tokLoop s i acc  =
tokNum t  =
tokSym s i c acc  =
tokWord t  =
tokenize s  =
wordAt toks i  =
