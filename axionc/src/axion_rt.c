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

/* --- OS capability layer (§pass): filesystem, subprocess, randomness, tty --- */
#include <dirent.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <termios.h>
#include <signal.h>

/* --- networking (§FFI): socket operations for TCP clients and servers --- */
#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <errno.h>

/* `malloc` that aborts cleanly on out-of-memory instead of returning NULL (which
 * the callers would dereference → SIGSEGV). Resource exhaustion is not a memory
 * bug, but the failure should be a clear message, not a crash. */
static void *axion_xmalloc(long size) {
  void *p = malloc((size_t)size);
  if (!p) {
    fprintf(stderr, "axion: out of memory (failed to allocate %ld bytes)\n", size);
    abort();
  }
  return p;
}

static void *axion_xrealloc(void *ptr, long size) {
  void *q = realloc(ptr, (size_t)size);
  if (!q) {
    fprintf(stderr, "axion: out of memory (failed to reallocate %ld bytes)\n", size);
    abort();
  }
  return q;
}

/* Runs `main` (an i64()-returning function pointer, passed as i64) on a thread
 * with a large, lazily-committed stack (1 GiB), so deep non-tail recursion grows
 * toward RAM instead of overflowing the small default stack — at worst hitting
 * the clean OOM abort. Falls back to a direct call if the thread can't spawn. */
#define AXION_STACK_SIZE (1L << 30) /* 1 GiB */
struct axion_main_arg {
  long (*fn)(void);
  long ret;
};
static void *axion_main_trampoline(void *p) {
  struct axion_main_arg *a = (struct axion_main_arg *)p;
  a->ret = a->fn();
  return NULL;
}
long axion_run_main(long fnptr) {
  struct axion_main_arg a;
  a.fn = (long (*)(void))fnptr;
  a.ret = 0;
  pthread_attr_t attr;
  pthread_t t;
  if (pthread_attr_init(&attr) != 0 ||
      pthread_attr_setstacksize(&attr, AXION_STACK_SIZE) != 0 ||
      pthread_create(&t, &attr, axion_main_trampoline, &a) != 0) {
    a.ret = a.fn(); /* fallback: run on the current stack */
  } else {
    pthread_join(t, NULL);
    pthread_attr_destroy(&attr);
  }
  return a.ret;
}

/* --- heap with a size header (Auto-Drop, §2) ---
 * MOVED TO RUST (axion-rt, Stage 3a, docs/rust-runtime-port.md): axion_alloc/axion_free/
 * axion_block_copy are now the Rust runtime's libc-malloc-based header allocator (`[total][payload]`,
 * byte-identical to the old C, so blocks stay interchangeable). Declared here so the remaining C
 * (arenas, collections, session) can still call them — resolved by linking axion-rt. */
extern long axion_alloc(long size);
extern void axion_free(long ptr);
extern long axion_block_copy(long ptr);

/* --- arbitrary-precision Integer (§Listing 1.4) ---------------------------
 * MOVED TO RUST: the bignum primitives (`axion_bignum_*`) now live in the Rust
 * runtime crate `axion-rt` (reusing axionc's tested `src/bigint.rs`), linked into the
 * --release executable. This deletes the hand-written C `bn_divmod` et al. — the one
 * place a real memory bug shipped. `axion_bignum_to_string` still allocates its String
 * via `axion_alloc` (below), so String reclamation is unchanged. See docs/rust-runtime-port.md. */

/* --- strings / IO + char primitives ---------------------------------------
 * MOVED TO RUST (axion-rt, Stage 2a, docs/rust-runtime-port.md): axion_puts/put/eput/eputs,
 * str_drop, show_int, print_float, show_float, strcat, str_len, str_at, str_cmp, substr.
 * All stdout now flows through the Rust runtime (flushed), so no C/Rust buffer interleaving. */

/* --- OS capability layer (§pass) ------------------------------------------
 * MOVED TO RUST (axion-rt, Stage 2b, docs/rust-runtime-port.md): getEnv, runCapture,
 * runStatus, readFile, writeFile, fileExists, makeDir, removeFile, renameFile, readDir,
 * randHex, readLine, readSecret, execCapture, execStatus, exitWith, setArgs/getArg/getArgs.
 * Now on std::fs / std::process / std::io (fork/exec/pipe/dirent/termios gone from C). */

/* --- arenas (§3) ----------------------------------------------------------
 * MOVED TO RUST (axion-rt, Stage 3b): axion_arena_new/alloc/reset/mark/release/promote —
 * libc-backed bump allocator, same 24-byte Chunk header layout. See docs/rust-runtime-port.md. */

/* --- flat collections (Buffer / Array / TritVec / I8 / I32 + list helpers) ---------
 * MOVED TO RUST (axion-rt, Stage 3c, docs/rust-runtime-port.md): axion_buf_*, axion_array_*,
 * axion_tritvec_*, axion_i8_*, axion_i32_*, list_to_buf/buf_to_list/fold_bytes. Same layouts
 * (Buffer/Array libc-malloc/free; TritVec/I8/I32 axion_alloc/axion_free) and autovectorizable
 * reduction shapes; the base-243 TritVec LUT is now a compile-time const. */

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
  int par;        /* §9 parMap: finish when ALL tasks are done (no single root) */
  int ncompleted; /* §9 parMap: tasks completed so far */
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
    s->eps = (SessEp *)axion_xrealloc(s->eps, (size_t)s->capeps * sizeof(SessEp));
    s->peer = (int *)axion_xrealloc(s->peer, (size_t)s->capeps * sizeof(int));
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
      s->ready = (int *)axion_xrealloc(s->ready, (size_t)s->rcap * sizeof(int));
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
    s->blocked = (int *)axion_xrealloc(s->blocked, (size_t)s->capblocked * sizeof(int));
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
      e->q = (long *)axion_xrealloc(e->q, (size_t)e->cap * sizeof(long));
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
    s->allocs = (void **)axion_xrealloc(s->allocs, (size_t)s->capallocs * sizeof(void *));
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
    s->tasks = (SessTask *)axion_xrealloc(s->tasks, (size_t)s->captasks * sizeof(SessTask));
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
      if (s->par) {
        /* §9 parMap: no distinguished root — finish once every worker is done. */
        if (++s->ncompleted == s->ntasks) s->done = 1;
      } else if (i == 0) {
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
  pthread_t *threads = (pthread_t *)axion_xmalloc((size_t)nthreads * sizeof(pthread_t));
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

/* §9 structured fork-join (parMap): spawn one worker per input, preload each input,
 * run all workers to completion on the thread pool, then collect the replies into a
 * List (Cons/Nil, in input order). The N endpoints live inside this scheduler only.
 * `step` = worker step fn; `state_size` = its state-block size; `ep_slot` = the byte
 * offset of the worker's endpoint parameter. Mirror of the --dev Rust axion_par_map. */
long axion_par_map(long step, long state_size, long ep_slot, long inputs) {
  Sched *s = (Sched *)axion_sess_new();
  s->par = 1;
  long n = 0;
  for (long p = inputs; p && !(p & 1); p = *(long *)(p + 16)) n++;
  long *pep = (long *)axion_xmalloc((size_t)(n > 0 ? n : 1) * sizeof(long));
  long k = 0;
  for (long p = inputs; p && !(p & 1);) {
    long v = *(long *)(p + 8);
    long next = *(long *)(p + 16);
    long a = axion_sess_channel((long)s); /* a = parent end, a+1 = child end */
    long st = axion_sess_alloc((long)s, state_size);
    *(long *)(st + ep_slot) = a + 1;      /* the worker's endpoint parameter */
    axion_sess_send((long)s, a, v);       /* preload the input → worker's first recv */
    axion_sess_spawn((long)s, step, st);
    pep[k++] = a;
    axion_free(p); /* parMap owns the input list — free each cons cell */
    p = next;
  }
  if (n > 0) {
    int nthreads;
    const char *env = getenv("AXION_SESS_THREADS");
    if (env && atoi(env) > 0) {
      nthreads = atoi(env);
    } else {
      long ncpu = sysconf(_SC_NPROCESSORS_ONLN);
      nthreads = (int)(ncpu < 1 ? 1 : (ncpu > 8 ? 8 : ncpu));
    }
    pthread_t *threads = (pthread_t *)axion_xmalloc((size_t)nthreads * sizeof(pthread_t));
    for (int t = 0; t < nthreads; t++) pthread_create(&threads[t], NULL, sess_worker, s);
    for (int t = 0; t < nthreads; t++) pthread_join(threads[t], NULL);
    free(threads);
  }
  long list = 1; /* Nil */
  for (long j = n - 1; j >= 0; j--) {
    long r = axion_sess_recv((long)s, pep[j]);
    long cell = axion_alloc(24);
    *(long *)cell = 1;           /* Cons tag */
    *(long *)(cell + 8) = r;     /* head */
    *(long *)(cell + 16) = list; /* tail */
    list = cell;
  }
  free(pep);
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
  return list;
}

/* --- networking primitives (§FFI) ----------------------------------------- */

/* ax_net_connect(hostname, port) → fd (≥0 on success, -errno on failure). */
long ax_net_connect(long host_ptr, long port) {
  const char *host = (const char *)host_ptr;
  struct addrinfo hints = {.ai_family = AF_UNSPEC, .ai_socktype = SOCK_STREAM};
  struct addrinfo *res = NULL;
  int r = getaddrinfo(host, NULL, &hints, &res);
  if (r != 0 || !res) return -(r ? r : EAI_FAIL);
  int fd = -1;
  for (struct addrinfo *rp = res; rp; rp = rp->ai_next) {
    fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
    if (fd < 0) continue;
    if (rp->ai_family == AF_INET) {
      ((struct sockaddr_in *)rp->ai_addr)->sin_port = htons((uint16_t)port);
    } else {
      ((struct sockaddr_in6 *)rp->ai_addr)->sin6_port = htons((uint16_t)port);
    }
    if (connect(fd, rp->ai_addr, rp->ai_addrlen) == 0) break;
    close(fd);
    fd = -1;
  }
  freeaddrinfo(res);
  return fd >= 0 ? fd : -errno;
}

/* ax_net_listen(port) → fd (listening socket, ≥0 on success). */
long ax_net_listen(long port) {
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) return -errno;
  int opt = 1;
  setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
  struct sockaddr_in addr = {.sin_family = AF_INET,
                              .sin_addr.s_addr = INADDR_ANY,
                              .sin_port = htons((uint16_t)port)};
  if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    int e = errno;
    close(fd);
    return -e;
  }
  if (listen(fd, 128) < 0) {
    int e = errno;
    close(fd);
    return -e;
  }
  return fd;
}

/* ax_net_accept(listen_fd) → client_fd (≥0 on success, blocks). */
long ax_net_accept(long listen_fd) {
  int fd = (int)listen_fd;
  int c = accept(fd, NULL, NULL);
  return c >= 0 ? c : -errno;
}

/* ax_net_send(fd, data_ptr) → bytes sent (or -errno). Uses strlen(data). */
long ax_net_send(long fd, long data_ptr) {
  const char *s = (const char *)data_ptr;
  size_t len = strlen(s);
  ssize_t n = send((int)fd, s, len, MSG_NOSIGNAL);
  return n >= 0 ? (long)n : -errno;
}

/* ax_net_recv(fd) → heap-allocated null-terminated string (or 0 on close/error).
   The returned pointer is compatible with axion_free(). */
long ax_net_recv(long fd) {
  char buf[4096];
  ssize_t n = recv((int)fd, buf, sizeof(buf) - 1, 0);
  if (n <= 0) { long p = axion_alloc(1); *(char *)p = 0; return p; }
  buf[n] = '\0';
  long p = axion_alloc(n + 1);
  memcpy((char *)p, buf, (size_t)n + 1);
  return p;
}

/* ax_net_close(fd) — closes the socket. */
void ax_net_close(long fd) { close((int)fd); }
