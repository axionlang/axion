












          ret call mapM_$$compose _cap0 _cap1 ys  ; Δ{}
        _ ->
        ret "Buzz"  ; Δ{}
        ret call show$Int n  ; Δ{} · makes String
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _dd1 = call axion_drop_List$Int _dd0  ; Δ{}
      let _t0 = call compose _cap0 _cap1 y  ; Δ{}
      let _t0 = mod n 5  ; Δ{}
      let _t1 = == _t0 0  ; Δ{}
      ret "Fizz"  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret case _t0 of
      ret if _t1 then
      ret putStr ""  ; Δ{}
    Cons y ys ->
    Nil ->
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t1 = + lo 1  ; Δ{}
    let _t2 = + acc lo  ; Δ{}
    let _t2 = call range _t1 hi  ; Δ{} · makes List$Int
    let _t2 = callclo c lo n  ; Δ{}
    let _t2 = mod n 3  ; Δ{}
    let _t3 = == _t2 0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "FizzBuzz"  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret 0  ; Δ{}
    ret acc  ; Δ{}
    ret call rangeFused _t1 hi c _t2  ; Δ{}
    ret call rangeFusedSum _t1 hi _t2  ; Δ{}
    ret con Cons lo _t2  ; Δ{_t2} · moves{_t2} · makes List$Int
    ret con Nil  ; Δ{} · makes List$Int
    ret if _t3 then
    ret n  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
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
  drop _t1
  drop _t2 : List$Int
  else
  else
  else
  else
  else
  else
  let _d1000000 = call mapM_$$compose _t0 _t1 _t2  ; Δ{_t0 _t1 _t2}
  let _dd4 = band _p 1  ; Δ{}
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _dd5 = if _dd4 then
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = > lo hi  ; Δ{}
  let _t0 = callclo g x  ; Δ{}
  let _t0 = closure lam$0  ; Δ{} · makes heap
  let _t1 = closure lam$1  ; Δ{_t0} · makes heap
  let _t2 = call range 1 15  ; Δ{_t0 _t1} · makes List$Int
  let _t4 = mod n 15  ; Δ{}
  let _t5 = == _t4 0  ; Δ{}
  ret 0  ; Δ{}
  ret 0  ; Δ{}
  ret _d1000000  ; Δ{}
  ret call fizzbuzz eta$3  ; Δ{} · makes String
  ret callclo f _t0  ; Δ{}
  ret case xs of
  ret if _t0 then
  ret if _t0 then
  ret if _t0 then
  ret if _t5 then
  ret putStrLn eta$1  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
  ret showInt x  ; Δ{} · makes String
axion_drop_Array _p  =
axion_drop_List _p  =
axion_drop_List$Int _p  =
compose f g x  =
fizzbuzz n  =
lam$0 [env ]eta$1  =
lam$1 [env ]eta$3  =
main  =
mapM_$$compose _cap0 _cap1 xs  =
range lo hi  =
rangeFused lo hi c n  =
rangeFusedSum lo hi acc  =
show$Int x  =
