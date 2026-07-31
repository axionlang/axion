/* C runtime of Axion's --release backend (§18). It is compiled TOGETHER with the
 * program's LLVM IR (clang -O2 -flto), so the hot operations (bump-alloc,
 * alloc) can inline into the caller. Mirrors the --dev Rust runtime
 * (codegen.rs). All pointers cross the boundary as `long` (i64), so the
 * generated IR is uniformly i64. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* --- heap with a size header (Auto-Drop, §2) --- */
long axion_alloc(long size) {
  long total = (size < 1 ? 1 : size) + 8;
  char *base = (char *)malloc(total);
  *(long *)base = total;
  return (long)(base + 8);
}
void axion_free(long ptr) { free((char *)ptr - 8); }

/* --- strings / IO --- */
void axion_puts(long s) { puts((const char *)s); }
void axion_put(long s) { fputs((const char *)s, stdout); }
long axion_show_int(long n) {
  char *buf = (char *)malloc(24);
  snprintf(buf, 24, "%ld", n);
  return (long)buf;
}

/* --- arenas (§3): bump-allocator over fixed chunks (stable pointers) --- */
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

/* bulk reset: drops all the chunks at once */
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

/* restores the bump-pointer to the mark (frees the chunks allocated since) */
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

/* --- linear U8 Buffer (§4/§5): [len(i64)][bytes…]. The bulk operations
 * (sum) and in-place ones (iota/xor) are loops that clang -O2 auto-vectorizes; with
 * -flto they inline into the caller. It is the imperative/vectorizable escape-hatch. */
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
long axion_buf_sum(long buf) { /* vectorizable reduction (borrows) */
  long n = *(long *)buf, s = 0;
  unsigned char *d = (unsigned char *)(buf + 8);
  for (long i = 0; i < n; i++) s += d[i];
  return s;
}
void axion_buf_free(long buf) { free((void *)buf); }

/* foldBytes f init buf: folds `f` over the bytes. `f` is an Axion closure
 * {fn_ptr, captures…}; call `fn_ptr(f, acc, byte)` (the closure is the env of the
 * 1st parameter). Indirect call per byte (does not vectorize — use sumBytes
 * for sums). */
long axion_fold_bytes(long f, long init, long buf) {
  long (*fn)(long, long, long) = *(long (**)(long, long, long))f;
  long n = *(long *)buf;
  unsigned char *d = (unsigned char *)(buf + 8);
  long acc = init;
  for (long i = 0; i < n; i++) acc = fn(f, acc, (long)d[i]);
  return acc;
}

/* --- cooperative session scheduler (§11): single-thread, defunctionalized.
 * Native mirror of the interpreter's runtime (interp.rs). A task is a state
 * machine `long step(long sched, long state)` that returns 1=done / 0=blocked,
 * writing its result into state[0] when done. The only suspension point is a
 * `recv` on an empty endpoint. Round-robin until the root task finishes; the
 * absence of deadlock is guaranteed by types (AX0302), so a full sweep with no
 * progress and a live root is a compiler/runtime bug, not a user error. */

typedef long (*SessStep)(long, long);

typedef struct {
  long *q;
  int head, len, cap;
} SessEp; /* FIFO of i64 messages waiting for this endpoint's owner */
typedef struct {
  SessStep step;
  long state;
  int done;
} SessTask;

typedef struct {
  SessEp *eps;
  int *peer;
  int neps, capeps;
  SessTask *tasks;
  int ntasks, captasks;
  void **allocs;
  int nallocs, capallocs; /* task states, freed in bulk at run end */
  int dirty;              /* a channel op happened this sweep → progress was made */
} Sched;

long axion_sess_new(void) { return (long)calloc(1, sizeof(Sched)); }

static int sess_new_ep(Sched *s) {
  if (s->neps + 1 > s->capeps) {
    s->capeps = s->capeps ? s->capeps * 2 : 8;
    s->eps = (SessEp *)realloc(s->eps, (size_t)s->capeps * sizeof(SessEp));
    s->peer = (int *)realloc(s->peer, (size_t)s->capeps * sizeof(int));
  }
  int id = s->neps++;
  s->eps[id].q = NULL;
  s->eps[id].head = s->eps[id].len = s->eps[id].cap = 0;
  return id;
}

/* create a channel: two peer endpoints, a and a+1 (mirrors newChannel) */
long axion_sess_channel(long sched) {
  Sched *s = (Sched *)sched;
  int a = sess_new_ep(s);
  int b = sess_new_ep(s);
  s->peer[a] = b;
  s->peer[b] = a;
  s->dirty = 1;
  return a;
}

/* send v on ep → push to the peer's input queue */
void axion_sess_send(long sched, long ep, long v) {
  Sched *s = (Sched *)sched;
  SessEp *e = &s->eps[s->peer[ep]];
  if (e->head + e->len >= e->cap) {
    if (e->head > 0) { /* compact */
      memmove(e->q, e->q + e->head, (size_t)e->len * sizeof(long));
      e->head = 0;
    } else { /* grow */
      e->cap = e->cap ? e->cap * 2 : 8;
      e->q = (long *)realloc(e->q, (size_t)e->cap * sizeof(long));
    }
  }
  e->q[e->head + e->len] = v;
  e->len++;
  s->dirty = 1;
}

/* 1 if a message is waiting on ep, 0 if empty (would block) */
long axion_sess_pending(long sched, long ep) {
  Sched *s = (Sched *)sched;
  return s->eps[ep].len > 0 ? 1 : 0;
}

/* pop and return the message on ep (caller guarantees pending) */
long axion_sess_recv(long sched, long ep) {
  Sched *s = (Sched *)sched;
  SessEp *e = &s->eps[ep];
  long v = e->q[e->head];
  e->head++;
  e->len--;
  s->dirty = 1;
  return v;
}

/* allocate a zeroed task-state block owned by the scheduler (the nursery arena);
 * all such blocks are freed in bulk when axion_sess_run returns. */
long axion_sess_alloc(long sched, long nbytes) {
  Sched *s = (Sched *)sched;
  if (s->nallocs + 1 > s->capallocs) {
    s->capallocs = s->capallocs ? s->capallocs * 2 : 8;
    s->allocs = (void **)realloc(s->allocs, (size_t)s->capallocs * sizeof(void *));
  }
  void *p = calloc(1, (size_t)(nbytes < 8 ? 8 : nbytes));
  s->allocs[s->nallocs++] = p;
  return (long)p;
}

void axion_sess_spawn(long sched, long step, long state) {
  Sched *s = (Sched *)sched;
  if (s->ntasks + 1 > s->captasks) {
    s->captasks = s->captasks ? s->captasks * 2 : 8;
    s->tasks = (SessTask *)realloc(s->tasks, (size_t)s->captasks * sizeof(SessTask));
  }
  SessTask *t = &s->tasks[s->ntasks++];
  t->step = (SessStep)step;
  t->state = state;
  t->done = 0;
  s->dirty = 1;
}

/* run the root task (task 0) and its children until the root finishes; returns
 * the root's result (read from state[0]). */
long axion_sess_run(long sched, long step, long state) {
  Sched *s = (Sched *)sched;
  axion_sess_spawn(sched, step, state); /* root = task 0 */
  long budget = 5000000;
  for (;;) {
    int progressed = 0;
    s->dirty = 0;
    int n = s->ntasks; /* children spawned this sweep run on the next one */
    for (int i = 0; i < n; i++) {
      if (s->tasks[i].done) continue;
      if (s->tasks[i].step(sched, s->tasks[i].state)) {
        s->tasks[i].done = 1;
        progressed = 1;
      }
      if (--budget <= 0) {
        fprintf(stderr, "session scheduler: budget exhausted\n");
        exit(1);
      }
    }
    if (s->tasks[0].done) break;
    if (!progressed && !s->dirty) {
      fprintf(stderr, "session scheduler: no progress (deadlock)\n");
      exit(1);
    }
  }
  long result = *(long *)s->tasks[0].state;
  for (int i = 0; i < s->neps; i++) free(s->eps[i].q);
  for (int i = 0; i < s->nallocs; i++) free(s->allocs[i]);
  free(s->allocs);
  free(s->eps);
  free(s->peer);
  free(s->tasks);
  free(s);
  return result;
}
