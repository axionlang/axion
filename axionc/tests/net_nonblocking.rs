//! Stage 0 of the async-sockets arc (docs/async-sockets.md): the runtime's non-blocking net ops.
//!
//! This drives the `axion_rt::ax_net_*` primitives directly (no Axión surface yet — that is Stage 2)
//! over a loopback socket, and asserts the make-or-break contract: when an `O_NONBLOCK` socket would
//! block, accept/recv return the `ax_net_wouldblock()` sentinel (i64::MIN) instead of blocking, and a
//! full ping/pong still round-trips once data is ready. The sentinel is what the scheduler (Stage 1)
//! will park on and the compiler (Stage 3) will compare against.
#![cfg(feature = "native")]
#![allow(clippy::unwrap_used, clippy::expect_used, unsafe_code, missing_docs)]
#![allow(
    clippy::cast_possible_truncation,
    clippy::cast_sign_loss,
    clippy::similar_names,
    clippy::undocumented_unsafe_blocks
)]

use std::ffi::CString;

/// Read an Axión String (pointer to UTF-8 bytes; length in an 8-byte header) into a Rust String,
/// then free it via the runtime's own deallocator — so the test itself is leak-clean.
unsafe fn take_str(ptr: i64) -> String {
    let len = axion_rt::axion_str_len(ptr) as usize;
    let bytes = std::slice::from_raw_parts(ptr as *const u8, len).to_vec();
    axion_rt::axion_str_drop(ptr);
    String::from_utf8(bytes).unwrap()
}

/// Spin a non-blocking op until it returns something other than the would-block sentinel, counting
/// the parks. Panics if it never becomes ready (guards against a hang turning into a green test).
unsafe fn spin<F: FnMut() -> i64>(mut op: F) -> (i64, u32) {
    let wb = axion_rt::ax_net_wouldblock();
    let mut parks = 0u32;
    for _ in 0..100_000 {
        let r = op();
        if r != wb {
            return (r, parks);
        }
        parks += 1;
        std::thread::sleep(std::time::Duration::from_micros(50));
    }
    panic!("op never became ready (parked {parks} times)");
}

#[test]
fn nonblocking_loopback_echo_round_trips_and_surfaces_the_wouldblock_sentinel() {
    unsafe {
        let wb = axion_rt::ax_net_wouldblock();
        assert_eq!(wb, i64::MIN, "the would-block sentinel is i64::MIN");

        // Bind a listener on the first free port in a private range.
        let mut listen_fd = -1i64;
        let mut port = 0i64;
        for p in 45_071..45_271 {
            let fd = axion_rt::ax_net_listen(p);
            if fd >= 0 {
                listen_fd = fd;
                port = p;
                break;
            }
        }
        assert!(listen_fd >= 0, "could not bind a loopback listener");
        assert_eq!(axion_rt::ax_net_set_nonblocking(listen_fd), 0);

        // With no connection pending, a non-blocking accept must return the sentinel, not block.
        assert_eq!(
            axion_rt::ax_net_accept(listen_fd),
            wb,
            "non-blocking accept with no pending connection must return the would-block sentinel"
        );

        // Connect the client, then accept the server side.
        let host = CString::new("127.0.0.1").unwrap();
        let client_fd = axion_rt::ax_net_connect(host.as_ptr() as i64, port);
        assert!(client_fd >= 0, "connect failed: {client_fd}");
        let (server_fd, accept_parks) = spin(|| axion_rt::ax_net_accept(listen_fd));
        assert!(server_fd >= 0, "accept failed: {server_fd}");
        assert_eq!(axion_rt::ax_net_set_nonblocking(server_fd), 0);
        assert_eq!(axion_rt::ax_net_set_nonblocking(client_fd), 0);

        // Server has no data yet → recv must return the sentinel (park), NOT "" (orderly close).
        assert_eq!(
            axion_rt::ax_net_recv(server_fd),
            wb,
            "non-blocking recv with no data must return the would-block sentinel, not \"\""
        );

        // client → server: "ping"
        let ping = CString::new("ping").unwrap();
        assert_eq!(axion_rt::ax_net_send(client_fd, ping.as_ptr() as i64), 4);
        let (msg_ptr, _) = spin(|| axion_rt::ax_net_recv(server_fd));
        assert_eq!(take_str(msg_ptr), "ping");

        // server → client: "pong"
        let pong = CString::new("pong").unwrap();
        assert_eq!(axion_rt::ax_net_send(server_fd, pong.as_ptr() as i64), 4);
        let (reply_ptr, _) = spin(|| axion_rt::ax_net_recv(client_fd));
        assert_eq!(take_str(reply_ptr), "pong");

        // NOTE: the non-blocking path is proven by the two explicit `== wb` assertions above
        // (accept-with-no-connection and recv-with-no-data both returned the sentinel rather than
        // blocking). On loopback the retry `spin`s then succeed immediately, so their park counts
        // are incidental and deliberately not asserted.
        let _ = accept_parks;

        axion_rt::ax_net_close(client_fd);
        axion_rt::ax_net_close(server_fd);
        axion_rt::ax_net_close(listen_fd);
    }
}
