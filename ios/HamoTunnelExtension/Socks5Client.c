//
//  Socks5Client.c
//  HamoTunnelExtension
//
//  SOCKS5 Client for direct connections (used by SSH Special protocol)
//

#include "HamoTunnelExtension-Bridging-Header.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <errno.h>

// Thread-local storage for SOCKS connections
__thread int tls_socks_fd = -1;

static int socks5_handshake(int fd) {
    uint8_t greeting[] = {0x05, 0x01, 0x00};
    if (write(fd, greeting, 3) != 3) return -1;
    
    uint8_t response[2];
    if (read(fd, response, 2) != 2) return -1;
    if (response[0] != 0x05 || response[1] != 0x00) return -1;
    
    return 0;
}

static int socks5_connect(int fd, const char* target_host, uint16_t target_port) {
    size_t host_len = strlen(target_host);
    if (host_len > 255) return -1;
    
    uint8_t request[256];
    request[0] = 0x05;
    request[1] = 0x01;
    request[2] = 0x00;
    request[3] = 0x03; // Domain name
    request[4] = (uint8_t)host_len;
    memcpy(&request[5], target_host, host_len);
    request[5 + host_len] = (target_port >> 8) & 0xFF;
    request[5 + host_len + 1] = target_port & 0xFF;
    size_t req_len = 5 + host_len + 2;
    
    if (write(fd, request, req_len) != (ssize_t)req_len) return -1;
    
    uint8_t response[4];
    if (read(fd, response, 4) != 4) return -1;
    if (response[0] != 0x05 || response[1] != 0x00) return -1;
    
    // Skip bound address
    if (response[3] == 0x01) { // IPv4
        char addr[6];
        read(fd, addr, 6);
    } else if (response[3] == 0x03) { // Domain
        uint8_t addr_len;
        read(fd, &addr_len, 1);
        char addr[256];
        read(fd, addr, addr_len + 2);
    } else if (response[3] == 0x04) { // IPv6
        char addr[18];
        read(fd, addr, 18);
    }
    
    return 0;
}

static int connect_socks_proxy(const char* proxy_host, uint16_t proxy_port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(proxy_port);
    inet_pton(AF_INET, proxy_host, &addr.sin_addr);
    
    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(fd);
        return -1;
    }
    
    return fd;
}

// C API implementations

int Socks5Connect(const char* host, uint16_t port) {
    // Use global SOCKS proxy (from Xray)
    const char* proxy_host = "127.0.0.1";
    uint16_t proxy_port = 10808;
    
    int fd = connect_socks_proxy(proxy_host, proxy_port);
    if (fd < 0) return -1;
    
    if (socks5_handshake(fd) < 0) {
        close(fd);
        return -1;
    }
    
    if (socks5_connect(fd, host, port) < 0) {
        close(fd);
        return -1;
    }
    
    tls_socks_fd = fd;
    return fd;
}

int Socks5Write(const uint8_t* data, size_t len) {
    if (tls_socks_fd < 0) return -1;
    
    ssize_t written = write(tls_socks_fd, data, len);
    return (written == (ssize_t)len) ? (int)len : -1;
}

int Socks5Read(uint8_t* buffer, size_t len) {
    if (tls_socks_fd < 0) return -1;
    
    ssize_t n = read(tls_socks_fd, buffer, len);
    return (n > 0) ? (int)n : -1;
}

void Socks5Close(void) {
    if (tls_socks_fd >= 0) {
        close(tls_socks_fd);
        tls_socks_fd = -1;
    }
}