; Axión --release (LLVM IR)
declare void @axion_puts(i64)
declare i64 @axion_show_int(i64)
declare i64 @axion_alloc(i64)
declare void @axion_free(i64)
declare i64 @axion_arena_new()
declare i64 @axion_arena_alloc(i64, i64)
declare void @axion_arena_reset(i64)
declare i64 @axion_arena_mark(i64)
declare void @axion_arena_release(i64)
declare i64 @axion_arena_promote(i64, i64, i64)
declare i64 @axion_buf_new(i64)
declare i64 @axion_buf_iota(i64)
declare i64 @axion_buf_xor(i64, i64)
declare i64 @axion_buf_sum(i64)
declare void @axion_buf_free(i64)
declare i64 @axion_fold_bytes(i64, i64, i64)
declare i32 @printf(ptr, ...)
@.fmt = private unnamed_addr constant [5 x i8] c"%ld\0A\00"

define i64 @"ax_fib"(i64 %arg0) {
entry:
  %v0 = icmp slt i64 %arg0, 2
  %v1 = zext i1 %v0 to i64
  %v2 = icmp ne i64 %v1, 0
  br i1 %v2, label %then0, label %else1
then0:
  br label %merge2
else1:
  %v3 = sub i64 %arg0, 1
  %v4 = call i64 @"ax_fib"(i64 %v3)
  %v5 = sub i64 %arg0, 2
  %v6 = call i64 @"ax_fib"(i64 %v5)
  %v7 = add i64 %v4, %v6
  br label %merge2
merge2:
  %v8 = phi i64 [ %arg0, %then0 ], [ %v7, %else1 ]
  ret i64 %v8
}

define i64 @"ax_main"() {
entry:
  %v0 = call i64 @"ax_fib"(i64 40)
  ret i64 %v0
}

define i32 @main() {
entry:
  %r = call i64 @"ax_main"()
  call i32 (ptr, ...) @printf(ptr @.fmt, i64 %r)
  ret i32 0
}
