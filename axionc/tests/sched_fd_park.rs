//! Stage 1 of the async-sockets arc (docs/async-sockets.md): the session scheduler's fd-park + poll
//! path. A worker whose step gets `ax_net_wouldblock()` from a non-blocking recv registers its fd
//! via `axion_sess_park_fd` and returns 0 (blocked); the scheduler must NOT treat that as a deadlock
//! (as it would for a channel-blocked task with nothing running) but instead `poll` the fd and
//! resume the task on readiness. This drives that end to end through the REAL scheduler: a reader
//! task parks on a loopback socket, a background thread sends after a delay, and `poll` wakes it.
//!
//! If fd-park were misrouted to the channel-`blocked` list, the scheduler would declare "no progress
//! (deadlock)" and `process::exit(1)`, killing the test binary — so a clean pass is a strong signal.
#![cfg(feature = "native")]
#![allow(clippy::unwrap_used, clippy::expect_used, unsafe_code, missing_docs)]
#![allow(
    clippy::cast_possible_truncation,
    clippy::cast_sign_loss,
    clippy::cast_possible_wrap,
    clippy::undocumented_unsafe_blocks
)]

use std::ffi::CString;
use std::sync::atomic::{AtomicUsize, Ordering};

// How many times the reader step was entered. It must be ≥ 2: once returning the would-block
// sentinel (parked), then again after `poll` resumes it (data ready) — proof it genuinely parked.
static ENTRIES: AtomicUsize = AtomicUsize::new(0);

// State block: [0] = result flag, [16] = the socket fd. (8 is the conventional resume slot, unused.)
extern "C" fn reader_step(sched_p: i64, state: i64) -> i64 {
    ENTRIES.fetch_add(1, Ordering::SeqCst);
    unsafe {
        let fd = *((state + 16) as *const i64);
        let r = axion_rt::ax_net_recv(fd);
        if r == axion_rt::AX_NET_WOULDBLOCK {
            axion_rt::axion_sess_park_fd(sched_p, fd, 0);
            return 0; // blocked on fd → the scheduler must poll, not deadlock
        }
        if r != 0 {
            axion_rt::axion_str_drop(r); // free the recv'd String (or the "" on close)
        }
        *(state as *mut i64) = 1; // result: the reader completed after being woken
        1
    }
}

#[test]
fn scheduler_parks_a_worker_on_a_socket_fd_and_poll_wakes_it() {
    unsafe {
        // Loopback socket pair.
        let (mut listen_fd, mut port) = (-1i64, 0i64);
        for p in 45_301..45_501 {
            let fd = axion_rt::ax_net_listen(p);
            if fd >= 0 {
                listen_fd = fd;
                port = p;
                break;
            }
        }
        assert!(listen_fd >= 0, "could not bind a loopback listener");
        let host = CString::new("127.0.0.1").unwrap();
        let client_fd = axion_rt::ax_net_connect(host.as_ptr() as i64, port);
        assert!(client_fd >= 0, "connect failed: {client_fd}");
        // spin accept (loopback connect completes into the backlog immediately).
        let mut server_fd = -1i64;
        for _ in 0..10_000 {
            let c = axion_rt::ax_net_accept(listen_fd);
            if c >= 0 {
                server_fd = c;
                break;
            }
        }
        assert!(server_fd >= 0, "accept failed");
        assert_eq!(axion_rt::ax_net_set_nonblocking(server_fd), 0);
        axion_rt::ax_net_close(listen_fd);

        // Background sender: wait long enough that the reader's FIRST recv must park, then send.
        let sender = std::thread::spawn(move || {
            std::thread::sleep(std::time::Duration::from_millis(60));
            let msg = CString::new("hello").unwrap();
            axion_rt::ax_net_send(client_fd, msg.as_ptr() as i64);
        });

        ENTRIES.store(0, Ordering::SeqCst);
        let sp = axion_rt::axion_sess_new();
        let st = axion_rt::axion_sess_alloc(sp, 32);
        *((st + 16) as *mut i64) = server_fd;
        let result = axion_rt::axion_sess_run(sp, reader_step as *const () as i64, st);

        sender.join().unwrap();
        assert_eq!(
            result, 1,
            "reader should complete after poll wakes it on socket readiness"
        );
        assert!(
            ENTRIES.load(Ordering::SeqCst) >= 2,
            "reader must have parked at least once then resumed (entries = {})",
            ENTRIES.load(Ordering::SeqCst)
        );
        axion_rt::ax_net_close(client_fd);
        axion_rt::ax_net_close(server_fd);
    }
}
