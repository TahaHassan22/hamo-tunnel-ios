//
//  HamoTunnelExtension-Bridging-Header.h
//  HamoTunnelExtension
//
//  Bridging header for C/C++ libraries (libxray, TUN2SOCKS, SOCKS5)
//

#ifndef HamoTunnelExtension_Bridging_Header_h
#define HamoTunnelExtension_Bridging_Header_h

#ifdef __cplusplus
extern "C" {
#endif

// libxray C API (from libxray-apple-cgo)
int XrayStart(const char* config_base64);
void XrayStop(void);
int XrayWritePacket(const uint8_t* data, size_t len);
int XrayUpdateConfig(const char* config_base64);
int XrayGetStats(int64_t* sent, int64_t* received);
void XraySetPacketCallback(void (*callback)(const uint8_t*, size_t));
const char* XrayVersion(void);

// TUN2SOCKS Bridge C API
int Tun2SocksInit(const char* socks_host, uint16_t socks_port);
void Tun2SocksCleanup(void);
int Tun2SocksWritePacket(const uint8_t* data, size_t len);
int Tun2SocksSetPacketCallback(void (*callback)(const uint8_t*, size_t));

// SOCKS5 Client C API
int Socks5Connect(const char* host, uint16_t port);
int Socks5Write(const uint8_t* data, size_t len);
int Socks5Read(uint8_t* buffer, size_t len);
void Socks5Close(void);

#ifdef __cplusplus
}
#endif

#endif /* HamoTunnelExtension_Bridging_Header_h */