# LibXray Integration Guide

## Overview
`LibXray.xcframework` (release asset `libxray-apple-cgo.zip`, version v26.10.31) is a prebuilt Xray core compiled with cgo for iOS.
It exports exactly **two** C functions. Everything else is a JSON request/response protocol defined in the libXray Go sources.

The extension uses it as a local SOCKS proxy:

```
iOS TUN  →  hev-socks5-tunnel  →  Xray SOCKS 127.0.0.1:10808  →  internet
```

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

### 2. Bridging Header

The real bridging header is `HamoTunnelExtension/Tun2SocksBridge.h`. It declares only
what the xcframework actually exports (`ios-arm64/Headers/libXray.h`):

```c
extern char *CGoInvoke(char *requestJSON);
extern void CGoFree(char *value);
```

This build exports no start/stop, packet-write, config-update, stats or version
C entry points. Every operation goes through `CGoInvoke` with the JSON methods
listed below.

### 3. Invoke Protocol (libXray v26.10.31)

Request:

```json
{
  "apiVersion": 3,
  "method": "runXray",
  "payload": { "xrayJson": "<plain Xray JSON configuration>" }
}
```

Response (always):

```json
{ "success": true, "data": null, "error": "" }
```

Source: `invoke.go`, `invoke_model.go` (`LibXrayAPIVersion = 3`) and `xray.go`.

Methods relevant to the tunnel:

| Method | Payload | Data |
|--------|---------|------|
| `runXray` | `{"xrayJson": "<plain JSON>"}` | none |
| `stopXray` | none | none |
| `getXrayState` | none | `{"running": bool}` |
| `xrayVersion` | none | `{"version": string}` |

`runXray` returns an error (`xray is already running`) if a core is already
alive, so a restart is **stopXray + runXray**. There is no hot reload and no
traffic-stats method in v26.10.31.

### 4. Swift Usage (in PacketTunnelProvider.swift)

```swift
// Plain JSON, NOT base64.
let request: [String: Any] = [
    "apiVersion": 3,
    "method": "runXray",
    "payload": ["xrayJson": configJSON]
]
let requestData = try JSONSerialization.data(withJSONObject: request)
let requestJSON = String(data: requestData, encoding: .utf8)!

let responseJSON: String? = requestJSON.withCString { cString in
    guard let raw = CGoInvoke(UnsafeMutablePointer(mutating: cString)) else { return nil }
    defer { CGoFree(raw) }
    return String(cString: raw)
}
```

The wrapper lives in `LibXrayBridge` at the top of `PacketTunnelProvider.swift`.

### 5. Required Entitlements
Both Runner and HamoTunnelExtension need:
- `com.apple.developer.networking.networkextension` → `packet-tunnel-provider`
- `com.apple.developer.networking.vpn.api` → `allow-vpn`
- App Groups: `group.com.hamo.hamo_tunnel.shared` (for shared keychain/prefs)

### 6. Build Settings for Extension Target
```
Target: HamoTunnelExtension
- Swift Version: 5.0
- iOS Deployment Target: 15.0
- Enable Bitcode: NO
- Bridging Header: HamoTunnelExtension/Tun2SocksBridge.h
- Code Sign Entitlements: HamoTunnelExtension/HamoTunnelExtension.entitlements
- Frameworks: NetworkExtension.framework, LibXray.xcframework, HevSocks5Tunnel.xcframework
```

### 7. App Group Configuration
1. In Xcode, select Runner target → Signing & Capabilities → + Capability → App Groups
2. Add: `group.com.hamo.hamo_tunnel.shared`
3. Repeat for HamoTunnelExtension target
4. This allows sharing keychain items (VPN credentials) between app and extension

### 8. Testing
```bash
# Build for device (not simulator - Network Extension requires real device)
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build
```

### 9. TrollStore Signing
For TrollStore distribution, the unsigned .ipa must be signed with `ldid`:
```bash
# After building unsigned .ipa
ldid -S entitlements.plist Payload/Runner.app/PlugIns/HamoTunnelExtension.appex/HamoTunnelExtension
ldid -S entitlements.plist Payload/Runner.app/Runner
```

## C API Reference (libXray v26.10.31)

| Function | Description |
|----------|-------------|
| `char *CGoInvoke(char *requestJSON)` | Execute one JSON request. Returns a C string owned by Go. |
| `void CGoFree(char *value)` | Free a string returned by `CGoInvoke`. |

## Stats

libXray v26.10.31 has no stats API. Traffic counters come only from
`hev_socks5_tunnel_stats(size_t *tx_packets, size_t *tx_bytes, size_t *rx_packets, size_t *rx_bytes)`
(header packaged by `build-apple.sh`: `src/hev-main.h`).

## Config Format
The config passed inside `xrayJson` is **plain JSON** (not base64). It must not
use `geoip:` / `geosite:` rules unless `geoip.dat` / `geosite.dat` are bundled:
Xray rewrites those to `ext:geoip.dat:…` / `ext:geosite.dat:…` and opens the
file through `common/platform/filesystem.OpenAsset`, which fails when the asset
is missing. Private destinations are therefore matched with plain CIDRs.

## Troubleshooting
- **"Library not loaded"**: Ensure xcframework is embedded in both targets
- **"Symbol not found"**: Check the bridging header matches the libXray release
- **VPN permission denied**: Verify entitlements and provisioning profile
- **No traffic**: Check the utun fd was found (`com.apple.net.utun_control`)
- **"failed to open geoip.dat"**: Replace `geoip:`/`geosite:` rules with CIDRs
- **`xray is already running`**: Always call `stopXray` before `runXray`
