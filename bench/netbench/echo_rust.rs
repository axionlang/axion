// Concurrent keep-alive TCP echo server — Rust, thread-per-connection (std, idiomatic simple).
// Mirrors the Axión server's model: one lightweight unit of concurrency per connection.
use std::io::{Read, Write};
use std::net::TcpListener;

fn main() {
    let port: u16 = std::env::args().nth(1).unwrap().parse().unwrap();
    let l = TcpListener::bind(("127.0.0.1", port)).unwrap();
    for stream in l.incoming() {
        let Ok(mut s) = stream else { continue };
        s.set_nodelay(true).ok();
        std::thread::spawn(move || {
            let mut buf = [0u8; 4096];
            loop {
                match s.read(&mut buf) {
                    Ok(0) | Err(_) => break,
                    Ok(n) => {
                        if s.write_all(&buf[..n]).is_err() {
                            break;
                        }
                    }
                }
            }
        });
    }
}
