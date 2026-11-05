# Native Library Integration Guide: OpenVPN & SSH

## Overview
This document provides step-by-step instructions for integrating established iOS libraries for OpenVPN and SSH into the Xcode project via CI.

---

## 1. OpenVPN Integration: OpenVPNAdapter

### Library Choice: **OpenVPNAdapter** (by sskorulis)
- Wrapper around OpenVPN 3 library for iOS
- Supports TCP/UDP, certificate/key auth, username/password
- MIT License, actively maintained
- CocoaPods/SPM support

### Integration Steps

#### A. Add to CI Dependencies Download Job

```yaml
# In .github/workflows/build-ios.yml, download_dependencies job:
- name: Download OpenVPNAdapter
  run: |
    cd ios/Frameworks
    echo "Downloading OpenVPNAdapter..."
    # Using Swift Package Manager approach - clone and build
    git clone --depth 1 --branch 2.0.0 https://github.com/sskorulis/OpenVPNAdapter.git OpenVPNAdapter
    cd OpenVPNAdapter
    # Build static library for iOS
    xcodebuild -scheme OpenVPNAdapter -configuration Release -sdk iphoneos \
      -derivedDataPath build BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      SKIP_INSTALL=NO BUILD_SHARED_LIBRARY=NO 2>&1 | tail -30
    # Copy built framework
    cp -R build/Build/Products/Release-iphoneos/OpenVPNAdapter.framework ../
```

#### B. Update Extension Target Setup Script

```ruby
# In setup_extension_target_ci.sh, add to framework linking:
# Add OpenVPNAdapter framework
openvpn_framework_path = File.join(ext_path, '..', 'Frameworks', 'OpenVPNAdapter.framework')
if File.exist?(openvpn_framework_path)
  openvpn_framework_ref = project.frameworks_group.new_file(openvpn_framework_path)
  ext_target.frameworks_build_phase.add_file_reference(openvpn_framework_ref)
  ext_target.build_configurations.each do |config|
    config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)']
    config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PROJECT_DIR)/../Frameworks'
  end
  puts "Linked OpenVPNAdapter.framework"
end
```

#### C. Swift Usage in PacketTunnelProvider

```swift
import OpenVPNAdapter

private func startOpenVPNStack(with config: VPNConfiguration, completion: @escaping (Error?) -> Void) {
    os_log("Starting OpenVPN via OpenVPNAdapter", log: logger, type: .info)
    
    let adapter = OpenVPNAdapter()
    adapter.delegate = self
    
    // Configure from config
    let ovpnSettings = OpenVPNAdapterSettings()
    ovpnSettings.configFile = config.openvpnConfig
    ovpnSettings.ca = config.caCert
    ovpnSettings.cert = config.clientCert
    ovpnSettings.key = config.clientKey
    ovpnSettings.username = config.username
    ovpnSettings.password = config.password
    ovpnSettings.connectTimeout = 30
    ovpnSettings.reconnectInterval = 5
    
    // For UDP vs TCP
    if config.protocolType == .openvpnUdp {
        ovpnSettings.protocol = .udp
    }
    
    do {
        try adapter.start(with: ovpnSettings)
        // Adapter handles connection lifecycle via delegate
        completion(nil)
    } catch {
        completion(error)
    }
}

// OpenVPNAdapterDelegate methods
extension PacketTunnelProvider: OpenVPNAdapterDelegate {
    func openVPNAdapter(_ adapter: OpenVPNAdapter, didChangeState state: OpenVPNAdapterState) {
        switch state {
        case .connected:
            isRunning = true
            os_log("OpenVPN connected", log: logger, type: .info)
        case .disconnected:
            isRunning = false
            os_log("OpenVPN disconnected", log: logger, type: .info)
        case .error(let error):
            os_log("OpenVPN error: %{public}@", log: logger, type: .error, error.localizedDescription)
        default:
            break
        }
    }
    
    func openVPNAdapter(_ adapter: OpenVPNAdapter, didReceiveData data: Data) {
        // Forward decrypted packets to iOS TUN
        packetFlow.writePackets([data], withProtocols: [NSNumber(value: AF_INET)]) { _ in }
    }
}
```

#### D. Update CI Build Settings

```yaml
# In xcodebuild command for extension:
OTHER_LDFLAGS="$(inherited) -framework NetworkExtension -lhev-socks5-tunnel -framework OpenVPNAdapter"
FRAMEWORK_SEARCH_PATHS="$(inherited) $(PROJECT_DIR)/../Frameworks"
```

---

## 2. SSH Integration: NMSSH (libssh2 wrapper)

### Library Choice: **NMSSH**
- Objective-C wrapper around libssh2
- Supports password auth, key auth, port forwarding
- CocoaPods/SPM support
- Used by many iOS SSH apps

### Integration Steps

#### A. Add to CI Dependencies Download Job

```yaml
- name: Download NMSSH
  run: |
    cd ios/Frameworks
    echo "Downloading NMSSH..."
    git clone --depth 1 --branch 2.3.1 https://github.com/NMSSH/NMSSH.git NMSSH
    cd NMSSH
    # Build static library
    xcodebuild -scheme NMSSH -configuration Release -sdk iphoneos \
      -derivedDataPath build BUILD_LIBRARY_FOR_DISTRIBUTION=YES 2>&1 | tail -30
    # Copy built framework
    cp -R build/Build/Products/Release-iphoneos/NMSSH.framework ../
    # Also need libssh2
    # libssh2 is usually bundled with NMSSH
```

#### B. Update Extension Target Setup

```ruby
# In setup_extension_target_ci.sh:
nmssh_framework_path = File.join(ext_path, '..', 'Frameworks', 'NMSSH.framework')
if File.exist?(nmssh_framework_path)
  nmssh_framework_ref = project.frameworks_group.new_file(nmssh_framework_path)
  ext_target.frameworks_build_phase.add_file_reference(nmssh_framework_ref)
  ext_target.build_configurations.each do |config|
    config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)']
    config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PROJECT_DIR)/../Frameworks'
  end
  puts "Linked NMSSH.framework"
end
```

#### C. Swift Usage in PacketTunnelProvider

```swift
import NMSSH

private var sshSession: NMSSHSession?
private var sshChannel: NMSSHChannel?

private func startSSHStack(with config: VPNConfiguration, completion: @escaping (Error?) -> Void) {
    os_log("Starting SSH via NMSSH", log: logger, type: .info)
    
    let host = config.sshHost ?? config.serverAddress
    let port = config.sshPort ?? 22
    let username = config.username ?? ""
    let password = config.password ?? ""
    
    sshSession = NMSSHSession(host: host, port: port, username: username)
    sshSession?.delegate = self
    
    do {
        try sshSession?.connect()
        try sshSession?.authenticate(byPassword: password)
        
        // For SSH Special (port 2222 forwarder): create dynamic port forward
        if config.useProxy == true {
            // NMSSH doesn't directly support dynamic forwarding
            // Would need to use libssh2 directly or create local SOCKS proxy
            os_log("SSH Special (dynamic forward) requires libssh2 direct usage", log: logger, type: .default)
        }
        
        // Create shell channel for keepalive
        sshChannel = try sshSession?.channel
        try sshChannel?.startShell()
        
        completion(nil)
    } catch {
        completion(error)
    }
}

// NMSSHSessionDelegate
extension PacketTunnelProvider: NMSSHSessionDelegate {
    func session(_ session: NMSSHSession, didReceiveData data: Data) {
        // Forward SSH output (not typically needed for tunnel)
    }
    
    func session(_ session: NMSSHSession, didDisconnectWithError error: Error?) {
        os_log("SSH disconnected: %{public}@", log: logger, type: .info, error?.localizedDescription ?? "Unknown")
        isRunning = false
    }
}
```

#### D. For SSH Special (Dynamic Port Forwarding)

Since NMSSH doesn't support SOCKS5 dynamic forwarding directly, you'll need to use **libssh2 directly** or integrate **libssh2** as a separate static library:

```yaml
# In download_dependencies job:
- name: Build libssh2
  run: |
    cd ios/Frameworks
    git clone --depth 1 --branch libssh2-1.11.0 https://github.com/libssh2/libssh2.git libssh2
    cd libssh2
    mkdir build && cd build
    cmake -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DBUILD_SHARED_LIBS=OFF -DCRYPTO_BACKEND=OpenSSL ..
    make -j$(sysctl -n hw.ncpu)
    cp libssh2.a ../libssh2.a
```

Then use libssh2 C API directly for `ssh2_channel_open_session` + `ssh2_channel_request_pty` + dynamic forwarding.

---

## 3. CI Build Configuration Summary

### Updated xcodebuild Command (Extension Target)

```bash
cd ios
xcodebuild \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  -quiet \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  OTHER_LDFLAGS="$(inherited) -framework NetworkExtension -lhev-socks5-tunnel -framework OpenVPNAdapter -framework NMSSH" \
  FRAMEWORK_SEARCH_PATHS="$(inherited) $(PROJECT_DIR)/../Frameworks" \
  LIBRARY_SEARCH_PATHS="$(inherited) $(PROJECT_DIR)/../Frameworks" \
  2>&1 | tail -50
```

### Framework Directory Structure (After CI Download)

```
ios/Frameworks/
├── libxray-apple-cgo.xcframework/     # Xray core
├── libhev-socks5-tunnel.a              # TUN2SOCKS bridge
├── hev-socks5-tunnel.h                 # TUN2SOCKS header
├── libxray-apple-cgo.xcframework/ios-arm64/libxray.a
├── OpenVPNAdapter.framework/           # OpenVPN adapter
├── NMSSH.framework/                    # SSH wrapper
└── libssh2.a                           # Raw SSH2 (for dynamic forwarding)
```

### Extension Target Build Settings (Generated by setup_extension_target_ci.sh)

```ruby
# Code Signing
CODE_SIGNING_ALLOWED = NO
CODE_SIGNING_REQUIRED = NO
CODE_SIGN_IDENTITY = ""
DEVELOPMENT_TEAM = ""

# Linking
OTHER_LDFLAGS = [
  "-framework NetworkExtension",
  "-lhev-socks5-tunnel",
  "-framework OpenVPNAdapter",
  "-framework NMSSH"
]
FRAMEWORK_SEARCH_PATHS = ["$(inherited)", "$(PROJECT_DIR)/../Frameworks"]
LIBRARY_SEARCH_PATHS = ["$(inherited)", "$(PROJECT_DIR)/../Frameworks"]
HEADER_SEARCH_PATHS = ["$(inherited)", "$(PROJECT_DIR)/../Frameworks"]

# Swift
SWIFT_OBJC_BRIDGING_HEADER = "HamoTunnelExtension/Tun2SocksBridge.h"
```

---

## 4. Verification Checklist

After CI runs, verify:

```bash
# Check extension target exists
xcodebuild -project ios/Runner.xcodeproj -list | grep HamoTunnelExtension

# Check linked frameworks
xcodebuild -project ios/Runner.xcodeproj -target HamoTunnelExtension -showBuildSettings | grep -E "(FRAMEWORK_SEARCH_PATHS|OTHER_LDFLAGS|SWIFT_OBJC_BRIDGING_HEADER)"

# Verify build succeeds
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -derivedDataPath build CODE_SIGNING_ALLOWED=NO
```

---

## 5. Notes

1. **OpenVPNAdapter** requires iOS 12.0+, we target 15.0 ✓
2. **NMSSH** requires libssh2 - ensure it's linked
3. **hev-socks5-tunnel** is pure C, no dependencies
4. **libxray-apple-cgo** is Go-compiled, CGO enabled
5. All frameworks must be built for `arm64` (iOS device)
6. Simulator builds (`arm64_x86_64`) need separate builds for testing
7. App Group `group.com.hamo.hamo_tunnel.shared` enables keychain sharing between app and extension

---

## 6. Alternative: Use Swift Package Manager (SPM)

For simpler dependency management, consider SPM instead of manual framework linking:

```swift
// Package.swift (if converting to SPM)
dependencies: [
    .package(url: "https://github.com/sskorulis/OpenVPNAdapter.git", from: "2.0.0"),
    .package(url: "https://github.com/NMSSH/NMSSH.git", from: "2.3.1"),
]
```

But for CI with manual xcodebuild, static frameworks work better.