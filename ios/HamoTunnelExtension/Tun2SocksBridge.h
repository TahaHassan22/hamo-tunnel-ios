//
//  Tun2SocksBridge.h
//  HamoTunnelExtension
//
//  Bridging header for C libraries:
//  - libxray-apple-cgo (Xray core)
//  - HevSocks5Tunnel.xcframework (TUN2SOCKS bridge)
//  - libxray C API
//

#ifndef Tun2SocksBridge_h
#define Tun2SocksBridge_h

#ifdef __cplusplus
extern "C" {
#endif

// libxray C API (from libxray-apple-cgo.xcframework)
int XrayStart(const char* config_base64);
void XrayStop(void);
int XrayWritePacket(const uint8_t* data, size_t len);
int XrayUpdateConfig(const char* config_base64);
int XrayGetStats(int64_t* sent, int64_t* received);
const char* XrayVersion(void);

// hev-socks5-tunnel C API (from HevSocks5Tunnel.xcframework)
// This is the TUN2SOCKS bridge: iOS TUN <-> SOCKS5 proxy (Xray)
// Upstream API from src/hev-socks5-tunnel.h:
//   int hev_socks5_tunnel_main(const char *config_path, int tun_fd);
//   int hev_socks5_tunnel_main_from_str(const unsigned char *config_str, unsigned int config_len, int tun_fd);
//   void hev_socks5_tunnel_quit(void);
//   int hev_socks5_tunnel_stats(unsigned long long *rx_bytes, unsigned long long *tx_bytes);
int hev_socks5_tunnel_main_from_str(const unsigned char *config_str, unsigned int config_len, int tun_fd);
void hev_socks5_tunnel_quit(void);
int hev_socks5_tunnel_stats(unsigned long long *rx_bytes, unsigned long long *tx_bytes);

#ifdef __cplusplus
}
#endif

#endif /* Tun2SocksBridge_h */