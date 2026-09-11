; Axion --release (LLVM IR)
declare void @axion_puts(i64)
declare void @axion_put(i64)
declare void @axion_eput(i64)
declare void @axion_eputs(i64)
declare i64 @axion_show_int(i64)
declare i64 @axion_show_float(i64)
declare i64 @axion_strcat(i64, i64)
declare i64 @axion_str_len(i64)
declare i64 @axion_str_at(i64, i64)
declare i64 @axion_str_cmp(i64, i64)
declare i64 @axion_substr(i64, i64, i64)
declare i64 @axion_getenv(i64)
declare i64 @axion_run(i64)
declare i64 @axion_system(i64)
declare i64 @axion_read_file(i64)
declare i64 @axion_write_file(i64, i64)
declare i64 @axion_file_exists(i64)
declare i64 @axion_mkdir_p(i64)
declare i64 @axion_unlink(i64)
declare i64 @axion_rename(i64, i64)
declare i64 @axion_readdir(i64)
declare i64 @axion_exec_capture(i64, i64)
declare i64 @axion_exec_status(i64, i64)
declare i64 @axion_read_line(i64)
declare i64 @axion_read_secret(i64)
declare i64 @axion_rand_hex(i64)
declare i64 @axion_exit(i64)
declare void @axion_set_args(i64, i64)
declare i64 @axion_getargs(i64)
declare i64 @axion_getarg(i64)
declare i64 @axion_bignum_from_i64(i64)
declare i64 @axion_bignum_from_str(i64)
declare i64 @axion_bignum_add(i64, i64)
declare i64 @axion_bignum_sub(i64, i64)
declare i64 @axion_bignum_mul(i64, i64)
declare i64 @axion_bignum_div(i64, i64)
declare i64 @axion_bignum_mod(i64, i64)
declare i64 @axion_bignum_eq(i64, i64)
declare i64 @axion_bignum_lt(i64, i64)
declare i64 @axion_bignum_gt(i64, i64)
declare i64 @axion_bignum_to_string(i64)
declare i64 @axion_alloc(i64)
declare void @axion_free(i64)
declare void @axion_str_drop(i64)
declare void @axion_bignum_free(i64)
declare i64 @axion_arena_new()
declare i64 @axion_arena_alloc(i64, i64)
declare void @axion_arena_reset(i64)
declare i64 @axion_arena_mark(i64)
declare void @axion_arena_release(i64)
declare i64 @axion_arena_promote(i64, i64, i64)
declare i64 @axion_fold_bytes(i64, i64, i64)
declare i64 @axion_array_new(i64, i64)
declare i64 @axion_array_get(i64, i64)
declare i64 @axion_array_set(i64, i64, i64)
declare i64 @axion_array_len(i64)
declare void @axion_array_free(i64)
declare i64 @axion_tritvec_new(i64, i64)
declare i64 @axion_tritvec_get(i64, i64)
declare i64 @axion_tritvec_set(i64, i64, i64)
declare i64 @axion_tritvec_len(i64)
declare i64 @axion_tritvec_dot(i64, i64)
declare i64 @axion_tritvec_matvec_sum(i64, i64, i64)
declare i64 @axion_tritvec_from_buffer(i64, i64)
declare i64 @axion_tritvec_iota(i64)
declare i64 @axion_array_iota(i64)
declare i64 @axion_i8_new(i64, i64)
declare i64 @axion_i8_iota(i64)
declare i64 @axion_i8_get(i64, i64)
declare i64 @axion_i8_set(i64, i64, i64)
declare i64 @axion_i8_len(i64)
declare i64 @axion_i8_matvec_sum(i64, i64, i64)
declare i64 @axion_i8_sum(i64)
declare i64 @axion_i8_dot(i64, i64)
declare i64 @axion_i8_dot_i8(i64, i64)
declare i64 @axion_array_sum(i64)
declare i64 @axion_array_dot(i64, i64)
declare i64 @axion_i32_new(i64, i64)
declare i64 @axion_i32_iota(i64)
declare i64 @axion_i32_get(i64, i64)
declare i64 @axion_i32_set(i64, i64, i64)
declare i64 @axion_i32_len(i64)
declare i64 @axion_i32_sum(i64)
declare i64 @axion_i32_dot(i64, i64)
declare i64 @axion_i32_matvec_sum(i64, i64, i64)
declare i64 @axion_buf_new(i64)
declare i64 @axion_buf_iota(i64)
declare i64 @axion_buf_xor(i64, i64)
declare i64 @axion_buf_sum(i64)
declare i64 @axion_buf_free(i64)
declare i64 @axion_sess_new()
declare i64 @axion_sess_channel(i64)
declare void @axion_sess_send(i64, i64, i64)
declare i64 @axion_sess_pending(i64, i64)
declare i64 @axion_sess_recv(i64, i64)
declare i64 @axion_sess_alloc(i64, i64)
declare void @axion_sess_spawn(i64, i64, i64)
declare i64 @axion_sess_run(i64, i64, i64)
declare i64 @axion_par_map(i64, i64, i64, i64)
declare i32 @printf(ptr, ...)
declare i64 @axion_run_main(i64)
declare void @axion_print_float(double)
declare double @llvm.sqrt.f64(double)
declare double @llvm.floor.f64(double)
declare double @llvm.fabs.f64(double)
@.fmt = private unnamed_addr constant [5 x i8] c"%ld\0A\00"
@.str0 = private unnamed_addr constant { i64, [2 x i8] } { i64 0, [2 x i8] c".\00" }
@.str1 = private unnamed_addr constant { i64, [19 x i8] } { i64 0, [19 x i8] c"PASSWORD_STORE_DIR\00" }
@.str2 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c"HOME\00" }
@.str3 = private unnamed_addr constant { i64, [17 x i8] } { i64 0, [17 x i8] c"/.password-store\00" }
@.str4 = private unnamed_addr constant { i64, [2 x i8] } { i64 0, [2 x i8] c"/\00" }
@.str5 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c".gpg\00" }
@.str6 = private unnamed_addr constant { i64, [16 x i8] } { i64 0, [16 x i8] c"gpg\0A-d\0A--quiet\0A\00" }
@.str7 = private unnamed_addr constant { i64, [2 x i8] } { i64 0, [2 x i8] c"'\00" }
@.str8 = private unnamed_addr constant { i64, [1 x i8] } { i64 0, [1 x i8] c"\00" }
@.str9 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c"'\5C''\00" }
@.str10 = private unnamed_addr constant { i64, [24 x i8] } { i64 0, [24 x i8] c"Usage:\20pass\20show\20<name>\00" }
@.str11 = private unnamed_addr constant { i64, [31 x i8] } { i64 0, [31 x i8] c"\20is\20not\20in\20the\20password\20store.\00" }
@.str12 = private unnamed_addr constant { i64, [8 x i8] } { i64 0, [8 x i8] c"Error:\20\00" }
@.str13 = private unnamed_addr constant { i64, [84 x i8] } { i64 0, [84 x i8] c"\202>/dev/null\20&&\20find\20.\20-name\20'*.gpg'\202>/dev/null\20|\20sed\20's#^\5C./##;s#\5C.gpg$##'\20|\20sort\00" }
@.str14 = private unnamed_addr constant { i64, [4 x i8] } { i64 0, [4 x i8] c"cd\20\00" }
@.str15 = private unnamed_addr constant { i64, [24 x i8] } { i64 0, [24 x i8] c"Usage:\20pass\20find\20<term>\00" }
@.str16 = private unnamed_addr constant { i64, [98 x i8] } { i64 0, [98 x i8] c"\202>/dev/null\20&&\20find\20.\20-name\20'*.gpg'\202>/dev/null\20|\20sed\20's#^\5C./##;s#\5C.gpg$##'\20|\20sort\20|\20grep\20-i\20--\20\00" }
@.str17 = private unnamed_addr constant { i64, [26 x i8] } { i64 0, [26 x i8] c"Usage:\20pass\20grep\20<search>\00" }
@.str18 = private unnamed_addr constant { i64, [96 x i8] } { i64 0, [96 x i8] c");\20if\20[\20-n\20\22$m\22\20];\20then\20echo\20\22${f#./}\22\20|\20sed\20's#\5C.gpg$#:#';\20echo\20\22$m\22\20|\20sed\20's/^/\20\20/';\20fi;\20done\00" }
@.str19 = private unnamed_addr constant { i64, [125 x i8] } { i64 0, [125 x i8] c"\202>/dev/null\20&&\20find\20.\20-name\20'*.gpg'\202>/dev/null\20|\20sort\20|\20while\20read\20f;\20do\20m=$(gpg\20-d\20--quiet\20\22$f\22\202>/dev/null\20|\20grep\20-i\20--\20\00" }
@.str20 = private unnamed_addr constant { i64, [8 x i8] } { i64 0, [8 x i8] c".gpg-id\00" }
@.str21 = private unnamed_addr constant { i64, [71 x i8] } { i64 0, [71 x i8] c";\20test\20-d\20\22$d/.git\22\20&&\20git\20-C\20\22$d\22\20add\20-A\20&&\20git\20-C\20\22$d\22\20commit\20-q\20-m\20\00" }
@.str22 = private unnamed_addr constant { i64, [3 x i8] } { i64 0, [3 x i8] c"d=\00" }
@.str23 = private unnamed_addr constant { i64, [23 x i8] } { i64 0, [23 x i8] c"\20>/dev/null\202>&1;\20true\00" }
@.str24 = private unnamed_addr constant { i64, [22 x i8] } { i64 0, [22 x i8] c"Usage:\20pass\20rm\20<name>\00" }
@.str25 = private unnamed_addr constant { i64, [8 x i8] } { i64 0, [8 x i8] c"Remove\20\00" }
@.str26 = private unnamed_addr constant { i64, [9 x i8] } { i64 0, [9 x i8] c"Removed\20\00" }
@.str27 = private unnamed_addr constant { i64, [27 x i8] } { i64 0, [27 x i8] c"Usage:\20pass\20mv\20<old>\20<new>\00" }
@.str28 = private unnamed_addr constant { i64, [8 x i8] } { i64 0, [8 x i8] c"Rename\20\00" }
@.str29 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c"\20to\20\00" }
@.str30 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c"\20->\20\00" }
@.str31 = private unnamed_addr constant { i64, [27 x i8] } { i64 0, [27 x i8] c"Usage:\20pass\20cp\20<old>\20<new>\00" }
@.str32 = private unnamed_addr constant { i64, [7 x i8] } { i64 0, [7 x i8] c"cp\0A--\0A\00" }
@.str33 = private unnamed_addr constant { i64, [2 x i8] } { i64 0, [2 x i8] c"\0A\00" }
@.str34 = private unnamed_addr constant { i64, [6 x i8] } { i64 0, [6 x i8] c"Copy\20\00" }
@.str35 = private unnamed_addr constant { i64, [98 x i8] } { i64 0, [98 x i8] c")\20&&\20printf\20'%s'\20\22$pw\22\20|\20gpg\20-e\20--batch\20--yes\20-r\20\22$(head\20-1\20\22$g\22)\22\20-o\20\22$e\22\20&&\20printf\20'%s\5Cn'\20\22$pw\22\00" }
@.str36 = private unnamed_addr constant { i64, [90 x i8] } { i64 0, [90 x i8] c";\20mkdir\20-p\20\22$(dirname\20\22$e\22)\22\20&&\20pw=$(LC_ALL=C\20tr\20-dc\20'A-Za-z0-9'\20</dev/urandom\20|\20head\20-c\20\00" }
@.str37 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c";\20g=\00" }
@.str38 = private unnamed_addr constant { i64, [3 x i8] } { i64 0, [3 x i8] c"e=\00" }
@.str39 = private unnamed_addr constant { i64, [27 x i8] } { i64 0, [27 x i8] c"Error:\20could\20not\20generate\20\00" }
@.str40 = private unnamed_addr constant { i64, [44 x i8] } { i64 0, [44 x i8] c"\20(is\20the\20store\20initialized\20with\20a\20.gpg-id?)\00" }
@.str41 = private unnamed_addr constant { i64, [28 x i8] } { i64 0, [28 x i8] c"The\20generated\20password\20for\20\00" }
@.str42 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c"\20is:\00" }
@.str43 = private unnamed_addr constant { i64, [10 x i8] } { i64 0, [10 x i8] c"Generate\20\00" }
@.str44 = private unnamed_addr constant { i64, [37 x i8] } { i64 0, [37 x i8] c"Usage:\20pass\20generate\20<name>\20[length]\00" }
@.str45 = private unnamed_addr constant { i64, [25 x i8] } { i64 0, [25 x i8] c"gpg\0A-e\0A--batch\0A--yes\0A-r\0A\00" }
@.str46 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c"\0A-o\0A\00" }
@.str47 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c"Add\20\00" }
@.str48 = private unnamed_addr constant { i64, [7 x i8] } { i64 0, [7 x i8] c"Added\20\00" }
@.str49 = private unnamed_addr constant { i64, [37 x i8] } { i64 0, [37 x i8] c"Error:\20no\20password\20entered,\20aborting\00" }
@.str50 = private unnamed_addr constant { i64, [52 x i8] } { i64 0, [52 x i8] c"Error:\20the\20entered\20passwords\20do\20not\20match,\20aborting\00" }
@.str51 = private unnamed_addr constant { i64, [26 x i8] } { i64 0, [26 x i8] c"Usage:\20pass\20insert\20<name>\00" }
@.str52 = private unnamed_addr constant { i64, [3 x i8] } { i64 0, [3 x i8] c":\20\00" }
@.str53 = private unnamed_addr constant { i64, [20 x i8] } { i64 0, [20 x i8] c"Enter\20password\20for\20\00" }
@.str54 = private unnamed_addr constant { i64, [18 x i8] } { i64 0, [18 x i8] c"Retype\20password:\20\00" }
@.str55 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c"show\00" }
@.str56 = private unnamed_addr constant { i64, [3 x i8] } { i64 0, [3 x i8] c"ls\00" }
@.str57 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c"list\00" }
@.str58 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c"find\00" }
@.str59 = private unnamed_addr constant { i64, [7 x i8] } { i64 0, [7 x i8] c"search\00" }
@.str60 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c"grep\00" }
@.str61 = private unnamed_addr constant { i64, [3 x i8] } { i64 0, [3 x i8] c"rm\00" }
@.str62 = private unnamed_addr constant { i64, [7 x i8] } { i64 0, [7 x i8] c"remove\00" }
@.str63 = private unnamed_addr constant { i64, [7 x i8] } { i64 0, [7 x i8] c"delete\00" }
@.str64 = private unnamed_addr constant { i64, [3 x i8] } { i64 0, [3 x i8] c"mv\00" }
@.str65 = private unnamed_addr constant { i64, [7 x i8] } { i64 0, [7 x i8] c"rename\00" }
@.str66 = private unnamed_addr constant { i64, [3 x i8] } { i64 0, [3 x i8] c"cp\00" }
@.str67 = private unnamed_addr constant { i64, [5 x i8] } { i64 0, [5 x i8] c"copy\00" }
@.str68 = private unnamed_addr constant { i64, [9 x i8] } { i64 0, [9 x i8] c"generate\00" }
@.str69 = private unnamed_addr constant { i64, [7 x i8] } { i64 0, [7 x i8] c"insert\00" }
@.str70 = private unnamed_addr constant { i64, [4 x i8] } { i64 0, [4 x i8] c"add\00" }

define i64 @"ax_&&"(i64 %arg0, i64 %arg1) {
entry:
  %v0 = icmp ne i64 %arg0, 0
  br i1 %v0, label %then0, label %else1
then0:
  br label %merge2
else1:
  br label %merge2
merge2:
  %v1 = phi i64 [ %arg1, %then0 ], [ 0, %else1 ]
  ret i64 %v1
}

define i64 @"ax_isDigit"(i64 %arg0) {
entry:
  %v0 = call i64 @"ax_>=$Int"(i64 %arg0, i64 48)
  %v1 = call i64 @"ax_<=$Int"(i64 %arg0, i64 57)
  %v2 = call i64 @"ax_&&"(i64 %v0, i64 %v1)
  ret i64 %v2
}

define i64 @"ax_chomp"(i64 %arg0) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = icmp eq i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  br label %merge2
else1:
  %v4 = call i64 @axion_str_len(i64 %arg0)
  %v5 = sub i64 %v4, 1
  %v6 = call i64 @axion_str_at(i64 %v5, i64 %arg0)
  %v7 = icmp eq i64 %v6, 10
  %v8 = zext i1 %v7 to i64
  %v9 = icmp ne i64 %v8, 0
  br i1 %v9, label %then3, label %else4
then3:
  %v10 = call i64 @axion_str_len(i64 %arg0)
  %v11 = sub i64 %v10, 1
  %v12 = call i64 @axion_substr(i64 0, i64 %v11, i64 %arg0)
  br label %merge5
else4:
  br label %merge5
merge5:
  %v13 = phi i64 [ %v12, %then3 ], [ %arg0, %else4 ]
  br label %merge2
merge2:
  %v14 = phi i64 [ %arg0, %then0 ], [ %v13, %merge5 ]
  ret i64 %v14
}

define i64 @"ax_hasSuffix"(i64 %arg0, i64 %arg1) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = call i64 @axion_str_len(i64 %arg1)
  %v2 = icmp sgt i64 %v0, %v1
  %v3 = zext i1 %v2 to i64
  %v4 = icmp ne i64 %v3, 0
  br i1 %v4, label %then0, label %else1
then0:
  br label %merge2
else1:
  %v5 = call i64 @axion_str_len(i64 %arg1)
  %v6 = call i64 @axion_str_len(i64 %arg0)
  %v7 = sub i64 %v5, %v6
  %v8 = call i64 @axion_str_len(i64 %arg0)
  %v9 = call i64 @axion_substr(i64 %v7, i64 %v8, i64 %arg1)
  %v10 = call i64 @axion_str_cmp(i64 %v9, i64 %arg0)
  call void @axion_str_drop(i64 %v9)
  %v11 = icmp eq i64 %v10, 0
  %v12 = zext i1 %v11 to i64
  br label %merge2
merge2:
  %v13 = phi i64 [ 0, %then0 ], [ %v12, %else1 ]
  ret i64 %v13
}

define i64 @"ax_lastIndex"(i64 %arg0, i64 %arg1, i64 %arg2, i64 %arg3) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg1)
  %v1 = call i64 @"ax_>=$Int"(i64 %arg2, i64 %v0)
  %v2 = icmp ne i64 %v1, 0
  br i1 %v2, label %then0, label %else1
then0:
  br label %merge2
else1:
  %v3 = call i64 @axion_str_at(i64 %arg2, i64 %arg1)
  %v4 = icmp eq i64 %v3, %arg0
  %v5 = zext i1 %v4 to i64
  %v6 = icmp ne i64 %v5, 0
  br i1 %v6, label %then3, label %else4
then3:
  %v7 = add i64 %arg2, 1
  %v8 = call i64 @"ax_lastIndex"(i64 %arg0, i64 %arg1, i64 %v7, i64 %arg2)
  br label %merge5
else4:
  %v9 = add i64 %arg2, 1
  %v10 = call i64 @"ax_lastIndex"(i64 %arg0, i64 %arg1, i64 %v9, i64 %arg3)
  br label %merge5
merge5:
  %v11 = phi i64 [ %v8, %then3 ], [ %v10, %else4 ]
  br label %merge2
merge2:
  %v12 = phi i64 [ %arg3, %then0 ], [ %v11, %merge5 ]
  ret i64 %v12
}

define i64 @"ax_dirName"(i64 %arg0) {
entry:
  %v0 = sub i64 0, 1
  %v1 = call i64 @"ax_lastIndex"(i64 47, i64 %arg0, i64 0, i64 %v0)
  %v2 = call i64 @"ax_dirBefore"(i64 %arg0, i64 %v1)
  ret i64 %v2
}

define i64 @"ax_dirBefore"(i64 %arg0, i64 %arg1) {
entry:
  %v0 = icmp slt i64 %arg1, 0
  %v1 = zext i1 %v0 to i64
  %v2 = icmp ne i64 %v1, 0
  br i1 %v2, label %then0, label %else1
then0:
  br label %merge2
else1:
  %v3 = call i64 @axion_substr(i64 0, i64 %arg1, i64 %arg0)
  br label %merge2
merge2:
  %v4 = phi i64 [ ptrtoint (ptr getelementptr inbounds ({ i64, [2 x i8] }, ptr @.str0, i32 0, i32 1) to i64), %then0 ], [ %v3, %else1 ]
  ret i64 %v4
}

define i64 @"ax_die"(i64 %arg0) {
entry:
  call void @axion_eputs(i64 %arg0)
  %v0 = call i64 @axion_exit(i64 1)
  ret i64 %v0
}

define i64 @"ax_readInt"(i64 %arg0) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = icmp eq i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  br label %merge2
else1:
  %v4 = call i64 @"ax_readIntGo"(i64 %arg0, i64 0, i64 0)
  br label %merge2
merge2:
  %v5 = phi i64 [ 1, %then0 ], [ %v4, %else1 ]
  ret i64 %v5
}

define i64 @"ax_readIntGo"(i64 %arg0, i64 %arg1, i64 %arg2) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = call i64 @"ax_>=$Int"(i64 %arg1, i64 %v0)
  %v2 = icmp ne i64 %v1, 0
  br i1 %v2, label %then0, label %else1
then0:
  %v3 = call i64 @axion_alloc(i64 16)
  %v4 = inttoptr i64 %v3 to ptr
  %v5 = getelementptr i8, ptr %v4, i64 0
  store i64 1, ptr %v5
  %v6 = inttoptr i64 %v3 to ptr
  %v7 = getelementptr i8, ptr %v6, i64 8
  store i64 %arg2, ptr %v7
  br label %merge2
else1:
  %v8 = call i64 @axion_str_at(i64 %arg1, i64 %arg0)
  %v9 = call i64 @"ax_isDigit"(i64 %v8)
  %v10 = icmp ne i64 %v9, 0
  br i1 %v10, label %then3, label %else4
then3:
  %v11 = add i64 %arg1, 1
  %v12 = mul i64 %arg2, 10
  %v13 = call i64 @axion_str_at(i64 %arg1, i64 %arg0)
  %v14 = sub i64 %v13, 48
  %v15 = add i64 %v12, %v14
  %v16 = call i64 @"ax_readIntGo"(i64 %arg0, i64 %v11, i64 %v15)
  br label %merge5
else4:
  br label %merge5
merge5:
  %v17 = phi i64 [ %v16, %then3 ], [ 1, %else4 ]
  br label %merge2
merge2:
  %v18 = phi i64 [ %v3, %then0 ], [ %v17, %merge5 ]
  ret i64 %v18
}

define i64 @"ax_maybe"(i64 %arg0, i64 %arg1, i64 %arg2) {
entry:
  %v0 = and i64 %arg2, 1
  %v1 = icmp ne i64 %v0, 0
  br i1 %v1, label %imm0, label %ptr1
imm0:
  %v2 = lshr i64 %arg2, 1
  br label %tmerge2
ptr1:
  %v3 = inttoptr i64 %arg2 to ptr
  %v4 = getelementptr i8, ptr %v3, i64 0
  %v5 = load i64, ptr %v4
  br label %tmerge2
tmerge2:
  %v6 = phi i64 [ %v2, %imm0 ], [ %v5, %ptr1 ]
  %v7 = icmp eq i64 %v6, 0
  br i1 %v7, label %then3, label %else4
then3:
  call void @axion_free(i64 %arg2)
  br label %merge5
else4:
  %v8 = inttoptr i64 %arg2 to ptr
  %v9 = getelementptr i8, ptr %v8, i64 8
  %v10 = load i64, ptr %v9
  call void @axion_free(i64 %arg2)
  %v11 = inttoptr i64 %arg1 to ptr
  %v12 = getelementptr i8, ptr %v11, i64 0
  %v13 = load i64, ptr %v12
  %v14 = inttoptr i64 %v13 to ptr
  %v15 = call i64 %v14(i64 %arg1, i64 %v10)
  br label %merge5
merge5:
  %v16 = phi i64 [ %arg0, %then3 ], [ %v15, %else4 ]
  ret i64 %v16
}

define i64 @"ax_fromMaybe"(i64 %arg0, i64 %arg1) {
entry:
  %v0 = call i64 @axion_alloc(i64 8)
  %v1 = inttoptr i64 %v0 to ptr
  %v2 = getelementptr i8, ptr %v1, i64 0
  store i64 ptrtoint (ptr @"ax_lam$0" to i64), ptr %v2
  %v3 = call i64 @"ax_maybe"(i64 %arg0, i64 %v0, i64 %arg1)
  call void @axion_free(i64 %v0)
  ret i64 %v3
}

define i64 @"ax_storeDir"() {
entry:
  %v0 = call i64 @axion_getenv(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [19 x i8] }, ptr @.str1, i32 0, i32 1) to i64))
  %v1 = call i64 @"ax_resolveStore"(i64 %v0)
  ret i64 %v1
}

define i64 @"ax_resolveStore"(i64 %arg0) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = icmp sgt i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  br label %merge2
else1:
  %v4 = call i64 @axion_getenv(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str2, i32 0, i32 1) to i64))
  %v5 = call i64 @axion_strcat(i64 %v4, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [17 x i8] }, ptr @.str3, i32 0, i32 1) to i64))
  call void @axion_str_drop(i64 %v4)
  br label %merge2
merge2:
  %v6 = phi i64 [ %arg0, %then0 ], [ %v5, %else1 ]
  ret i64 %v6
}

define i64 @"ax_</>"(i64 %arg0, i64 %arg1) {
entry:
  %v0 = call i64 @"ax_hasSuffix"(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [2 x i8] }, ptr @.str4, i32 0, i32 1) to i64), i64 %arg0)
  %v1 = icmp ne i64 %v0, 0
  br i1 %v1, label %then0, label %else1
then0:
  %v2 = call i64 @axion_strcat(i64 %arg0, i64 %arg1)
  br label %merge2
else1:
  %v3 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [2 x i8] }, ptr @.str4, i32 0, i32 1) to i64), i64 %arg1)
  %v4 = call i64 @axion_strcat(i64 %arg0, i64 %v3)
  call void @axion_str_drop(i64 %v3)
  br label %merge2
merge2:
  %v5 = phi i64 [ %v2, %then0 ], [ %v4, %else1 ]
  ret i64 %v5
}

define i64 @"ax_entryPath"(i64 %arg0) {
entry:
  %v0 = call i64 @"ax_storeDir"()
  %v1 = call i64 @axion_strcat(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str5, i32 0, i32 1) to i64))
  %v2 = call i64 @"ax_</>"(i64 %v0, i64 %v1)
  call void @axion_str_drop(i64 %v1)
  call void @axion_str_drop(i64 %v0)
  ret i64 %v2
}

define i64 @"ax_decryptArgv"(i64 %arg0) {
entry:
  %v0 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [16 x i8] }, ptr @.str6, i32 0, i32 1) to i64), i64 %arg0)
  ret i64 %v0
}

define i64 @"ax_shQuote"(i64 %arg0) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = call i64 @"ax_shEsc"(i64 %arg0, i64 0, i64 %v0)
  %v2 = call i64 @axion_strcat(i64 %v1, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [2 x i8] }, ptr @.str7, i32 0, i32 1) to i64))
  call void @axion_str_drop(i64 %v1)
  %v3 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [2 x i8] }, ptr @.str7, i32 0, i32 1) to i64), i64 %v2)
  call void @axion_str_drop(i64 %v2)
  ret i64 %v3
}

define i64 @"ax_shEsc"(i64 %arg0, i64 %arg1, i64 %arg2) {
entry:
  %v0 = call i64 @"ax_>=$Int"(i64 %arg1, i64 %arg2)
  %v1 = icmp ne i64 %v0, 0
  br i1 %v1, label %then0, label %else1
then0:
  br label %merge2
else1:
  %v2 = call i64 @axion_str_at(i64 %arg1, i64 %arg0)
  %v3 = icmp eq i64 %v2, 39
  %v4 = zext i1 %v3 to i64
  %v5 = icmp ne i64 %v4, 0
  br i1 %v5, label %then3, label %else4
then3:
  %v6 = add i64 %arg1, 1
  %v7 = call i64 @"ax_shEsc"(i64 %arg0, i64 %v6, i64 %arg2)
  %v8 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str9, i32 0, i32 1) to i64), i64 %v7)
  call void @axion_str_drop(i64 %v7)
  br label %merge5
else4:
  %v9 = call i64 @axion_substr(i64 %arg1, i64 1, i64 %arg0)
  %v10 = add i64 %arg1, 1
  %v11 = call i64 @"ax_shEsc"(i64 %arg0, i64 %v10, i64 %arg2)
  %v12 = call i64 @axion_strcat(i64 %v9, i64 %v11)
  call void @axion_str_drop(i64 %v11)
  call void @axion_str_drop(i64 %v9)
  br label %merge5
merge5:
  %v13 = phi i64 [ %v8, %then3 ], [ %v12, %else4 ]
  br label %merge2
merge2:
  %v14 = phi i64 [ ptrtoint (ptr getelementptr inbounds ({ i64, [1 x i8] }, ptr @.str8, i32 0, i32 1) to i64), %then0 ], [ %v13, %merge5 ]
  ret i64 %v14
}

define i64 @"ax_doShow"(i64 %arg0) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = icmp eq i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  %v4 = call i64 @"ax_die"(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [24 x i8] }, ptr @.str10, i32 0, i32 1) to i64))
  br label %merge2
else1:
  %v5 = call i64 @"ax_entryPath"(i64 %arg0)
  %v6 = call i64 @axion_file_exists(i64 %v5)
  call void @axion_str_drop(i64 %v5)
  %v7 = icmp eq i64 %v6, 1
  %v8 = zext i1 %v7 to i64
  %v9 = icmp ne i64 %v8, 0
  br i1 %v9, label %then3, label %else4
then3:
  %v10 = call i64 @"ax_entryPath"(i64 %arg0)
  %v11 = call i64 @"ax_decryptArgv"(i64 %v10)
  call void @axion_str_drop(i64 %v10)
  %v12 = call i64 @axion_exec_capture(i64 %v11, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [1 x i8] }, ptr @.str8, i32 0, i32 1) to i64))
  call void @axion_str_drop(i64 %v11)
  call void @axion_put(i64 %v12)
  call void @axion_str_drop(i64 %v12)
  br label %merge5
else4:
  %v13 = call i64 @axion_strcat(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [31 x i8] }, ptr @.str11, i32 0, i32 1) to i64))
  %v14 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [8 x i8] }, ptr @.str12, i32 0, i32 1) to i64), i64 %v13)
  call void @axion_str_drop(i64 %v13)
  %v15 = call i64 @"ax_die"(i64 %v14)
  br label %merge5
merge5:
  %v16 = phi i64 [ 0, %then3 ], [ %v15, %else4 ]
  br label %merge2
merge2:
  %v17 = phi i64 [ %v4, %then0 ], [ %v16, %merge5 ]
  ret i64 %v17
}

define i64 @"ax_doLs"() {
entry:
  %v0 = call i64 @"ax_storeDir"()
  %v1 = call i64 @"ax_shQuote"(i64 %v0)
  call void @axion_str_drop(i64 %v0)
  %v2 = call i64 @axion_strcat(i64 %v1, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [84 x i8] }, ptr @.str13, i32 0, i32 1) to i64))
  call void @axion_str_drop(i64 %v1)
  %v3 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [4 x i8] }, ptr @.str14, i32 0, i32 1) to i64), i64 %v2)
  call void @axion_str_drop(i64 %v2)
  %v4 = call i64 @axion_run(i64 %v3)
  call void @axion_str_drop(i64 %v3)
  call void @axion_put(i64 %v4)
  call void @axion_str_drop(i64 %v4)
  ret i64 0
}

define i64 @"ax_doFind"(i64 %arg0) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = icmp eq i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  %v4 = call i64 @"ax_die"(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [24 x i8] }, ptr @.str15, i32 0, i32 1) to i64))
  br label %merge2
else1:
  %v5 = call i64 @"ax_storeDir"()
  %v6 = call i64 @"ax_shQuote"(i64 %v5)
  call void @axion_str_drop(i64 %v5)
  %v7 = call i64 @"ax_shQuote"(i64 %arg0)
  %v8 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [98 x i8] }, ptr @.str16, i32 0, i32 1) to i64), i64 %v7)
  call void @axion_str_drop(i64 %v7)
  %v9 = call i64 @axion_strcat(i64 %v6, i64 %v8)
  call void @axion_str_drop(i64 %v6)
  call void @axion_str_drop(i64 %v8)
  %v10 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [4 x i8] }, ptr @.str14, i32 0, i32 1) to i64), i64 %v9)
  call void @axion_str_drop(i64 %v9)
  %v11 = call i64 @axion_run(i64 %v10)
  call void @axion_str_drop(i64 %v10)
  call void @axion_put(i64 %v11)
  call void @axion_str_drop(i64 %v11)
  br label %merge2
merge2:
  %v12 = phi i64 [ %v4, %then0 ], [ 0, %else1 ]
  ret i64 %v12
}

define i64 @"ax_doGrep"(i64 %arg0) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = icmp eq i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  %v4 = call i64 @"ax_die"(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [26 x i8] }, ptr @.str17, i32 0, i32 1) to i64))
  br label %merge2
else1:
  %v5 = call i64 @"ax_storeDir"()
  %v6 = call i64 @"ax_shQuote"(i64 %v5)
  call void @axion_str_drop(i64 %v5)
  %v7 = call i64 @"ax_shQuote"(i64 %arg0)
  %v8 = call i64 @axion_strcat(i64 %v7, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [96 x i8] }, ptr @.str18, i32 0, i32 1) to i64))
  call void @axion_str_drop(i64 %v7)
  %v9 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [125 x i8] }, ptr @.str19, i32 0, i32 1) to i64), i64 %v8)
  call void @axion_str_drop(i64 %v8)
  %v10 = call i64 @axion_strcat(i64 %v6, i64 %v9)
  call void @axion_str_drop(i64 %v9)
  call void @axion_str_drop(i64 %v6)
  %v11 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [4 x i8] }, ptr @.str14, i32 0, i32 1) to i64), i64 %v10)
  call void @axion_str_drop(i64 %v10)
  %v12 = call i64 @axion_run(i64 %v11)
  call void @axion_str_drop(i64 %v11)
  call void @axion_put(i64 %v12)
  call void @axion_str_drop(i64 %v12)
  br label %merge2
merge2:
  %v13 = phi i64 [ %v4, %then0 ], [ 0, %else1 ]
  ret i64 %v13
}

define i64 @"ax_gpgId"() {
entry:
  %v0 = call i64 @"ax_storeDir"()
  %v1 = call i64 @"ax_</>"(i64 %v0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [8 x i8] }, ptr @.str20, i32 0, i32 1) to i64))
  call void @axion_str_drop(i64 %v0)
  ret i64 %v1
}

define i64 @"ax_gitCommit"(i64 %arg0) {
entry:
  %v0 = call i64 @"ax_storeDir"()
  %v1 = call i64 @"ax_shQuote"(i64 %v0)
  call void @axion_str_drop(i64 %v0)
  %v2 = call i64 @axion_strcat(i64 %v1, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [71 x i8] }, ptr @.str21, i32 0, i32 1) to i64))
  call void @axion_str_drop(i64 %v1)
  %v3 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [3 x i8] }, ptr @.str22, i32 0, i32 1) to i64), i64 %v2)
  call void @axion_str_drop(i64 %v2)
  %v4 = call i64 @"ax_shQuote"(i64 %arg0)
  %v5 = call i64 @axion_strcat(i64 %v4, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [23 x i8] }, ptr @.str23, i32 0, i32 1) to i64))
  call void @axion_str_drop(i64 %v4)
  %v6 = call i64 @axion_strcat(i64 %v3, i64 %v5)
  call void @axion_str_drop(i64 %v3)
  call void @axion_str_drop(i64 %v5)
  %v7 = call i64 @axion_system(i64 %v6)
  call void @axion_str_drop(i64 %v6)
  ret i64 %v7
}

define i64 @"ax_doRm"(i64 %arg0) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = icmp eq i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  %v4 = call i64 @"ax_die"(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [22 x i8] }, ptr @.str24, i32 0, i32 1) to i64))
  br label %merge2
else1:
  %v5 = call i64 @"ax_entryPath"(i64 %arg0)
  %v6 = call i64 @axion_file_exists(i64 %v5)
  call void @axion_str_drop(i64 %v5)
  %v7 = icmp eq i64 %v6, 1
  %v8 = zext i1 %v7 to i64
  %v9 = icmp ne i64 %v8, 0
  br i1 %v9, label %then3, label %else4
then3:
  %v10 = call i64 @"ax_entryPath"(i64 %arg0)
  %v11 = call i64 @axion_unlink(i64 %v10)
  call void @axion_str_drop(i64 %v10)
  %v12 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [8 x i8] }, ptr @.str25, i32 0, i32 1) to i64), i64 %arg0)
  %v13 = call i64 @"ax_gitCommit"(i64 %v12)
  call void @axion_str_drop(i64 %v12)
  %v14 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [9 x i8] }, ptr @.str26, i32 0, i32 1) to i64), i64 %arg0)
  call void @axion_puts(i64 %v14)
  call void @axion_str_drop(i64 %v14)
  br label %merge5
else4:
  %v15 = call i64 @axion_strcat(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [31 x i8] }, ptr @.str11, i32 0, i32 1) to i64))
  %v16 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [8 x i8] }, ptr @.str12, i32 0, i32 1) to i64), i64 %v15)
  call void @axion_str_drop(i64 %v15)
  %v17 = call i64 @"ax_die"(i64 %v16)
  br label %merge5
merge5:
  %v18 = phi i64 [ 0, %then3 ], [ %v17, %else4 ]
  br label %merge2
merge2:
  %v19 = phi i64 [ %v4, %then0 ], [ %v18, %merge5 ]
  ret i64 %v19
}

define i64 @"ax_doMv"(i64 %arg0, i64 %arg1) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = icmp eq i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  %v4 = call i64 @"ax_die"(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [27 x i8] }, ptr @.str27, i32 0, i32 1) to i64))
  br label %merge2
else1:
  %v5 = call i64 @axion_str_len(i64 %arg1)
  %v6 = icmp eq i64 %v5, 0
  %v7 = zext i1 %v6 to i64
  %v8 = icmp ne i64 %v7, 0
  br i1 %v8, label %then3, label %else4
then3:
  %v9 = call i64 @"ax_die"(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [27 x i8] }, ptr @.str27, i32 0, i32 1) to i64))
  br label %merge5
else4:
  %v10 = call i64 @"ax_entryPath"(i64 %arg0)
  %v11 = call i64 @axion_file_exists(i64 %v10)
  call void @axion_str_drop(i64 %v10)
  %v12 = icmp eq i64 %v11, 0
  %v13 = zext i1 %v12 to i64
  %v14 = icmp ne i64 %v13, 0
  br i1 %v14, label %then6, label %else7
then6:
  %v15 = call i64 @axion_strcat(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [31 x i8] }, ptr @.str11, i32 0, i32 1) to i64))
  %v16 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [8 x i8] }, ptr @.str12, i32 0, i32 1) to i64), i64 %v15)
  call void @axion_str_drop(i64 %v15)
  %v17 = call i64 @"ax_die"(i64 %v16)
  br label %merge8
else7:
  %v18 = call i64 @"ax_entryPath"(i64 %arg1)
  %v19 = call i64 @"ax_dirName"(i64 %v18)
  call void @axion_str_drop(i64 %v18)
  %v20 = call i64 @axion_mkdir_p(i64 %v19)
  call void @axion_str_drop(i64 %v19)
  %v21 = call i64 @"ax_entryPath"(i64 %arg0)
  %v22 = call i64 @"ax_entryPath"(i64 %arg1)
  %v23 = call i64 @axion_rename(i64 %v21, i64 %v22)
  call void @axion_str_drop(i64 %v22)
  call void @axion_str_drop(i64 %v21)
  %v24 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [8 x i8] }, ptr @.str28, i32 0, i32 1) to i64), i64 %arg0)
  %v25 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str29, i32 0, i32 1) to i64), i64 %arg1)
  %v26 = call i64 @axion_strcat(i64 %v24, i64 %v25)
  call void @axion_str_drop(i64 %v24)
  call void @axion_str_drop(i64 %v25)
  %v27 = call i64 @"ax_gitCommit"(i64 %v26)
  call void @axion_str_drop(i64 %v26)
  %v28 = call i64 @axion_strcat(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str30, i32 0, i32 1) to i64))
  %v29 = call i64 @axion_strcat(i64 %v28, i64 %arg1)
  call void @axion_str_drop(i64 %v28)
  call void @axion_puts(i64 %v29)
  call void @axion_str_drop(i64 %v29)
  br label %merge8
merge8:
  %v30 = phi i64 [ %v17, %then6 ], [ 0, %else7 ]
  br label %merge5
merge5:
  %v31 = phi i64 [ %v9, %then3 ], [ %v30, %merge8 ]
  br label %merge2
merge2:
  %v32 = phi i64 [ %v4, %then0 ], [ %v31, %merge5 ]
  ret i64 %v32
}

define i64 @"ax_doCp"(i64 %arg0, i64 %arg1) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = icmp eq i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  %v4 = call i64 @"ax_die"(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [27 x i8] }, ptr @.str31, i32 0, i32 1) to i64))
  br label %merge2
else1:
  %v5 = call i64 @axion_str_len(i64 %arg1)
  %v6 = icmp eq i64 %v5, 0
  %v7 = zext i1 %v6 to i64
  %v8 = icmp ne i64 %v7, 0
  br i1 %v8, label %then3, label %else4
then3:
  %v9 = call i64 @"ax_die"(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [27 x i8] }, ptr @.str31, i32 0, i32 1) to i64))
  br label %merge5
else4:
  %v10 = call i64 @"ax_entryPath"(i64 %arg0)
  %v11 = call i64 @axion_file_exists(i64 %v10)
  call void @axion_str_drop(i64 %v10)
  %v12 = icmp eq i64 %v11, 0
  %v13 = zext i1 %v12 to i64
  %v14 = icmp ne i64 %v13, 0
  br i1 %v14, label %then6, label %else7
then6:
  %v15 = call i64 @axion_strcat(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [31 x i8] }, ptr @.str11, i32 0, i32 1) to i64))
  %v16 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [8 x i8] }, ptr @.str12, i32 0, i32 1) to i64), i64 %v15)
  call void @axion_str_drop(i64 %v15)
  %v17 = call i64 @"ax_die"(i64 %v16)
  br label %merge8
else7:
  %v18 = call i64 @"ax_entryPath"(i64 %arg1)
  %v19 = call i64 @"ax_dirName"(i64 %v18)
  call void @axion_str_drop(i64 %v18)
  %v20 = call i64 @axion_mkdir_p(i64 %v19)
  call void @axion_str_drop(i64 %v19)
  %v21 = call i64 @"ax_entryPath"(i64 %arg0)
  %v22 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [7 x i8] }, ptr @.str32, i32 0, i32 1) to i64), i64 %v21)
  call void @axion_str_drop(i64 %v21)
  %v23 = call i64 @"ax_entryPath"(i64 %arg1)
  %v24 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [2 x i8] }, ptr @.str33, i32 0, i32 1) to i64), i64 %v23)
  call void @axion_str_drop(i64 %v23)
  %v25 = call i64 @axion_strcat(i64 %v22, i64 %v24)
  call void @axion_str_drop(i64 %v24)
  call void @axion_str_drop(i64 %v22)
  %v26 = call i64 @axion_exec_status(i64 %v25, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [1 x i8] }, ptr @.str8, i32 0, i32 1) to i64))
  call void @axion_str_drop(i64 %v25)
  %v27 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [6 x i8] }, ptr @.str34, i32 0, i32 1) to i64), i64 %arg0)
  %v28 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str29, i32 0, i32 1) to i64), i64 %arg1)
  %v29 = call i64 @axion_strcat(i64 %v27, i64 %v28)
  call void @axion_str_drop(i64 %v28)
  call void @axion_str_drop(i64 %v27)
  %v30 = call i64 @"ax_gitCommit"(i64 %v29)
  call void @axion_str_drop(i64 %v29)
  %v31 = call i64 @axion_strcat(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str30, i32 0, i32 1) to i64))
  %v32 = call i64 @axion_strcat(i64 %v31, i64 %arg1)
  call void @axion_str_drop(i64 %v31)
  call void @axion_puts(i64 %v32)
  call void @axion_str_drop(i64 %v32)
  br label %merge8
merge8:
  %v33 = phi i64 [ %v17, %then6 ], [ 0, %else7 ]
  br label %merge5
merge5:
  %v34 = phi i64 [ %v9, %then3 ], [ %v33, %merge8 ]
  br label %merge2
merge2:
  %v35 = phi i64 [ %v4, %then0 ], [ %v34, %merge5 ]
  ret i64 %v35
}

define i64 @"ax_genCmd"(i64 %arg0, i64 %arg1, i64 %arg2) {
entry:
  %v0 = call i64 @"ax_shQuote"(i64 %arg0)
  %v1 = call i64 @"ax_shQuote"(i64 %arg1)
  %v2 = call i64 @axion_show_int(i64 %arg2)
  %v3 = call i64 @axion_strcat(i64 %v2, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [98 x i8] }, ptr @.str35, i32 0, i32 1) to i64))
  call void @axion_str_drop(i64 %v2)
  %v4 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [90 x i8] }, ptr @.str36, i32 0, i32 1) to i64), i64 %v3)
  call void @axion_str_drop(i64 %v3)
  %v5 = call i64 @axion_strcat(i64 %v1, i64 %v4)
  call void @axion_str_drop(i64 %v1)
  call void @axion_str_drop(i64 %v4)
  %v6 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str37, i32 0, i32 1) to i64), i64 %v5)
  call void @axion_str_drop(i64 %v5)
  %v7 = call i64 @axion_strcat(i64 %v0, i64 %v6)
  call void @axion_str_drop(i64 %v6)
  call void @axion_str_drop(i64 %v0)
  %v8 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [3 x i8] }, ptr @.str38, i32 0, i32 1) to i64), i64 %v7)
  call void @axion_str_drop(i64 %v7)
  ret i64 %v8
}

define i64 @"ax_genReport"(i64 %arg0, i64 %arg1) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg1)
  %v1 = icmp eq i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  %v4 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [27 x i8] }, ptr @.str39, i32 0, i32 1) to i64), i64 %arg0)
  %v5 = call i64 @axion_strcat(i64 %v4, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [44 x i8] }, ptr @.str40, i32 0, i32 1) to i64))
  call void @axion_str_drop(i64 %v4)
  %v6 = call i64 @"ax_die"(i64 %v5)
  br label %merge2
else1:
  %v7 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [28 x i8] }, ptr @.str41, i32 0, i32 1) to i64), i64 %arg0)
  %v8 = call i64 @axion_strcat(i64 %v7, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str42, i32 0, i32 1) to i64))
  call void @axion_str_drop(i64 %v7)
  call void @axion_puts(i64 %v8)
  call void @axion_str_drop(i64 %v8)
  %v9 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [10 x i8] }, ptr @.str43, i32 0, i32 1) to i64), i64 %arg0)
  %v10 = call i64 @"ax_gitCommit"(i64 %v9)
  call void @axion_str_drop(i64 %v9)
  call void @axion_put(i64 %arg1)
  br label %merge2
merge2:
  %v11 = phi i64 [ %v6, %then0 ], [ 0, %else1 ]
  ret i64 %v11
}

define i64 @"ax_doGenerate"(i64 %arg0, i64 %arg1) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = icmp eq i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  %v4 = call i64 @"ax_die"(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [37 x i8] }, ptr @.str44, i32 0, i32 1) to i64))
  br label %merge2
else1:
  %v5 = call i64 @"ax_entryPath"(i64 %arg0)
  %v6 = call i64 @"ax_gpgId"()
  %v7 = call i64 @"ax_readInt"(i64 %arg1)
  %v8 = call i64 @"ax_fromMaybe"(i64 25, i64 %v7)
  %v9 = call i64 @"ax_genCmd"(i64 %v5, i64 %v6, i64 %v8)
  call void @axion_str_drop(i64 %v6)
  call void @axion_str_drop(i64 %v5)
  %v10 = call i64 @axion_run(i64 %v9)
  call void @axion_str_drop(i64 %v9)
  %v11 = call i64 @"ax_genReport"(i64 %arg0, i64 %v10)
  br label %merge2
merge2:
  %v12 = phi i64 [ %v4, %then0 ], [ %v11, %else1 ]
  ret i64 %v12
}

define i64 @"ax_encryptArgv"(i64 %arg0, i64 %arg1) {
entry:
  %v0 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [25 x i8] }, ptr @.str45, i32 0, i32 1) to i64), i64 %arg0)
  %v1 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str46, i32 0, i32 1) to i64), i64 %arg1)
  %v2 = call i64 @axion_strcat(i64 %v0, i64 %v1)
  call void @axion_str_drop(i64 %v0)
  call void @axion_str_drop(i64 %v1)
  ret i64 %v2
}

define i64 @"ax_insertEncrypt"(i64 %arg0, i64 %arg1, i64 %arg2) {
entry:
  %v0 = call i64 @"ax_entryPath"(i64 %arg0)
  %v1 = call i64 @"ax_dirName"(i64 %v0)
  call void @axion_str_drop(i64 %v0)
  %v2 = call i64 @axion_mkdir_p(i64 %v1)
  call void @axion_str_drop(i64 %v1)
  %v3 = call i64 @"ax_entryPath"(i64 %arg0)
  %v4 = call i64 @"ax_encryptArgv"(i64 %arg1, i64 %v3)
  call void @axion_str_drop(i64 %v3)
  %v5 = call i64 @axion_exec_status(i64 %v4, i64 %arg2)
  call void @axion_str_drop(i64 %v4)
  %v6 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str47, i32 0, i32 1) to i64), i64 %arg0)
  %v7 = call i64 @"ax_gitCommit"(i64 %v6)
  call void @axion_str_drop(i64 %v6)
  %v8 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [7 x i8] }, ptr @.str48, i32 0, i32 1) to i64), i64 %arg0)
  call void @axion_puts(i64 %v8)
  call void @axion_str_drop(i64 %v8)
  ret i64 0
}

define i64 @"ax_insertFinish"(i64 %arg0, i64 %arg1, i64 %arg2) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg1)
  %v1 = icmp eq i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  %v4 = call i64 @"ax_die"(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [37 x i8] }, ptr @.str49, i32 0, i32 1) to i64))
  br label %merge2
else1:
  %v5 = call i64 @axion_str_cmp(i64 %arg1, i64 %arg2)
  %v6 = icmp eq i64 %v5, 0
  %v7 = zext i1 %v6 to i64
  %v8 = icmp ne i64 %v7, 0
  br i1 %v8, label %then3, label %else4
then3:
  %v9 = call i64 @"ax_gpgId"()
  %v10 = call i64 @axion_read_file(i64 %v9)
  call void @axion_str_drop(i64 %v9)
  %v11 = call i64 @"ax_chomp"(i64 %v10)
  %v12 = call i64 @"ax_insertEncrypt"(i64 %arg0, i64 %v11, i64 %arg1)
  call void @axion_str_drop(i64 %v11)
  br label %merge5
else4:
  %v13 = call i64 @"ax_die"(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [52 x i8] }, ptr @.str50, i32 0, i32 1) to i64))
  br label %merge5
merge5:
  %v14 = phi i64 [ %v12, %then3 ], [ %v13, %else4 ]
  br label %merge2
merge2:
  %v15 = phi i64 [ %v4, %then0 ], [ %v14, %merge5 ]
  ret i64 %v15
}

define i64 @"ax_doInsert"(i64 %arg0) {
entry:
  %v0 = call i64 @axion_str_len(i64 %arg0)
  %v1 = icmp eq i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  %v4 = call i64 @"ax_die"(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [26 x i8] }, ptr @.str51, i32 0, i32 1) to i64))
  br label %merge2
else1:
  %v5 = call i64 @axion_strcat(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [3 x i8] }, ptr @.str52, i32 0, i32 1) to i64))
  %v6 = call i64 @axion_strcat(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [20 x i8] }, ptr @.str53, i32 0, i32 1) to i64), i64 %v5)
  call void @axion_str_drop(i64 %v5)
  call void @axion_eput(i64 %v6)
  call void @axion_str_drop(i64 %v6)
  %v7 = call i64 @axion_read_secret(i64 0)
  call void @axion_eput(i64 ptrtoint (ptr getelementptr inbounds ({ i64, [18 x i8] }, ptr @.str54, i32 0, i32 1) to i64))
  %v8 = call i64 @axion_read_secret(i64 0)
  %v9 = call i64 @"ax_insertFinish"(i64 %arg0, i64 %v7, i64 %v8)
  call void @axion_str_drop(i64 %v8)
  call void @axion_str_drop(i64 %v7)
  br label %merge2
merge2:
  %v10 = phi i64 [ %v4, %then0 ], [ %v9, %else1 ]
  ret i64 %v10
}

define i64 @"ax_dispatch"(i64 %arg0) {
entry:
  %v0 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str55, i32 0, i32 1) to i64))
  %v1 = icmp eq i64 %v0, 0
  %v2 = zext i1 %v1 to i64
  %v3 = icmp ne i64 %v2, 0
  br i1 %v3, label %then0, label %else1
then0:
  %v4 = call i64 @axion_getarg(i64 1)
  %v5 = call i64 @"ax_doShow"(i64 %v4)
  call void @axion_str_drop(i64 %v4)
  br label %merge2
else1:
  %v6 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [3 x i8] }, ptr @.str56, i32 0, i32 1) to i64))
  %v7 = icmp eq i64 %v6, 0
  %v8 = zext i1 %v7 to i64
  %v9 = icmp ne i64 %v8, 0
  br i1 %v9, label %then3, label %else4
then3:
  %v10 = call i64 @"ax_doLs"()
  br label %merge5
else4:
  %v11 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str57, i32 0, i32 1) to i64))
  %v12 = icmp eq i64 %v11, 0
  %v13 = zext i1 %v12 to i64
  %v14 = icmp ne i64 %v13, 0
  br i1 %v14, label %then6, label %else7
then6:
  %v15 = call i64 @"ax_doLs"()
  br label %merge8
else7:
  %v16 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str58, i32 0, i32 1) to i64))
  %v17 = icmp eq i64 %v16, 0
  %v18 = zext i1 %v17 to i64
  %v19 = icmp ne i64 %v18, 0
  br i1 %v19, label %then9, label %else10
then9:
  %v20 = call i64 @axion_getarg(i64 1)
  %v21 = call i64 @"ax_doFind"(i64 %v20)
  call void @axion_str_drop(i64 %v20)
  br label %merge11
else10:
  %v22 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [7 x i8] }, ptr @.str59, i32 0, i32 1) to i64))
  %v23 = icmp eq i64 %v22, 0
  %v24 = zext i1 %v23 to i64
  %v25 = icmp ne i64 %v24, 0
  br i1 %v25, label %then12, label %else13
then12:
  %v26 = call i64 @axion_getarg(i64 1)
  %v27 = call i64 @"ax_doFind"(i64 %v26)
  call void @axion_str_drop(i64 %v26)
  br label %merge14
else13:
  %v28 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str60, i32 0, i32 1) to i64))
  %v29 = icmp eq i64 %v28, 0
  %v30 = zext i1 %v29 to i64
  %v31 = icmp ne i64 %v30, 0
  br i1 %v31, label %then15, label %else16
then15:
  %v32 = call i64 @axion_getarg(i64 1)
  %v33 = call i64 @"ax_doGrep"(i64 %v32)
  call void @axion_str_drop(i64 %v32)
  br label %merge17
else16:
  %v34 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [3 x i8] }, ptr @.str61, i32 0, i32 1) to i64))
  %v35 = icmp eq i64 %v34, 0
  %v36 = zext i1 %v35 to i64
  %v37 = icmp ne i64 %v36, 0
  br i1 %v37, label %then18, label %else19
then18:
  %v38 = call i64 @axion_getarg(i64 1)
  %v39 = call i64 @"ax_doRm"(i64 %v38)
  call void @axion_str_drop(i64 %v38)
  br label %merge20
else19:
  %v40 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [7 x i8] }, ptr @.str62, i32 0, i32 1) to i64))
  %v41 = icmp eq i64 %v40, 0
  %v42 = zext i1 %v41 to i64
  %v43 = icmp ne i64 %v42, 0
  br i1 %v43, label %then21, label %else22
then21:
  %v44 = call i64 @axion_getarg(i64 1)
  %v45 = call i64 @"ax_doRm"(i64 %v44)
  call void @axion_str_drop(i64 %v44)
  br label %merge23
else22:
  %v46 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [7 x i8] }, ptr @.str63, i32 0, i32 1) to i64))
  %v47 = icmp eq i64 %v46, 0
  %v48 = zext i1 %v47 to i64
  %v49 = icmp ne i64 %v48, 0
  br i1 %v49, label %then24, label %else25
then24:
  %v50 = call i64 @axion_getarg(i64 1)
  %v51 = call i64 @"ax_doRm"(i64 %v50)
  call void @axion_str_drop(i64 %v50)
  br label %merge26
else25:
  %v52 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [3 x i8] }, ptr @.str64, i32 0, i32 1) to i64))
  %v53 = icmp eq i64 %v52, 0
  %v54 = zext i1 %v53 to i64
  %v55 = icmp ne i64 %v54, 0
  br i1 %v55, label %then27, label %else28
then27:
  %v56 = call i64 @axion_getarg(i64 1)
  %v57 = call i64 @axion_getarg(i64 2)
  %v58 = call i64 @"ax_doMv"(i64 %v56, i64 %v57)
  call void @axion_str_drop(i64 %v56)
  call void @axion_str_drop(i64 %v57)
  br label %merge29
else28:
  %v59 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [7 x i8] }, ptr @.str65, i32 0, i32 1) to i64))
  %v60 = icmp eq i64 %v59, 0
  %v61 = zext i1 %v60 to i64
  %v62 = icmp ne i64 %v61, 0
  br i1 %v62, label %then30, label %else31
then30:
  %v63 = call i64 @axion_getarg(i64 1)
  %v64 = call i64 @axion_getarg(i64 2)
  %v65 = call i64 @"ax_doMv"(i64 %v63, i64 %v64)
  call void @axion_str_drop(i64 %v64)
  call void @axion_str_drop(i64 %v63)
  br label %merge32
else31:
  %v66 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [3 x i8] }, ptr @.str66, i32 0, i32 1) to i64))
  %v67 = icmp eq i64 %v66, 0
  %v68 = zext i1 %v67 to i64
  %v69 = icmp ne i64 %v68, 0
  br i1 %v69, label %then33, label %else34
then33:
  %v70 = call i64 @axion_getarg(i64 1)
  %v71 = call i64 @axion_getarg(i64 2)
  %v72 = call i64 @"ax_doCp"(i64 %v70, i64 %v71)
  call void @axion_str_drop(i64 %v70)
  call void @axion_str_drop(i64 %v71)
  br label %merge35
else34:
  %v73 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [5 x i8] }, ptr @.str67, i32 0, i32 1) to i64))
  %v74 = icmp eq i64 %v73, 0
  %v75 = zext i1 %v74 to i64
  %v76 = icmp ne i64 %v75, 0
  br i1 %v76, label %then36, label %else37
then36:
  %v77 = call i64 @axion_getarg(i64 1)
  %v78 = call i64 @axion_getarg(i64 2)
  %v79 = call i64 @"ax_doCp"(i64 %v77, i64 %v78)
  call void @axion_str_drop(i64 %v78)
  call void @axion_str_drop(i64 %v77)
  br label %merge38
else37:
  %v80 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [9 x i8] }, ptr @.str68, i32 0, i32 1) to i64))
  %v81 = icmp eq i64 %v80, 0
  %v82 = zext i1 %v81 to i64
  %v83 = icmp ne i64 %v82, 0
  br i1 %v83, label %then39, label %else40
then39:
  %v84 = call i64 @axion_getarg(i64 1)
  %v85 = call i64 @axion_getarg(i64 2)
  %v86 = call i64 @"ax_doGenerate"(i64 %v84, i64 %v85)
  call void @axion_str_drop(i64 %v84)
  call void @axion_str_drop(i64 %v85)
  br label %merge41
else40:
  %v87 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [7 x i8] }, ptr @.str69, i32 0, i32 1) to i64))
  %v88 = icmp eq i64 %v87, 0
  %v89 = zext i1 %v88 to i64
  %v90 = icmp ne i64 %v89, 0
  br i1 %v90, label %then42, label %else43
then42:
  %v91 = call i64 @axion_getarg(i64 1)
  %v92 = call i64 @"ax_doInsert"(i64 %v91)
  call void @axion_str_drop(i64 %v91)
  br label %merge44
else43:
  %v93 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [4 x i8] }, ptr @.str70, i32 0, i32 1) to i64))
  %v94 = icmp eq i64 %v93, 0
  %v95 = zext i1 %v94 to i64
  %v96 = icmp ne i64 %v95, 0
  br i1 %v96, label %then45, label %else46
then45:
  %v97 = call i64 @axion_getarg(i64 1)
  %v98 = call i64 @"ax_doInsert"(i64 %v97)
  call void @axion_str_drop(i64 %v97)
  br label %merge47
else46:
  %v99 = call i64 @axion_str_cmp(i64 %arg0, i64 ptrtoint (ptr getelementptr inbounds ({ i64, [1 x i8] }, ptr @.str8, i32 0, i32 1) to i64))
  %v100 = icmp eq i64 %v99, 0
  %v101 = zext i1 %v100 to i64
  %v102 = icmp ne i64 %v101, 0
  br i1 %v102, label %then48, label %else49
then48:
  %v103 = call i64 @"ax_doLs"()
  br label %merge50
else49:
  %v104 = call i64 @"ax_doShow"(i64 %arg0)
  br label %merge50
merge50:
  %v105 = phi i64 [ %v103, %then48 ], [ %v104, %else49 ]
  br label %merge47
merge47:
  %v106 = phi i64 [ %v98, %then45 ], [ %v105, %merge50 ]
  br label %merge44
merge44:
  %v107 = phi i64 [ %v92, %then42 ], [ %v106, %merge47 ]
  br label %merge41
merge41:
  %v108 = phi i64 [ %v86, %then39 ], [ %v107, %merge44 ]
  br label %merge38
merge38:
  %v109 = phi i64 [ %v79, %then36 ], [ %v108, %merge41 ]
  br label %merge35
merge35:
  %v110 = phi i64 [ %v72, %then33 ], [ %v109, %merge38 ]
  br label %merge32
merge32:
  %v111 = phi i64 [ %v65, %then30 ], [ %v110, %merge35 ]
  br label %merge29
merge29:
  %v112 = phi i64 [ %v58, %then27 ], [ %v111, %merge32 ]
  br label %merge26
merge26:
  %v113 = phi i64 [ %v51, %then24 ], [ %v112, %merge29 ]
  br label %merge23
merge23:
  %v114 = phi i64 [ %v45, %then21 ], [ %v113, %merge26 ]
  br label %merge20
merge20:
  %v115 = phi i64 [ %v39, %then18 ], [ %v114, %merge23 ]
  br label %merge17
merge17:
  %v116 = phi i64 [ %v33, %then15 ], [ %v115, %merge20 ]
  br label %merge14
merge14:
  %v117 = phi i64 [ %v27, %then12 ], [ %v116, %merge17 ]
  br label %merge11
merge11:
  %v118 = phi i64 [ %v21, %then9 ], [ %v117, %merge14 ]
  br label %merge8
merge8:
  %v119 = phi i64 [ %v15, %then6 ], [ %v118, %merge11 ]
  br label %merge5
merge5:
  %v120 = phi i64 [ %v10, %then3 ], [ %v119, %merge8 ]
  br label %merge2
merge2:
  %v121 = phi i64 [ %v5, %then0 ], [ %v120, %merge5 ]
  ret i64 %v121
}

define i64 @"ax_main"() {
entry:
  %v0 = call i64 @axion_getarg(i64 0)
  %v1 = call i64 @"ax_dispatch"(i64 %v0)
  call void @axion_str_drop(i64 %v0)
  ret i64 %v1
}

define i64 @"ax_le$Int"(i64 %arg0, i64 %arg1) {
entry:
  %v0 = icmp slt i64 %arg0, %arg1
  %v1 = zext i1 %v0 to i64
  %v2 = icmp ne i64 %v1, 0
  br i1 %v2, label %then0, label %else1
then0:
  br label %merge2
else1:
  %v3 = icmp eq i64 %arg0, %arg1
  %v4 = zext i1 %v3 to i64
  br label %merge2
merge2:
  %v5 = phi i64 [ 1, %then0 ], [ %v4, %else1 ]
  ret i64 %v5
}

define i64 @"ax_<=$Int"(i64 %arg0, i64 %arg1) {
entry:
  %v0 = call i64 @"ax_le$Int"(i64 %arg0, i64 %arg1)
  ret i64 %v0
}

define i64 @"ax_>=$Int"(i64 %arg0, i64 %arg1) {
entry:
  %v0 = call i64 @"ax_le$Int"(i64 %arg1, i64 %arg0)
  ret i64 %v0
}

define i64 @"ax_lam$0"(i64 %env, i64 %arg0) {
entry:
  ret i64 %arg0
}

define i64 @"ax_axion_drop_List"(i64 %arg0) {
entry:
  %v0 = and i64 %arg0, 1
  %v1 = icmp ne i64 %v0, 0
  br i1 %v1, label %then0, label %else1
then0:
  br label %merge2
else1:
  %v2 = inttoptr i64 %arg0 to ptr
  %v3 = getelementptr i8, ptr %v2, i64 0
  %v4 = load i64, ptr %v3
  %v5 = icmp eq i64 %v4, 1
  %v6 = zext i1 %v5 to i64
  %v7 = icmp ne i64 %v6, 0
  br i1 %v7, label %then3, label %else4
then3:
  %v8 = inttoptr i64 %arg0 to ptr
  %v9 = getelementptr i8, ptr %v8, i64 16
  %v10 = load i64, ptr %v9
  %v11 = call i64 @"ax_axion_drop_List"(i64 %v10)
  br label %merge5
else4:
  br label %merge5
merge5:
  %v12 = phi i64 [ 0, %then3 ], [ 0, %else4 ]
  call void @axion_free(i64 %arg0)
  br label %merge2
merge2:
  %v13 = phi i64 [ 0, %then0 ], [ 0, %merge5 ]
  ret i64 0
}

define i64 @"ax_axion_drop_Array"(i64 %arg0) {
entry:
  call void @axion_array_free(i64 %arg0)
  ret i64 0
}

define i64 @"ax_axion_drop_Maybe$Int"(i64 %arg0) {
entry:
  %v0 = and i64 %arg0, 1
  %v1 = icmp ne i64 %v0, 0
  br i1 %v1, label %then0, label %else1
then0:
  br label %merge2
else1:
  %v2 = inttoptr i64 %arg0 to ptr
  %v3 = getelementptr i8, ptr %v2, i64 0
  %v4 = load i64, ptr %v3
  call void @axion_free(i64 %arg0)
  br label %merge2
merge2:
  %v5 = phi i64 [ 0, %then0 ], [ 0, %else1 ]
  ret i64 0
}

define i32 @main(i32 %argc, ptr %argv) {
entry:
  %ac = sext i32 %argc to i64
  %av = ptrtoint ptr %argv to i64
  call void @axion_set_args(i64 %ac, i64 %av)
  %fp = ptrtoint ptr @"ax_main" to i64
  %r = call i64 @axion_run_main(i64 %fp)
  ret i32 0
}
