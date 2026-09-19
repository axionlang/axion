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
    let out = axionc().args(["--emit", "core"]).arg(&path).output().unwrap();
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
