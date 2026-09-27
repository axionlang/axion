#!/usr/bin/env python3
"""Echo-server benchmark orchestrator (Axión / Rust / C / Haskell).

For each server: start it, wait until it listens, run a warm-up, then take the MEDIAN of several
timed loadgen trials (N concurrent keep-alive connections × R round-trips each). Identical loadgen
binary + parameters for all four → apples-to-apples. Reports throughput + p50/p99 latency.
"""
import socket, subprocess, sys, time, statistics, os

HERE = os.path.dirname(os.path.abspath(__file__))
N = int(sys.argv[1]) if len(sys.argv) > 1 else 50      # concurrent connections
R = int(sys.argv[2]) if len(sys.argv) > 2 else 500     # requests per connection
SZ = int(sys.argv[3]) if len(sys.argv) > 3 else 32     # message bytes
TRIALS = int(sys.argv[4]) if len(sys.argv) > 4 else 3

SERVERS = [
    ("C (clang -O2, pthread/conn)",      [f"{HERE}/echo_c", "47002"],                 47002),
    ("Rust (rustc -O, thread/conn)",     [f"{HERE}/echo_rust", "47001"],              47001),
    ("Haskell (ghc -O2 -threaded, forkIO)", [f"{HERE}/echo_hs", "47003", "+RTS", "-N"], 47003),
    ("Axion (--release, M:N session)",   [f"{HERE}/echo_axion"],                      47004),
]


def wait_listen(port, timeout=8.0):
    end = time.time() + timeout
    while time.time() < end:
        try:
            socket.create_connection(("127.0.0.1", port), timeout=1).close()
            return True
        except OSError:
            time.sleep(0.05)
    return False


def loadgen(port):
    out = subprocess.run(
        [f"{HERE}/loadgen", str(port), str(N), str(R), str(SZ)],
        capture_output=True, text=True, timeout=120,
    ).stdout.strip()
    # THROUGHPUT <tput> P50 <us> P99 <us> TOTAL <n> ELAPSED <s>
    t = out.split()
    return {"tput": float(t[1]), "p50": int(t[3]), "p99": int(t[5])}


def bench(cmd, port):
    srv = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        if not wait_listen(port):
            return None
        loadgen(port)  # warm-up (discarded)
        trials = [loadgen(port) for _ in range(TRIALS)]
        return {
            "tput": statistics.median(x["tput"] for x in trials),
            "p50": statistics.median(x["p50"] for x in trials),
            "p99": statistics.median(x["p99"] for x in trials),
        }
    finally:
        srv.terminate()
        try:
            srv.wait(timeout=5)
        except subprocess.TimeoutExpired:
            srv.kill()
            srv.wait()
        time.sleep(0.3)


def main():
    print(f"# echo benchmark: N={N} connections x R={R} keep-alive round-trips, {SZ}B msgs, "
          f"median of {TRIALS} trials ({N*R} echoes/trial)\n")
    print(f"{'server':<40}{'throughput (echo/s)':>22}{'p50 (us)':>12}{'p99 (us)':>12}")
    print("-" * 86)
    rows = []
    for name, cmd, port in SERVERS:
        r = bench(cmd, port)
        if r is None:
            print(f"{name:<40}{'FAILED (no listen)':>22}")
            continue
        rows.append((name, r))
        print(f"{name:<40}{r['tput']:>22,.0f}{r['p50']:>12}{r['p99']:>12}")
    print()


if __name__ == "__main__":
    main()
