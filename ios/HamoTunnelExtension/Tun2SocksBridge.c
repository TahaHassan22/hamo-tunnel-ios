//
//  Tun2SocksBridge.c
//  HamoTunnelExtension
//
//  TUN2SOCKS Bridge - forwards IP packets from iOS TUN to Xray SOCKS proxy
//  Based on simple TCP relay logic (similar to badvpn/tun2socks)
//

#include "HamoTunnelExtension-Bridging-Header.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <errno.h>

// Global state
static int g_socks_fd = -1;
static pthread_t g_relay_thread = 0;
static volatile int g_running = 0;
static void (*g_packet_callback)(const uint8_t*, size_t) = NULL;
static pthread_mutex_t g_callback_mutex = PTHREAD_MUTEX_INITIALIZER;
static char g_socks_host[256] = "127.0.0.1";
static uint16_t g_socks_port = 10808;

// SOCKS5 handshake and relay
static int socks5_handshake(int fd) {
    // SOCKS5 greeting: version=5, nmethods=1, method=0 (no auth)
    uint8_t greeting[] = {0x05, 0x01, 0x00};
    if (write(fd, greeting, 3) != 3) return -1;
    
    uint8_t response[2];
    if (read(fd, response, 2) != 2) return -1;
    if (response[0] != 0x05 || response[1] != 0x00) return -1;
    
    return 0;
}

static int socks5_connect(int fd, const char* target_host, uint16_t target_port) {
    // SOCKS5 connect request
    // version=5, cmd=1 (connect), rsv=0, atyp=3 (domain name)
    size_t host_len = strlen(target_host);
    uint8_t request[256];
    request[0] = 0x05;  // version
    request[1] = 0x01;  // cmd = CONNECT
    request[2] = 0x00;  // reserved
    request[3] = 0x03;  // atyp = domain name
    request[4] = (uint8_t)host_len;
    memcpy(&request[5], target_host, host_len);
    request[5 + host_len] = (target_port >> 8) & 0xFF;
    request[5 + host_len + 1] = target_port & 0xFF;
    size_t req_len = 5 + host_len + 2;
    
    if (write(fd, request, req_len) != (ssize_t)req_len) return -1;
    
    // Read response (at least 10 bytes for domain)
    uint8_t response[256];
    ssize_t n = read(fd, response, 10);
    if (n < 10) return -1;
    
    if (response[0] != 0x05 || response[1] != 0x00) return -1;
    
    // Skip address in response
    if (response[3] == 0x01) { // IPv4
        read(fd, response, 6); // 4 bytes IP + 2 bytes port
    } else if (response[3] == 0x03) { // Domain
        uint8_t addr_len;
        read(fd, &addr_len, 1);
        read(fd, response, addr_len + 2);
    } else if (response[3] == 0x04) { // IPv6
        read(fd, response, 18);
    }
    
    return 0;
}

static int connect_to_socks() {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(g_socks_port);
    inet_pton(AF_INET, g_socks_host, &addr.sin_addr);
    
    // Set non-blocking
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    
    int ret = connect(fd, (struct sockaddr*)&addr, sizeof(addr));
    if (ret < 0 && errno != EINPROGRESS) {
        close(fd);
        return -1;
    }
    
    // Wait for connection with select
    fd_set wfds;
    FD_ZERO(&wfds);
    FD_SET(fd, &wfds);
    struct timeval tv = {10, 0};
    ret = select(fd + 1, NULL, &wfds, NULL, &tv);
    if (ret <= 0) {
        close(fd);
        return -1;
    }
    
    // Check connection result
    int error = 0;
    socklen_t len = sizeof(error);
    getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &len);
    if (error != 0) {
        close(fd);
        return -1;
    }
    
    // Set back to blocking
    fcntl(fd, F_SETFL, flags);
    
    // SOCKS5 handshake
    if (socks5_handshake(fd) < 0) {
        close(fd);
        return -1;
    }
    
    return fd;
}

// Thread function to relay packets from SOCKS to callback
static void* relay_thread_func(void* arg) {
    uint8_t buffer[65536];
    
    while (g_running && g_socks_fd >= 0) {
        fd_set rfds;
        FD_ZERO(&rfds);
        FD_SET(g_socks_fd, &rfds);
        
        struct timeval tv = {1, 0};
        int ret = select(g_socks_fd + 1, &rfds, NULL, NULL, &tv);
        
        if (ret > 0 && FD_ISSET(g_socks_fd, &rfds)) {
            ssize_t n = read(g_socks_fd, buffer, sizeof(buffer));
            if (n > 0) {
                pthread_mutex_lock(&g_callback_mutex);
                if (g_packet_callback) {
                    g_packet_callback(buffer, n);
                }
                pthread_mutex_unlock(&g_callback_mutex);
            } else if (n == 0) {
                // Connection closed
                break;
            } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
                break;
            }
        }
    }
    
    return NULL;
}

// C API implementations

int Tun2SocksInit(const char* socks_host, uint16_t socks_port) {
    if (g_running) return -1;
    
    strncpy(g_socks_host, socks_host, sizeof(g_socks_host) - 1);
    g_socks_port = socks_port;
    
    g_socks_fd = connect_to_socks();
    if (g_socks_fd < 0) {
        return -1;
    }
    
    g_running = 1;
    if (pthread_create(&g_relay_thread, NULL, relay_thread_func, NULL) != 0) {
        close(g_socks_fd);
        g_socks_fd = -1;
        g_running = 0;
        return -1;
    }
    
    return 0;
}

void Tun2SocksCleanup(void) {
    g_running = 0;
    
    if (g_relay_thread) {
        pthread_join(g_relay_thread, NULL);
        g_relay_thread = 0;
    }
    
    if (g_socks_fd >= 0) {
        close(g_socks_fd);
        g_socks_fd = -1;
    }
}

int Tun2SocksWritePacket(const uint8_t* data, size_t len) {
    if (!g_running || g_socks_fd < 0) return -1;
    
    // Write packet to SOCKS connection
    // For SOCKS5, we need to wrap in a simple framing or use UDP associate
    // For simplicity, we write directly (assuming TCP stream)
    // In production, use SOCKS5 UDP ASSOCIATE for proper UDP support
    
    ssize_t written = write(g_socks_fd, data, len);
    return (written == (ssize_t)len) ? 0 : -1;
}

int Tun2SocksSetPacketCallback(void (*callback)(const uint8_t*, size_t)) {
    pthread_mutex_lock(&g_callback_mutex);
    g_packet_callback = callback;
    pthread_mutex_unlock(&g_callback_mutex);
    return 0;
}

// SOCKS5 Client API

int Socks5Connect(const char* host, uint16_t port) {
    int fd = connect_to_socks();
    if (fd < 0) return -1;
    
    if (socks5_connect(fd, host, port) < 0) {
        close(fd);
        return -1;
    }
    
    return fd;
}

int Socks5Write(const uint8_t* data, size_t len) {
    // This would use a stored fd in production
    return -1;
}

int Socks5Read(uint8_t* buffer, size_t len) {
    return -1;
}

void Socks5Close(void) {
    // Close stored fd
}