//! Stage 3 of the async-sockets arc (docs/async-sockets.md): a native async socket server. An
//! Axión server built from a `bound $ do` session — `netListen`/`netAccept`/`netRecv`/`netSend`
//! compiled by `SessGen` into suspension points that park the fd — handles a real TCP client. We
//! spawn the compiled server as a subprocess, connect a std client, and assert the echo.
#![cfg(feature = "native")]
#![allow(clippy::unwrap_used, clippy::expect_used, let_underscore_drop)]

use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::process::{Child, Command};
use std::time::{Duration, Instant};

fn axionc() -> Command {
    Command::new(env!("CARGO_BIN_EXE_axionc"))
}

/// A free localhost port (bind :0, read it, drop the listener).
fn free_port() -> u16 {
    TcpListener::bind("127.0.0.1:0")
        .unwrap()
        .local_addr()
        .unwrap()
        .port()
}

/// Connect with retry until the server is up (or ~5s elapse).
fn connect_retry(port: u16) -> TcpStream {
    let deadline = Instant::now() + Duration::from_secs(5);
    loop {
        if let Ok(s) = TcpStream::connect(("127.0.0.1", port)) {
            return s;
        }
        assert!(Instant::now() < deadline, "server never came up on {port}");
        std::thread::sleep(Duration::from_millis(50));
    }
}

/// Kill + reap the server child on drop.
struct Kill(Child);
impl Drop for Kill {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

fn run_echo_server(backend: &[&str]) {
    let port = free_port();
    let src = format!(
        "main :: Int\n\
         main = bound $ do\n\
        \x20 l <- netListen {port}\n\
        \x20 s <- netAccept l\n\
        \x20 msg <- netRecv s\n\
        \x20 _ <- netSend s msg\n\
        \x20 _ <- netClose s\n\
        \x20 _ <- netCloseL l\n\
        \x20 0\n"
    );
    let path = std::env::temp_dir().join(format!("axion_echo_{}_{port}.axi", std::process::id()));
    std::fs::write(&path, src).unwrap();

    let child = axionc().args(backend).arg(&path).spawn().unwrap();
    let _guard = Kill(child);

    let mut s = connect_retry(port);
    s.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
    s.write_all(b"hello-axion").unwrap();
    let mut buf = [0u8; 64];
    let n = s.read(&mut buf).unwrap();
    let _ = std::fs::remove_file(&path);
    assert_eq!(&buf[..n], b"hello-axion", "server should echo the payload");
}

#[test]
fn native_cranelift_echo_server_handles_a_client() {
    run_echo_server(&["--backend", "cranelift"]);
}

#[test]
fn native_release_echo_server_handles_a_client() {
    // `--release` compiles a standalone binary via clang + the axion-rt staticlib (LTO); the same
    // net-op suspension state machine, on the LLVM backend.
    run_echo_server(&["--release"]);
}
