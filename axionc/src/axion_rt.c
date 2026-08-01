/* C runtime of Axion's --release backend (§18). It is compiled TOGETHER with the
 * program's LLVM IR (clang -O2 -flto), so the hot operations (bump-alloc,
 * alloc) can inline into the caller. Mirrors the --dev Rust runtime
 * (codegen.rs). All pointers cross the boundary as `long` (i64), so the
 * generated IR is uniformly i64. */
#include <pthread.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

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

/* Prints a `Float` (`main :: Float`) as its SHORTEST round-tripping decimal, so
   --release matches the interpreter/Cranelift (Rust's `{}`), rather than the
   lossy 6-digit `%g`. Grows the precision until the value parses back exactly. */
static void float_shortest(double d, char *buf, long cap) {
  for (int prec = 1; prec <= 17; prec++) {
    snprintf(buf, cap, "%.*g", prec, d);
    if (strtod(buf, NULL) == d)
      break;
  }
}
void axion_print_float(double d) {
  char buf[32];
  float_shortest(d, buf, sizeof buf);
  printf("%s\n", buf);
}

/* `show :: Float -> String`: the shortest round-tripping decimal, as a heap
   C-string (like axion_show_int). The i64 arg is the f64 bit pattern. */
long axion_show_float(long bits) {
  double d;
  memcpy(&d, &bits, sizeof d);
  char *buf = (char *)malloc(32);
  float_shortest(d, buf, 32);
  return (long)buf;
}

/* String concatenation `a ++ b` (both NUL-terminated C-strings) into a fresh
   heap C-string. Backs the `strAppend` builtin. */
long axion_strcat(long a, long b) {
  const char *x = (const char *)a, *y = (const char *)b;
  long la = (long)strlen(x), lb = (long)strlen(y);
  char *buf = (char *)malloc(la + lb + 1);
  memcpy(buf, x, la);
  memcpy(buf + la, y, lb + 1); /* copies y's NUL too */
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

/* --- M:N session scheduler (§11): multi-threaded, defunctionalized. Mirror of
 * the --dev Rust runtime (codegen.rs). A task is a state machine
 * `long step(long sched, long state)` returning 1=done / 0=blocked, writing its
 * result into state[0] when done. Tasks run on a pool of OS threads; one mutex
 * guards the shared state, held ONLY during channel ops — the compute between
 * them runs in parallel. Session-type linearity makes every channel SPSC, so the
 * mutex is the only synchronization needed; deadlock-freedom is guaranteed by
 * types (AX0302). Blocked tasks park in `blocked` and are woken by any `send`; a
 * generation counter closes the lost-wakeup window between a step returning
 * blocked and the worker recording it. */

typedef long (*SessStep)(long, long);

typedef struct {
  long *q;
  int head, len, cap;
} SessEp; /* SPSC FIFO of i64 messages waiting for this endpoint's owner */
typedef struct {
  SessStep step;
  long state;
} SessTask;

typedef struct {
  SessEp *eps;
  int *peer;
  int neps, capeps;
  SessTask *tasks;
  int ntasks, captasks;
  int *ready;
  int rhead, rlen, rcap; /* queue of runnable task indices */
  int *blocked;
  int nblocked, capblocked; /* tasks parked on an empty recv */
  int running;              /* tasks currently being stepped */
  unsigned long gen;        /* bumped on every send (wakeups) */
  void **allocs;
  int nallocs, capallocs; /* task states, freed in bulk at run end */
  long budget;            /* safety net against a livelock bug */
  pthread_mutex_t mtx;
  int done;
  long result;
} Sched;

long axion_sess_new(void) {
  Sched *s = (Sched *)calloc(1, sizeof(Sched));
  pthread_mutex_init(&s->mtx, NULL);
  s->budget = 2000000000L;
  return (long)s;
}

/* all of the following static helpers run with s->mtx held */
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

static void ready_push(Sched *s, int i) {
  if (s->rhead + s->rlen >= s->rcap) {
    if (s->rhead > 0) {
      memmove(s->ready, s->ready + s->rhead, (size_t)s->rlen * sizeof(int));
      s->rhead = 0;
    } else {
      s->rcap = s->rcap ? s->rcap * 2 : 8;
      s->ready = (int *)realloc(s->ready, (size_t)s->rcap * sizeof(int));
    }
  }
  s->ready[s->rhead + s->rlen] = i;
  s->rlen++;
}

static int ready_pop(Sched *s) {
  int i = s->ready[s->rhead];
  s->rhead++;
  s->rlen--;
  return i;
}

static void blocked_push(Sched *s, int i) {
  if (s->nblocked + 1 > s->capblocked) {
    s->capblocked = s->capblocked ? s->capblocked * 2 : 8;
    s->blocked = (int *)realloc(s->blocked, (size_t)s->capblocked * sizeof(int));
  }
  s->blocked[s->nblocked++] = i;
}

/* create a channel: two peer endpoints, a and a+1 (mirrors newChannel) */
long axion_sess_channel(long sched) {
  Sched *s = (Sched *)sched;
  pthread_mutex_lock(&s->mtx);
  int a = sess_new_ep(s);
  int b = sess_new_ep(s);
  s->peer[a] = b;
  s->peer[b] = a;
  pthread_mutex_unlock(&s->mtx);
  return a;
}

/* send v on ep → push to the peer's input queue and wake parked receivers */
void axion_sess_send(long sched, long ep, long v) {
  Sched *s = (Sched *)sched;
  pthread_mutex_lock(&s->mtx);
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
  s->gen++;
  for (int k = 0; k < s->nblocked; k++) ready_push(s, s->blocked[k]);
  s->nblocked = 0;
  pthread_mutex_unlock(&s->mtx);
}

/* 1 if a message is waiting on ep, 0 if empty (would block) */
long axion_sess_pending(long sched, long ep) {
  Sched *s = (Sched *)sched;
  pthread_mutex_lock(&s->mtx);
  long r = s->eps[ep].len > 0 ? 1 : 0;
  pthread_mutex_unlock(&s->mtx);
  return r;
}

/* pop and return the message on ep (caller guarantees pending; SPSC consumer) */
long axion_sess_recv(long sched, long ep) {
  Sched *s = (Sched *)sched;
  pthread_mutex_lock(&s->mtx);
  SessEp *e = &s->eps[ep];
  long v = e->q[e->head];
  e->head++;
  e->len--;
  pthread_mutex_unlock(&s->mtx);
  return v;
}

/* allocate a zeroed task-state block owned by the scheduler (the nursery arena);
 * all such blocks are freed in bulk when axion_sess_run returns. */
long axion_sess_alloc(long sched, long nbytes) {
  Sched *s = (Sched *)sched;
  void *p = calloc(1, (size_t)(nbytes < 8 ? 8 : nbytes));
  pthread_mutex_lock(&s->mtx);
  if (s->nallocs + 1 > s->capallocs) {
    s->capallocs = s->capallocs ? s->capallocs * 2 : 8;
    s->allocs = (void **)realloc(s->allocs, (size_t)s->capallocs * sizeof(void *));
  }
  s->allocs[s->nallocs++] = p;
  pthread_mutex_unlock(&s->mtx);
  return (long)p;
}

void axion_sess_spawn(long sched, long step, long state) {
  Sched *s = (Sched *)sched;
  pthread_mutex_lock(&s->mtx);
  if (s->ntasks + 1 > s->captasks) {
    s->captasks = s->captasks ? s->captasks * 2 : 8;
    s->tasks = (SessTask *)realloc(s->tasks, (size_t)s->captasks * sizeof(SessTask));
  }
  int i = s->ntasks++;
  s->tasks[i].step = (SessStep)step;
  s->tasks[i].state = state;
  ready_push(s, i);
  pthread_mutex_unlock(&s->mtx);
}

/* one worker thread: pull a ready task, run its step without the lock, then mark
 * it done / re-park it. Exits when the root task finishes. */
static void *sess_worker(void *arg) {
  Sched *s = (Sched *)arg;
  for (;;) {
    pthread_mutex_lock(&s->mtx);
    if (s->done) {
      pthread_mutex_unlock(&s->mtx);
      return NULL;
    }
    if (s->rlen == 0) {
      /* nothing runnable: if nothing is running either and tasks are parked, no
       * one can wake them — a deadlock (types forbid it). */
      int stuck = (s->running == 0 && s->nblocked > 0);
      pthread_mutex_unlock(&s->mtx);
      if (stuck) {
        fprintf(stderr, "session scheduler: no progress (deadlock)\n");
        exit(1);
      }
      sched_yield();
      continue;
    }
    if (--s->budget <= 0) {
      pthread_mutex_unlock(&s->mtx);
      fprintf(stderr, "session scheduler: budget exhausted\n");
      exit(1);
    }
    int i = ready_pop(s);
    s->running++;
    SessStep step = s->tasks[i].step;
    long st = s->tasks[i].state;
    unsigned long gen0 = s->gen;
    pthread_mutex_unlock(&s->mtx);

    /* step status: 1 = done, 2 = re-queue (a recursive session loop iterated),
     * 0 = blocked on an empty recv. */
    long fin = step((long)s, st); /* runs WITHOUT the lock (parallel) */

    pthread_mutex_lock(&s->mtx);
    s->running--;
    if (fin == 1) {
      if (i == 0) {
        s->result = *(long *)st;
        s->done = 1;
      }
    } else if (fin == 2 || s->gen != gen0) {
      /* 2: the task looped (§6 recursion) → re-run at the loop head. Also the
       * lost-wakeup guard: a send during this step → re-run, don't park. */
      ready_push(s, i);
    } else {
      blocked_push(s, i);
    }
    pthread_mutex_unlock(&s->mtx);
  }
}

/* run the root task (task 0) and its children on a thread pool until the root
 * finishes; returns the root's result (read from state[0]). */
long axion_sess_run(long sched, long step, long state) {
  Sched *s = (Sched *)sched;
  axion_sess_spawn(sched, step, state); /* root = task 0 */
  /* worker threads: AXION_SESS_THREADS overrides (for scaling benchmarks), else
   * min(online CPUs, 8). */
  int nthreads;
  const char *env = getenv("AXION_SESS_THREADS");
  if (env && atoi(env) > 0) {
    nthreads = atoi(env);
  } else {
    long ncpu = sysconf(_SC_NPROCESSORS_ONLN);
    nthreads = (int)(ncpu < 1 ? 1 : (ncpu > 8 ? 8 : ncpu));
  }
  pthread_t *threads = (pthread_t *)malloc((size_t)nthreads * sizeof(pthread_t));
  for (int t = 0; t < nthreads; t++) pthread_create(&threads[t], NULL, sess_worker, s);
  for (int t = 0; t < nthreads; t++) pthread_join(threads[t], NULL);
  free(threads);
  long result = s->result;
  for (int i = 0; i < s->neps; i++) free(s->eps[i].q);
  for (int i = 0; i < s->nallocs; i++) free(s->allocs[i]);
  free(s->allocs);
  free(s->eps);
  free(s->peer);
  free(s->tasks);
  free(s->ready);
  free(s->blocked);
  pthread_mutex_destroy(&s->mtx);
  free(s);
  return result;
}
