# Config Bridging: Flutter UI → Network Extension

## Overview
This document shows the exact code path for passing VPN configuration from the Flutter UI to the iOS Network Extension.

---

## 1. Flutter Side: Building Config & Starting VPN

### `lib/core/vpn/vpn_service.dart` - `connect()` method

```dart
Future<bool> connect({String? serverName}) async {
  if (isConnecting || isConnected) return false;

  _setState(VpnConnectionState.preparing, 'Preparing connection...');
  
  try {
    // 1. Load server from preferences
    final server = serverName ?? _prefs.selectedServer;
    if (server.isEmpty) throw Exception('No server selected');

    _setState(VpnConnectionState.connecting, 'Connecting to $server...');

    // 2. Build complete config from preferences
    final config = _buildVpnConfig(server);
    
    // 3. Start VPN via MethodChannel
    final success = await VpnMethodChannel.startVpn(config);
    
    if (!success) {
      _setState(VpnConnectionState.error, 'Failed to start VPN tunnel');
      return false;
    }
    return true;
  } catch (e) {
    _setState(VpnConnectionState.error, 'Connection failed: $e');
    return false;
  }
}

Map<String, dynamic> _buildVpnConfig(String serverName) {
  final protocol = VpnProtocol.fromValue(_prefs.vpnMode);
  
  // Base config
  final config = <String, dynamic>{
    'protocol': protocol.name,
    'server': _prefs.serverIp.isNotEmpty ? _prefs.serverIp : serverName,
    'port': _getPortForProtocol(protocol),
    'username': _prefs.username.isNotEmpty ? _prefs.username : null,
    'password': _prefs.password.isNotEmpty ? _prefs.password : null,
    'customDns': _prefs.customDns.isNotEmpty ? _prefs.customDns : null,
    'mtu': 1500,
  };

  // Protocol-specific config
  switch (protocol) {
    case VpnProtocol.v2ray:
      config.addAll({
        'v2rayUuid': _prefs.v2rayUuid.isNotEmpty ? _prefs.v2rayUuid : null,
        'v2rayPath': _prefs.v2rayPath.isNotEmpty ? _prefs.v2rayPath : '/',
        'v2rayHost': _prefs.v2rayHost.isNotEmpty ? _prefs.v2rayHost : _prefs.serverIp,
        'v2rayType': _prefs.v2rayType,
        'allowInsecure': _prefs.allowInsecure,
        // Custom V2Ray JSON config (if enabled)
        'v2rayConfig': _prefs.customV2RayConfig ? _buildCustomV2RayConfig() : null,
      });
      break;
    case VpnProtocol.openvpnTcp:
    case VpnProtocol.openvpnUdp:
      config.addAll({
        'openvpnConfig': HamoConstants.defaultOpenVPNConfig,
        'caCert': _extractCaCert(),
      });
      break;
    case VpnProtocol.ssh:
    case VpnProtocol.sshSpecial:
      config.addAll({
        'sshHost': _prefs.sshHost.isNotEmpty ? _prefs.sshHost : _prefs.serverIp,
        'sshPort': _prefs.sshPort,
        'useProxy': protocol == VpnProtocol.sshSpecial,
        'proxyHost': _prefs.proxyHost.isNotEmpty ? _prefs.proxyHost : '127.0.0.1',
        'proxyPort': _prefs.proxyPort,
      });
      break;
  }

  return config;
}
```

---

## 2. Flutter Side: MethodChannel Call

### `lib/core/vpn/vpn_method_channel.dart`

```dart
static Future<bool> startVpn(Map<String, dynamic> config) async {
  try {
    // Encode config as JSON bytes
    final configData = utf8.encode(jsonEncode(config));
    
    // Call native method with config data
    final result = await _channel.invokeMethod('startVpn', {
      'vpnConfig': configData,
    });
    return result as bool? ?? false;
  } on PlatformException catch (e) {
    debugPrint('[VpnMethodChannel] startVpn error: ${e.message}');
    return false;
  }
}
```

---

## 3. iOS Side: MethodChannel Handler

### `ios/Runner/VpnManager.swift`

```swift
private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startVpn":
        guard let configData = call.arguments as? Data else {
            result(FlutterError(code: "INVALID_CONFIG", message: "Missing config data", details: nil))
            return
        }
        startVpn(configData: configData, result: result)
        
    // ... other cases
    }
}

private func startVpn(configData: Data, result: @escaping FlutterResult) {
    guard let manager = tunnelProviderManager else {
        result(FlutterError(code: "NO_MANAGER", message: "VPN manager not loaded", details: nil))
        return
    }
    
    // Save config to manager's providerConfiguration
    // This is passed to the Extension via startVPNTunnel(options:)
    if let configDict = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
        manager.protocolConfiguration?.providerConfiguration = configDict
    }
    
    // Save and start
    manager.saveToPreferences { [weak self] error in
        if let error = error {
            result(FlutterError(code: "SAVE_FAILED", message: error.localizedDescription, details: nil))
            return
        }
        
        do {
            // Pass config via options dictionary
            let options = ["vpnConfig": configData]
            try manager.connection.startVPNTunnel(options: options)
            result(true)
        } catch {
            result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
        }
    }
}
```

---

## 4. Network Extension Side: Receiving Config

### `ios/HamoTunnelExtension/PacketTunnelProvider.swift`

```swift
override func startTunnel(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
    // Extract config from options dictionary
    guard let options = options,
          let configData = options["vpnConfig"] as? Data else {
        let error = NSError(domain: "HamoTunnelError", code: 1, 
            userInfo: [NSLocalizedDescriptionKey: "Missing VPN configuration"])
        completionHandler(error)
        return
    }
    
    do {
        // Decode the config
        let config = try JSONDecoder().decode(VPNConfiguration.self, from: configData)
        self.currentConfig = config
        
        // Create network settings
        let networkSettings = createNetworkSettings(for: config)
        setTunnelNetworkSettings(networkSettings) { [weak self] error in
            if let error = error {
                completionHandler(error)
                return
            }
            
            // Start VPN stack with decoded config
            self?.startVPNStack(with: config) { stackError in
                if let stackError = stackError {
                    completionHandler(stackError)
                    return
                }
                self?.isRunning = true
                completionHandler(nil)
            }
        }
    } catch {
        completionHandler(error)
    }
}
```

---

## 5. VPNConfiguration Struct (Shared Definition)

### Swift (PacketTunnelProvider.swift)
```swift
struct VPNConfiguration: Codable {
    let protocolType: VPNProtocolType
    let serverAddress: String
    let serverPort: Int
    let username: String?
    let password: String?
    
    // V2Ray specific
    let v2rayConfig: String?
    let v2rayUuid: String?
    let v2rayPath: String?
    let v2rayHost: String?
    let v2rayType: Int?
    let allowInsecure: Bool?
    
    // OpenVPN specific
    let openvpnConfig: String?
    let caCert: String?
    let clientCert: String?
    let clientKey: String?
    
    // SSH specific
    let sshHost: String?
    let sshPort: Int?
    let useProxy: Bool?
    let proxyHost: String?
    let proxyPort: Int?
    
    // Common
    let customDns: String?
    let mtu: Int?
}
```

### Dart (hamo_constants.dart)
```dart
enum VpnProtocol {
  openvpnTcp(0, 'OpenVPN TCP', 'OVPN'),
  ssh(1, 'SSH', 'SSH'),
  openvpnUdp(2, 'OpenVPN UDP', 'UDP'),
  v2ray(3, 'V2Ray', 'V2Ray'),
  sshSpecial(4, 'SSH Special', 'SSH+');
  // ... fromValue() method
}
```

---

## Complete Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ FLUTTER UI                                                                  │
│  User taps "Connect"                                                        │
│       │                                                                     │
│       ▼                                                                     │
│  VpnService.connect()                                                       │
│  - Reads prefs (selectedServer, v2rayUuid, v2rayPath, etc.)                │
│  - Builds config Map<String, dynamic>                                       │
│       │                                                                     │
│       ▼                                                                     │
│  VpnMethodChannel.startVpn(config)                                          │
│  - jsonEncode(config) → bytes                                               │
│  - MethodChannel.invokeMethod('startVpn', {'vpnConfig': bytes})            │
│       │                                                                     │
└─────────┼───────────────────────────────────────────────────────────────────┘
          │ MethodChannel (binary message)
          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ iOS RUNNER (VpnManager.swift)                                               │
│  MethodChannel handler receives:                                            │
│    call.method == "startVpn"                                                │
│    call.arguments == Data (JSON bytes)                                      │
│       │                                                                     │
│       ▼                                                                     │
│  NETunnelProviderManager.loadAllFromPreferences()                           │
│  manager.protocolConfiguration?.providerConfiguration = configDict          │
│  manager.saveToPreferences()                                                │
│       │                                                                     │
│       ▼                                                                     │
│  manager.connection.startVPNTunnel(options: ["vpnConfig": configData])     │
│       │                                                                     │
└─────────┼───────────────────────────────────────────────────────────────────┘
          │ NSExtension IPC
          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ NETWORK EXTENSION (PacketTunnelProvider.swift)                              │
│  override func startTunnel(options: [String: NSObject]?)                   │
│       │                                                                     │
│       ▼                                                                     │
│  let configData = options["vpnConfig"] as? Data                            │
│  let config = try JSONDecoder().decode(VPNConfiguration.self, from: data)  │
│       │                                                                     │
│       ▼                                                                     │
│  setTunnelNetworkSettings(networkSettings) {                               │
│       startVPNStack(with: config) {                                        │
│           // Start Xray + hev-socks5-tunnel                                 │
│       }                                                                    │
│  }                                                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Points

1. **Config is passed as JSON bytes** via `options["vpnConfig"]` in `startVPNTunnel(options:)`
2. **`VPNConfiguration` struct is shared** - same fields in Swift (Codable) and Dart
3. **Protocol-specific fields** are nested in the same JSON object
3. **Custom V2Ray JSON config** can be passed as Base64 string in `v2rayConfig` field
4. **Credentials** (username/password) are included - ensure secure storage on Flutter side
4. **App Group** (`group.com.hamo.hamo_tunnel.shared`) can be used for shared keychain access if needed

---

## Security Notes

- **Never log passwords** - filter sensitive fields before debugPrint
- **Use Keychain** for credential storage on iOS (via `flutter_secure_storage`)
- **Clear config on disconnect** - set `providerConfiguration = nil` after stop
- **Validate config** on both sides before starting tunnel