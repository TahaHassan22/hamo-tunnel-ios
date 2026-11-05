//
//  Tun2SocksBridge.h
//  HamoTunnelExtension
//
//  Bridging header for C libraries:
//  - libxray-apple-cgo (Xray core)
//  - libhev-socks5-tunnel (TUN2SOCKS bridge)
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

// hev-socks5-tunnel C API (from libhev-socks5-tunnel.a)
// This is the TUN2SOCKS bridge: iOS TUN <-> SOCKS5 proxy (Xray)
int HevSocks5TunnelInit(const char* socks_host, uint16_t socks_port);
void HevSocks5TunnelCleanup(void);
int HevSocks5TunnelWritePacket(const uint8_t* data, size_t len);
void HevSocks5TunnelSetPacketCallback(void (*callback)(const uint8_t*, size_t));

#ifdef __cplusplus
}
#endif

#endif /* Tun2SocksBridge_h */