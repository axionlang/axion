/* Runtime C do backend --release da Axión (§18). É compilado JUNTO com o LLVM
 * IR do programa (clang -O2 -flto), pelo que as operações quentes (bump-alloc,
 * alloc) podem inlinar no chamador. Espelha o runtime Rust do --dev
 * (codegen.rs). Todos os ponteiros atravessam a fronteira como `long` (i64),
 * para o IR gerado ser uniformemente i64. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* --- heap com cabeçalho de tamanho (Auto-Drop, §2) --- */
long axion_alloc(long size) {
  long total = (size < 1 ? 1 : size) + 8;
  char *base = (char *)malloc(total);
  *(long *)base = total;
  return (long)(base + 8);
}
void axion_free(long ptr) { free((char *)ptr - 8); }

/* --- strings / IO --- */
void axion_puts(long s) { puts((const char *)s); }
long axion_show_int(long n) {
  char *buf = (char *)malloc(24);
  snprintf(buf, 24, "%ld", n);
  return (long)buf;
}

/* --- arenas (§3): bump-allocator por chunks fixos (ponteiros estáveis) --- */
#define ARENA_CHUNK (64 * 1024)
typedef struct Chunk {
  struct Chunk *prev;
  long cap, off;
  char data[];
} Chunk;
typedef struct {
  Chunk *cur;
} Arena;
typedef struct {
  Arena *arena;
  Chunk *chunk;
  long off;
} Mark;

static Chunk *chunk_new(long cap, Chunk *prev) {
  Chunk *c = (Chunk *)malloc(sizeof(Chunk) + cap);
  c->prev = prev;
  c->cap = cap;
  c->off = 0;
  return c;
}

long axion_arena_new(void) {
  Arena *a = (Arena *)malloc(sizeof(Arena));
  a->cur = chunk_new(ARENA_CHUNK, NULL);
  return (long)a;
}

long axion_arena_alloc(long arena, long size) {
  Arena *a = (Arena *)arena;
  size = (size + 7) & ~7L;
  if (size < 1) size = 8;
  Chunk *c = a->cur;
  if (c->off + size > c->cap) {
    long cap = size > ARENA_CHUNK ? size : ARENA_CHUNK;
    c = chunk_new(cap, a->cur);
    a->cur = c;
  }
  char *p = c->data + c->off;
  c->off += size;
  return (long)p;
}

/* reset em massa: larga todos os chunks de uma vez */
void axion_arena_reset(long arena) {
  Arena *a = (Arena *)arena;
  Chunk *c = a->cur;
  while (c) {
    Chunk *p = c->prev;
    free(c);
    c = p;
  }
  free(a);
}

long axion_arena_mark(long arena) {
  Arena *a = (Arena *)arena;
  Mark *m = (Mark *)malloc(sizeof(Mark));
  m->arena = a;
  m->chunk = a->cur;
  m->off = a->cur->off;
  return (long)m;
}

/* repõe o bump-pointer na marca (liberta os chunks alocados desde então) */
void axion_arena_release(long mark) {
  Mark *m = (Mark *)mark;
  Arena *a = m->arena;
  while (a->cur != m->chunk) {
    Chunk *p = a->cur->prev;
    free(a->cur);
    a->cur = p;
  }
  a->cur->off = m->off;
  free(m);
}

long axion_arena_promote(long target, long cell, long size) {
  long dst = axion_arena_alloc(target, size);
  memcpy((void *)dst, (void *)cell, (size_t)size);
  return dst;
}

/* --- Buffer U8 linear (§4/§5): [len(i64)][bytes…]. As operações em massa
 * (sum) e in-place (iota/xor) são laços que o clang -O2 auto-vectoriza; com
 * -flto inlinam no chamador. É o escape-hatch imperativo/vectorizável. */
long axion_buf_new(long n) {
  char *b = (char *)malloc(8 + (n < 0 ? 0 : n));
  *(long *)b = n;
  memset(b + 8, 0, (size_t)(n < 0 ? 0 : n));
  return (long)b;
}
long axion_buf_iota(long buf) { /* in-place: data[i] = i & 0xFF */
  long n = *(long *)buf;
  unsigned char *d = (unsigned char *)(buf + 8);
  for (long i = 0; i < n; i++) d[i] = (unsigned char)(i & 0xFF);
  return buf;
}
long axion_buf_xor(long buf, long key) { /* in-place: data[i] ^= key */
  long n = *(long *)buf;
  unsigned char *d = (unsigned char *)(buf + 8);
  for (long i = 0; i < n; i++) d[i] ^= (unsigned char)key;
  return buf;
}
long axion_buf_sum(long buf) { /* redução vectorizável (empresta) */
  long n = *(long *)buf, s = 0;
  unsigned char *d = (unsigned char *)(buf + 8);
  for (long i = 0; i < n; i++) s += d[i];
  return s;
}
void axion_buf_free(long buf) { free((void *)buf); }

/* foldBytes f init buf: dobra `f` sobre os bytes. `f` é uma closure Axión
 * {fn_ptr, capturas…}; chama-se `fn_ptr(f, acc, byte)` (a closure é o env do
 * 1.º parâmetro). Chamada indirecta por byte (não vectoriza — usar sumBytes
 * para somas). */
long axion_fold_bytes(long f, long init, long buf) {
  long (*fn)(long, long, long) = *(long (**)(long, long, long))f;
  long n = *(long *)buf;
  unsigned char *d = (unsigned char *)(buf + 8);
  long acc = init;
  for (long i = 0; i < n; i++) acc = fn(f, acc, (long)d[i]);
  return acc;
}
