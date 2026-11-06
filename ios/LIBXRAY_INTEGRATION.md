# LibXray Integration Guide

## Overview
The `LibXray.xcframework` (release asset `libxray-apple-cgo.zip`) is a prebuilt Xray core compiled with cgo for iOS.
It provides the C API that our Network Extension uses via the bridging header.

## Download
1. Go to: https://github.com/XTLS/libXray/releases
2. Download `libxray-apple-cgo.zip` (version v26.10.31 or later)
3. Extract to get `libxray-apple-cgo/LibXray.xcframework`

## Integration Steps

### 1. Add to Xcode Project
```bash
# In Xcode:
# 1. Select Runner project (not target)
# 2. Go to "Frameworks, Libraries, and Embedded Content"
# 3. Click "+" -> "Add Other..." -> "Add Files..."
# 4. Select LibXray.xcframework
# 5. Make sure "Embed & Sign" is selected
# 6. Add to BOTH targets: Runner AND HamoTunnelExtension
```

### 2. Verify Bridging Header
The bridging header (`HamoTunnelExtension-Bridging-Header.h`) declares the C API:

```c
// libxray C API
int XrayStart(const char* config_base64);
void XrayStop(void);
int XrayWritePacket(const uint8_t* data, size_t len);
int XrayUpdateConfig(const char* config_base64);
int XrayGetStats(int64_t* sent, int64_t* received);
void XraySetPacketCallback(void (*callback)(const uint8_t*, size_t));
const char* XrayVersion(void);
```

### 3. Swift Usage (in PacketTunnelProvider.swift)
```swift
// Start Xray with Base64-encoded JSON config
let configBase64 = v2rayConfigJSON.data(using: .utf8)!.base64EncodedString()
let result = XrayStart(configBase64)

// Write packets to Xray TUN interface
XrayWritePacket(packetData, packetData.count)

// Get stats
var sent: Int64 = 0
var received: Int64 = 0
XrayGetStats(&sent, &received)

// Set callback for incoming packets from Xray
XraySetPacketCallback { data, len in
    // Forward to packetFlow.writePackets
    let packet = Data(bytes: data, count: len)
    packetFlow.writePackets([packet], withProtocols: [NSNumber(value: AF_INET)])
}
```

### 4. Required Entitlements
Both Runner and HamoTunnelExtension need:
- `com.apple.developer.networking.networkextension` → `packet-tunnel-provider`
- `com.apple.developer.networking.vpn.api` → `allow-vpn`
- App Groups: `com.hamo.hamo_tunnel.shared` (for shared keychain/prefs)

### 5. Build Settings for Extension Target
```
Target: HamoTunnelExtension
- Swift Version: 5.0
- iOS Deployment Target: 15.0
- Enable Bitcode: NO
- Bridging Header: HamoTunnelExtension/HamoTunnelExtension-Bridging-Header.h
- Code Sign Entitlements: HamoTunnelExtension/HamoTunnelExtension.entitlements
- Frameworks: NetworkExtension.framework, LibXray.xcframework
```

### 6. App Group Configuration
1. In Xcode, select Runner target → Signing & Capabilities → + Capability → App Groups
2. Add: `group.com.hamo.hamo_tunnel.shared`
3. Repeat for HamoTunnelExtension target
4. This allows sharing keychain items (VPN credentials) between app and extension

### 7. Testing
```bash
# Build for device (not simulator - Network Extension requires real device)
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build
```

### 8. TrollStore Signing
For TrollStore distribution, the unsigned .ipa must be signed with `ldid`:
```bash
# After building unsigned .ipa
ldid -S entitlements.plist Payload/Runner.app/HamoTunnelExtension.appex/HamoTunnelExtension
ldid -S entitlements.plist Payload/Runner.app/Runner
```

## C API Reference (from libxray)

| Function | Description |
|----------|-------------|
| `XrayStart(config_base64)` | Start Xray core with Base64 JSON config. Returns 0 on success. |
| `XrayStop()` | Stop Xray core and clean up. |
| `XrayWritePacket(data, len)` | Write packet to Xray TUN input. Returns bytes written. |
| `XrayUpdateConfig(config_base64)` | Hot-reload configuration. Returns 0 on success. |
| `XrayGetStats(sent, received)` | Get traffic statistics. |
| `XraySetPacketCallback(cb)` | Set callback for packets FROM Xray TO network. |
| `XrayVersion()` | Get version string. |

## Config Format
The config passed to `XrayStart` is a Base64-encoded JSON matching Xray's config format.
See `generateV2RayConfig()` in `PacketTunnelProvider.swift` for the structure used.

## Troubleshooting
- **"Library not loaded"**: Ensure xcframework is embedded in both targets
- **"Symbol not found"**: Check bridging header matches libxray version
- **VPN permission denied**: Verify entitlements and provisioning profile
- **No traffic**: Check `XraySetPacketCallback` is set before `XrayStart`
- **Crash on start**: Check config JSON is valid (use `XrayUpdateConfig` to test)