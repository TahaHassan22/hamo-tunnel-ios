//
//  XrayBridge.c
//  HamoTunnelExtension
//
//  C bridge between Swift and libxray C API
//  Provides the XrayStart, XrayStop, XrayWritePacket, etc. functions
//  These are thin wrappers that call the actual libxray functions from the xcframework
//

#include "HamoTunnelExtension-Bridging-Header.h"
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

// Global state for packet callback
static void (*g_xray_packet_callback)(const uint8_t*, size_t) = NULL;
static pthread_mutex_t g_xray_callback_mutex = PTHREAD_MUTEX_INITIALIZER;

// These functions are provided by libxray-apple-cgo.xcframework
// The actual implementations are in the xcframework
extern int libxray_start(const char* config_base64);
extern void libxray_stop(void);
extern int libxray_write_packet(const uint8_t* data, size_t len);
extern int libxray_update_config(const char* config_base64);
extern int libxray_get_stats(int64_t* sent, int64_t* received);
extern void libxray_set_packet_callback(void (*callback)(const uint8_t*, size_t));
extern const char* libxray_version(void);

// Callback from libxray when packets are received from the VPN tunnel
// This is called by libxray on its internal goroutine
void libxray_on_packet_received(const uint8_t* data, size_t len) {
    pthread_mutex_lock(&g_xray_callback_mutex);
    if (g_xray_packet_callback) {
        g_xray_packet_callback(data, len);
    }
    pthread_mutex_unlock(&g_xray_callback_mutex);
}

// Bridge implementations

int XrayStart(const char* config_base64) {
    // Register our packet callback with libxray
    libxray_set_packet_callback(libxray_on_packet_received);
    
    // Start libxray core
    return libxray_start(config_base64);
}

void XrayStop(void) {
    libxray_stop();
}

int XrayWritePacket(const uint8_t* data, size_t len) {
    // Write packet to libxray's TUN input
    return libxray_write_packet(data, len);
}

int XrayUpdateConfig(const char* config_base64) {
    return libxray_update_config(config_base64);
}

int XrayGetStats(int64_t* sent, int64_t* received) {
    return libxray_get_stats(sent, received);
}

void XraySetPacketCallback(void (*callback)(const uint8_t*, size_t)) {
    pthread_mutex_lock(&g_xray_callback_mutex);
    g_xray_packet_callback = callback;
    pthread_mutex_unlock(&g_xray_callback_mutex);
}

const char* XrayVersion(void) {
    return libxray_version();
}