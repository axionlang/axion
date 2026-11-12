//! Stage 2 of the async-sockets arc (docs/async-sockets.md): the typed linear `Sock`/`Listener`
//! surface, end-to-end on the interpreter. Two halves:
//!
//! 1. RUNTIME: an Axión client using the `%1`-linear `Sock` handler pattern
//!    (`netConnect`/`netSend`/`netRecv`/`netClose`) round-trips against a background std echo
//!    server — proving the interpreter's `net*` builtins work end to end.
//! 2. SAFETY: the linear checker enforces close-exactly-once on a `Sock %1` — forgetting `netClose`
//!    is AX0002 (must-use), double `netClose` is AX0001 (contraction), and using the socket after
//!    close is AX0004 (use-after-move). This is the compile-time guarantee the `Sock` type buys.
#![cfg(feature = "native")]
#![allow(clippy::unwrap_used, clippy::expect_used, let_underscore_drop)]

use std::io::{Read, Write};
use std::net::TcpListener;
use std::process::Command;

fn axionc() -> Command {
    Command::new(env!("CARGO_BIN_EXE_axionc"))
}

/// Write `src` to a unique temp `.axi` file and return its path.
fn temp_axi(tag: &str, src: &str) -> std::path::PathBuf {
    let p = std::env::temp_dir().join(format!("axion_net_{tag}_{}.axi", std::process::id()));
    std::fs::write(&p, src).unwrap();
    p
}

#[test]
fn sock_client_round_trips_against_a_background_echo_server_on_the_interpreter() {
    // Background echo server on an ephemeral port; handle exactly one connection.
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    let server = std::thread::spawn(move || {
        let (mut conn, _) = listener.accept().unwrap();
        let mut buf = [0u8; 64];
        let n = conn.read(&mut buf).unwrap();
        conn.write_all(&buf[..n]).unwrap();
        // drop(conn) closes it after echoing.
    });

    // Client: the safe %1-linear Sock handler pattern (netClose consumes the socket exactly once).
    let src = format!(
        "handler :: Sock %1 -> IO ()\n\
         handler s =\n\
        \x20 case netSend s \"ping\" of\n\
        \x20   _ ->\n\
        \x20     case netRecv s of\n\
        \x20       resp ->\n\
        \x20         case netClose s of\n\
        \x20           _ -> putStr resp\n\
         main :: IO ()\n\
         main = handler (netConnect \"127.0.0.1\" {port})\n"
    );
    let path = temp_axi("client", &src);
    let out = axionc().arg(&path).output().unwrap();
    server.join().unwrap();
    let _ = std::fs::remove_file(&path);

    assert!(
        out.status.success(),
        "client run failed: {}",
        String::from_utf8_lossy(&out.stderr)
    );
    assert_eq!(
        String::from_utf8_lossy(&out.stdout),
        "ping",
        "the echoed payload should come back through the Sock round-trip"
    );
}

/// Compile-only: assert the given source is REJECTED with the given diagnostic code.
fn assert_rejected(tag: &str, code: &str, src: &str) {
    let path = temp_axi(tag, src);
    let out = axionc()
        .args(["--emit", "core"])
        .arg(&path)
        .output()
        .unwrap();
    let _ = std::fs::remove_file(&path);
    let stderr = String::from_utf8_lossy(&out.stderr);
    let stdout = String::from_utf8_lossy(&out.stdout);
    assert!(
        stderr.contains(code) || stdout.contains(code),
        "expected {code} for {tag}, got:\nstdout={stdout}\nstderr={stderr}"
    );
}

#[test]
fn linear_sock_enforces_close_exactly_once() {
    // Forgetting to close a %1 Sock: must-use (AX0002).
    assert_rejected(
        "noclose",
        "AX0002",
        "handler :: Sock %1 -> IO ()\n\
         handler s = case netRecv s of\n  msg -> putStr msg\n\
         main :: IO ()\nmain = handler (netConnect \"127.0.0.1\" 1)\n",
    );
    // Closing twice: contraction (AX0001).
    assert_rejected(
        "double",
        "AX0001",
        "handler :: Sock %1 -> IO ()\n\
         handler s = case netClose s of\n  _ -> netClose s\n\
         main :: IO ()\nmain = handler (netConnect \"127.0.0.1\" 1)\n",
    );
    // Using the socket after close: use-after-move (AX0004).
    assert_rejected(
        "uaf",
        "AX0004",
        "handler :: Sock %1 -> IO ()\n\
         handler s = case netClose s of\n  _ -> netSend s \"late\"\n\
         main :: IO ()\nmain = handler (netConnect \"127.0.0.1\" 1)\n",
    );
}

#[test]
fn fresh_sockets_are_tracked_from_their_binding() {
    // A socket from netAccept/netConnect/netListen bound by a `do` bind or a `let` is checked
    // where it is bound, not only once it reaches a `%1` parameter.
    let wrap = |body: &str| {
        format!("serve :: Listener -> IO ()\nserve l = {body}\nmain :: Int\nmain = 0\n")
    };
    let cases = [
        ("bind_leak", "AX0002", wrap("do\n  s <- netAccept l\n  putStr \"\"")),
        ("bind_double", "AX0001", wrap("do\n  s <- netAccept l\n  netClose s\n  netClose s")),
        ("bind_wild", "AX0002", wrap("do\n  _ <- netAccept l\n  putStr \"\"")),
        ("stmt_discard", "AX0002", wrap("do\n  netAccept l\n  putStr \"\"")),
        ("bind_uaf", "AX0004", wrap("do\n  s <- netAccept l\n  netClose s\n  _ <- netSend s \"late\"\n  putStr \"\"")),
        ("let_leak", "AX0002", wrap("let s = netAccept l in putStr \"\"")),
        ("do_let_leak", "AX0002", wrap("do\n  let s = netAccept l\n  putStr \"\"")),
        ("let_branch", "AX0002", "serve :: Listener -> Int -> IO ()\nserve l n = let s = netAccept l in if n == 0 then netClose s else putStr \"\"\nmain :: Int\nmain = 0\n".to_string()),
        ("listen_leak", "AX0002", "go :: Int -> Int\ngo p = let l = netListen p in 0\nmain :: Int\nmain = 0\n".to_string()),
        ("connect_double", "AX0001", "go :: Int -> IO ()\ngo p = let s = netConnect \"h\" p in do\n  netClose s\n  netClose s\nmain :: Int\nmain = 0\n".to_string()),
    ];
    for (tag, code, src) in &cases {
        assert_rejected(tag, code, src);
    }
    // The correct shapes still compile: close it, or hand it to a `%1` handler.
    for (tag, src) in [
        ("ok_bind", wrap("do\n  s <- netAccept l\n  msg <- netRecv s\n  _ <- netSend s msg\n  netClose s")),
        ("ok_let", wrap("let s = netAccept l in netClose s")),
        (
            "ok_handoff",
            "handler :: Sock %1 -> IO ()\nhandler s = netClose s\nserve :: Listener -> IO ()\nserve l = do\n  s <- netAccept l\n  _ <- spawn (handler s)\n  serve l\nmain :: Int\nmain = 0\n".to_string(),
        ),
    ] {
        let path = temp_axi(tag, &src);
        let out = axionc().arg("--check").arg(&path).output().unwrap();
        let _ = std::fs::remove_file(&path);
        assert!(
            out.status.success(),
            "{tag} must compile: {}{}",
            String::from_utf8_lossy(&out.stdout),
            String::from_utf8_lossy(&out.stderr)
        );
    }
}
