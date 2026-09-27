/* Concurrent keep-alive TCP echo server — C, pthread-per-connection (idiomatic simple). */
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

static void *handle(void *arg) {
    int fd = (int)(long)arg;
    char buf[4096];
    for (;;) {
        ssize_t n = recv(fd, buf, sizeof buf, 0);
        if (n <= 0) break;
        ssize_t off = 0;
        while (off < n) {
            ssize_t w = send(fd, buf + off, (size_t)(n - off), 0);
            if (w <= 0) { close(fd); return NULL; }
            off += w;
        }
    }
    close(fd);
    return NULL;
}

int main(int argc, char **argv) {
    int port = atoi(argv[1]);
    int lfd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(lfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof opt);
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof addr);
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons((unsigned short)port);
    if (bind(lfd, (struct sockaddr *)&addr, sizeof addr) < 0) return 1;
    if (listen(lfd, 512) < 0) return 1;
    for (;;) {
        int cfd = accept(lfd, NULL, NULL);
        if (cfd < 0) continue;
        int one = 1;
        setsockopt(cfd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof one);
        pthread_t t;
        if (pthread_create(&t, NULL, handle, (void *)(long)cfd) == 0)
            pthread_detach(t);
        else
            close(cfd);
    }
    return 0;
}
