






              ret 0  ; Δ{}
              ret 1  ; Δ{}
            else
            let _t12 = 0  ; Δ{}
            let _t13 = if _t12 then
            ret 0  ; Δ{}
            ret 1  ; Δ{}
            ret 1  ; Δ{}
            ret call not _t13  ; Δ{}
          else
          else
          let _t10 = 0  ; Δ{}
          let _t11 = if _t10 then
          ret 0  ; Δ{}
          ret 0  ; Δ{}
          ret 1  ; Δ{}
          ret if _t11 then
        else
        else
        let _t8 = 1  ; Δ{}
        let _t9 = if _t8 then
        ret 0  ; Δ{}
        ret 0  ; Δ{}
        ret 1  ; Δ{}
        ret if _t9 then
      else
      else
      let _dd0 = loadraw _p+16  ; Δ{}
      let _dd1 = call axion_drop_List _dd0  ; Δ{}
      let _t3 = call truth  ; Δ{}
      let _t5 = 0  ; Δ{}
      let _t6 = if _t5 then
      let _t7 = call not _t6  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret 0  ; Δ{}
      ret _t3  ; Δ{}
      ret if _t7 then
    else
    else
    else
    else
    let _dd2 = == _tag 1  ; Δ{}
    let _dd3 = if _dd2 then
    let _dfree = rtcall axion_free _p  ; Δ{}
    let _t1 = div 100 x  ; Δ{}
    let _t1 = div 100 x  ; Δ{}
    let _t2 = 1  ; Δ{}
    let _t2 = call orDiv 0  ; Δ{}
    let _t3 = if _t2 then
    let _t4 = call not _t3  ; Δ{}
    let _tag = loadraw _p+0  ; Δ{}
    ret "bad"  ; Δ{}
    ret "ok"  ; Δ{}
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
    ret > _t1 5  ; Δ{}
    ret > _t1 5  ; Δ{}
    ret if _t2 then
    ret if _t4 then
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  ; Δ{}
  else
  else
  else
  else
  else
  else
  else
  else
  let _dd4 = band _p 1  ; Δ{}
  let _dd5 = if _dd4 then
  let _t0 = 1  ; Δ{}
  let _t0 = == x 0  ; Δ{}
  let _t0 = > x 0  ; Δ{}
  let _t0 = call guardDiv 0  ; Δ{}
  let _t1 = call not _t0  ; Δ{}
  let _t1 = if _t0 then
  let _t4 = if _t1 then
  let _t5 = if _t4 then
  ret 0  ; Δ{}
  ret if _t0 then
  ret if _t0 then
  ret if _t1 then
  ret if b then
  ret putStrLn _t5  ; Δ{}
  ret rtcall axion_array_free _p  ; Δ{}
axion_drop_Array _p  =
axion_drop_List _p  =
guardDiv x  =
main  =
not b  =
orDiv x  =
truth  =
