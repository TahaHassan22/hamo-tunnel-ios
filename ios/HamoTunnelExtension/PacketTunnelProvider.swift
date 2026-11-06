//
//  PacketTunnelProvider.swift
//  HamoTunnelExtension
//
//  Network Extension Packet Tunnel Provider for Hamo Tunnel VPN
//  Uses: Xray core (LibXray.xcframework) + hev-socks5-tunnel (HevSocks5Tunnel.xcframework)
//  Architecture: iOS TUN → hev-socks5-tunnel → Xray SOCKS (127.0.0.1:10808)
//

import Foundation
import NetworkExtension
import os.log

// MARK: - Log
private let logger = OSLog(subsystem: "com.hamo.hamo_tunnel", category: "PacketTunnelProvider")

// MARK: - VPN Protocol Types
enum VPNProtocolType: String, Codable {
    case v2ray = "v2ray"
    case openvpnTcp = "openvpn_tcp"
    case openvpnUdp = "openvpn_udp"
    case ssh = "ssh"
    case sshSpecial = "ssh_special"
}

// MARK: - VPN Configuration (received from Flutter via MethodChannel)
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

    enum CodingKeys: String, CodingKey {
        case protocolType = "protocol"
        case serverAddress = "server"
        case serverPort = "port"
        case username, password
        case v2rayConfig, v2rayUuid, v2rayPath, v2rayHost, v2rayType, allowInsecure
        case openvpnConfig, caCert, clientCert, clientKey
        case sshHost, sshPort, useProxy, proxyHost, proxyPort
        case customDns, mtu
    }
}

// MARK: - libXray JSON bridge
//
// libXray v26.10.31 exports exactly two C functions (Headers/libXray.h):
//
//     char *CGoInvoke(char *requestJSON);
//     void  CGoFree(char *value);
//
// Every operation is a JSON request:
//
//     {"apiVersion":3,"method":"runXray","payload":{"xrayJson":"<plain JSON>"}}
//
// and every reply is:
//
//     {"success":true,"data":...,"error":""}
//
// See github.com/XTLS/libXray @ v26.10.31: invoke.go, invoke_model.go, xray.go.
private struct LibXrayResult {
    let data: Any?
    let error: String?
}

private enum LibXrayBridge {
    /// LibXrayAPIVersion in libxray/invoke_model.go (v26.10.31).
    static let apiVersion = 3

    static func invoke(method: String, payload: [String: Any]? = nil) -> LibXrayResult {
        var request: [String: Any] = ["apiVersion": apiVersion, "method": method]
        if let payload = payload {
            request["payload"] = payload
        }

        guard JSONSerialization.isValidJSONObject(request),
              let requestData = try? JSONSerialization.data(withJSONObject: request),
              let requestJSON = String(data: requestData, encoding: .utf8) else {
            return LibXrayResult(data: nil, error: "Failed to encode libXray request (\(method))")
        }

        // CGoInvoke returns a malloc'd (Go-allocated) C string which must be
        // released with CGoFree. Copy it out before freeing.
        let responseJSON: String? = requestJSON.withCString { cString in
            guard let raw = CGoInvoke(UnsafeMutablePointer(mutating: cString)) else {
                return nil
            }
            defer { CGoFree(raw) }
            return String(cString: raw)
        }

        guard let json = responseJSON,
              let responseData = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            return LibXrayResult(data: nil, error: "Failed to decode libXray response (\(method))")
        }

        let success = object["success"] as? Bool ?? false
        let error = object["error"] as? String
        return LibXrayResult(
            data: object["data"],
            error: success ? nil : (error?.isEmpty == false ? error : "libXray \(method) failed")
        )
    }

    /// runXray → xray.RunXray(payload.xrayJson). Returns ErrAlreadyRunning when
    /// a core is already alive, so callers restart with stopXray + runXray.
    static func start(configJSON: String) -> String? {
        invoke(method: "runXray", payload: ["xrayJson": configJSON]).error
    }

    /// stopXray → xray.StopXray(). No-op (success) when nothing is running.
    static func stop() -> String? {
        invoke(method: "stopXray").error
    }

    /// getXrayState → data = {"running": Bool}
    static func isRunning() -> Bool {
        guard let data = invoke(method: "getXrayState").data as? [String: Any] else { return false }
        return data["running"] as? Bool ?? false
    }
}

// MARK: - Packet Tunnel Provider
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - Properties
    private var isRunning = false
    private var currentConfig: VPNConfiguration?
    private var hevSocks5TunnelThread: Thread?

    // libXray start/stop are serialized here: runXray and stopXray both take
    // the same Go mutex, and restart = stopXray + runXray.
    private let xrayQueue = DispatchQueue(label: "com.hamo.hamo_tunnel.xray")

    // Xray SOCKS proxy endpoint
    private let xraySocksHost = "127.0.0.1"
    private let xraySocksPort = 10808

    // Local/private destinations that must bypass the proxy. Plain CIDRs are
    // used because geoip.dat / geosite.dat are not bundled with the app, and
    // geoip:/geosite: rules make Xray try to open those assets.
    private static let privateIPRules = [
        "10.0.0.0/8",
        "172.16.0.0/12",
        "192.168.0.0/16",
        "127.0.0.0/8",
        "169.254.0.0/16",
        "100.64.0.0/10",
        "fc00::/7",
        "fe80::/10"
    ]

    // MARK: - Lifecycle
    override func startTunnel(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting Hamo Tunnel", log: logger, type: .info)

        guard let options = options,
              let configData = options["vpnConfig"] as? Data else {
            let error = NSError(domain: "HamoTunnelError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing VPN configuration"])
            completionHandler(error)
            return
        }

        do {
            let config = try JSONDecoder().decode(VPNConfiguration.self, from: configData)
            self.currentConfig = config

            // Set up tunnel network settings
            let networkSettings = createNetworkSettings(for: config)
            setTunnelNetworkSettings(networkSettings) { [weak self] error in
                if let error = error {
                    os_log("Failed to set network settings: %{public}@", log: logger, type: .error, error.localizedDescription)
                    completionHandler(error)
                    return
                }

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
            os_log("Failed to decode config: %{public}@", log: logger, type: .error, error.localizedDescription)
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping tunnel, reason: %{public}ld", log: logger, type: .info, reason.rawValue)

        isRunning = false
        stopVPNStack()
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        os_log("Received app message: %{public}ld bytes", log: logger, type: .info, messageData.count)

        if let message = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
           let type = message["type"] as? String {

            switch type {
            case "getStats":
                let stats = getCurrentStats()
                let response = try? JSONSerialization.data(withJSONObject: stats)
                completionHandler?(response)
            case "updateConfig":
                // VpnManager.swift sends "config" as a JSON object, not Data.
                if let configDict = message["config"] as? [String: Any],
                   JSONSerialization.isValidJSONObject(configDict),
                   let configData = try? JSONSerialization.data(withJSONObject: configDict) {
                    handleConfigUpdate(configData)
                }
                completionHandler?(nil)
            default:
                completionHandler?(nil)
            }
        } else {
            completionHandler?(nil)
        }
    }

    // MARK: - Network Settings
    private func createNetworkSettings(for config: VPNConfiguration) -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.10.10.1")

        // IPv4 - Use V2Ray private address space
        let ipv4Settings = NEIPv4Settings(addresses: ["10.10.10.1"], subnetMasks: ["255.255.255.252"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        ipv4Settings.excludedRoutes = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "169.254.0.0", subnetMask: "255.255.0.0"),
        ]

        // Exclude local SOCKS proxy
        ipv4Settings.excludedRoutes?.append(NEIPv4Route(destinationAddress: "127.0.0.1", subnetMask: "255.255.255.255"))

        // Also exclude server IP
        if let serverIP = resolveHostname(config.serverAddress) {
            ipv4Settings.excludedRoutes?.append(NEIPv4Route(destinationAddress: serverIP, subnetMask: "255.255.255.255"))
        }

        settings.ipv4Settings = ipv4Settings

        // IPv6
        let ipv6Settings = NEIPv6Settings(addresses: ["fc00::10:10:10:1"], networkPrefixLengths: [126])
        ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6Settings

        // DNS
        let dnsServers = config.customDns?.components(separatedBy: ",") ?? ["1.1.1.1", "8.8.8.8"]
        let dnsSettings = NEDNSSettings(servers: dnsServers)
        dnsSettings.matchDomains = [""]
        settings.dnsSettings = dnsSettings

        // MTU
        settings.mtu = NSNumber(value: config.mtu ?? 1500)

        return settings
    }

    private func resolveHostname(_ hostname: String) -> String? {
        let ipv4Pattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#
        if hostname.range(of: ipv4Pattern, options: .regularExpression) != nil {
            return hostname
        }
        return nil
    }

    // MARK: - VPN Stack Management
    private func startVPNStack(with config: VPNConfiguration, completion: @escaping (Error?) -> Void) {
        os_log("Starting VPN stack for protocol: %{public}@", log: logger, type: .info, config.protocolType.rawValue)

        switch config.protocolType {
        case .v2ray:
            startV2RayStack(with: config, completion: completion)
        case .openvpnTcp, .openvpnUdp:
            startOpenVPNStack(with: config, completion: completion)
        case .ssh, .sshSpecial:
            startSSHStack(with: config, completion: completion)
        }
    }

    private func startV2RayStack(with config: VPNConfiguration, completion: @escaping (Error?) -> Void) {
        os_log("Starting V2Ray stack (Xray + hev-socks5-tunnel)", log: logger, type: .info)

        // Step 1: Generate Xray config (plain JSON, no base64)
        let xrayConfigJSON = generateXrayConfig(from: config)
        guard !xrayConfigJSON.isEmpty else {
            completion(NSError(domain: "HamoTunnelError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to build Xray configuration JSON"]))
            return
        }

        // Step 2: Start Xray core as SOCKS proxy (port 10808)
        startXray(withConfig: xrayConfigJSON) { [weak self] error in
            if let error = error {
                os_log("Failed to start Xray: %{public}@", log: logger, type: .error, error.localizedDescription)
                completion(error)
                return
            }

            os_log("Xray started on 127.0.0.1:%{public}ld", log: logger, type: .info, self?.xraySocksPort ?? 10808)

            // Step 3: Start hev-socks5-tunnel bridge (iOS TUN -> Xray SOCKS)
            self?.startHevSocks5Tunnel { tunError in
                if let tunError = tunError {
                    os_log("Failed to start hev-socks5-tunnel: %{public}@", log: logger, type: .error, tunError.localizedDescription)
                    completion(tunError)
                    return
                }

                os_log("hev-socks5-tunnel bridge started", log: logger, type: .info)
                completion(nil)
            }
        }
    }

    private func generateXrayConfig(from config: VPNConfiguration) -> String {
        // Dart sends v2rayConfig as plain JSON (jsonEncode), not base64.
        if let customConfig = config.v2rayConfig, !customConfig.isEmpty {
            return customConfig
        }

        // Build config matching Android app's V2rayConfigManager logic
        let uuid = config.v2rayUuid ?? "a3482e88-686a-4a58-8126-99c9df64b7bf"
        let path = config.v2rayPath ?? "/"
        let host = config.v2rayHost ?? config.serverAddress
        let v2rayType = config.v2rayType ?? 0
        let allowInsecure = config.allowInsecure ?? false
        let isGrpc = v2rayType % 3 == 1

        var user: [String: Any] = [
            "id": uuid,
            "level": 8
        ]
        if v2rayType >= 3 { // VLESS
            user["encryption"] = "none"
        } else { // VMess
            user["alterId"] = 0
            user["security"] = "auto"
        }

        let outboundSettings: [String: Any] = [
            "vnext": [[
                "address": config.serverAddress,
                "port": config.serverPort,
                "users": [user]
            ]]
        ]

        var streamSettings: [String: Any] = [
            "network": isGrpc ? "grpc" : "ws",
            "security": allowInsecure ? "none" : "tls"
        ]

        if isGrpc {
            streamSettings["grpcSettings"] = [
                "serviceName": path,
                "mode": v2rayType == 1 ? "gun" : "multi"
            ]
        } else {
            streamSettings["wsSettings"] = [
                "path": path,
                "headers": ["Host": host]
            ]
        }

        if !allowInsecure {
            streamSettings["tlsSettings"] = [
                "serverName": host,
                "allowInsecure": allowInsecure
            ]
        }

        let outbound: [String: Any] = [
            "tag": "proxy",
            "protocol": v2rayType >= 3 ? "vless" : "vmess",
            "settings": outboundSettings,
            "streamSettings": streamSettings
        ]

        var configDict: [String: Any] = [
            "log": ["loglevel": "warning"],
            "inbounds": [
                [
                    "tag": "socks-in",
                    "port": xraySocksPort,
                    "listen": "127.0.0.1",
                    "protocol": "socks",
                    "settings": [
                        "auth": "noauth",
                        "udp": true,
                        "userLevel": 8
                    ],
                    "sniffing": [
                        "enabled": true,
                        "destOverride": ["http", "tls"]
                    ]
                ]
            ],
            "routing": [
                "domainStrategy": "IPIfNonMatch",
                "rules": [
                    ["type": "field", "outboundTag": "direct", "ip": PacketTunnelProvider.privateIPRules],
                    ["type": "field", "outboundTag": "direct", "domain": ["full:localhost", "domain:local"]],
                    ["type": "field", "outboundTag": "proxy", "port": "0-65535"]
                ] as [[String: Any]]
            ],
            "dns": [
                "servers": config.customDns?.components(separatedBy: ",") ?? ["1.1.1.1", "8.8.8.8"]
            ]
        ]
        
        let outbounds: [[String: Any]] = [
            outbound,
            ["tag": "direct", "protocol": "freedom"],
            ["tag": "block", "protocol": "blackhole"]
        ]
        configDict["outbounds"] = outbounds

        guard let jsonData = try? JSONSerialization.data(withJSONObject: configDict) else {
            return ""
        }
        return String(data: jsonData, encoding: .utf8) ?? ""
    }

    // MARK: - Xray Process Management (via libXray CGoInvoke)
    private func startXray(withConfig configJSON: String, completion: @escaping (Error?) -> Void) {
        os_log("Starting Xray core via libXray CGoInvoke(runXray)", log: logger, type: .info)

        xrayQueue.async {
            // runXray returns ErrAlreadyRunning when a core is alive, so an
            // update/restart is always stopXray + runXray.
            _ = LibXrayBridge.stop()

            if let error = LibXrayBridge.start(configJSON: configJSON) {
                os_log("Xray core failed to start: %{public}@", log: logger, type: .error, error)
                completion(NSError(domain: "LibXray", code: 1, userInfo: [NSLocalizedDescriptionKey: error]))
            } else {
                os_log("Xray core started successfully", log: logger, type: .info)
                completion(nil)
            }
        }
    }

    private func stopXray() {
        xrayQueue.sync {
            _ = LibXrayBridge.stop()
        }
    }

    // MARK: - hev-socks5-tunnel Bridge (TUN2SOCKS)
    // Uses upstream API: hev_socks5_tunnel_main_from_str, hev_socks5_tunnel_quit, hev_socks5_tunnel_stats
    private func startHevSocks5Tunnel(completion: @escaping (Error?) -> Void) {
        os_log("Starting hev-socks5-tunnel bridge", log: logger, type: .info)

        guard let tunFd = tunnelFileDescriptor() else {
            completion(NSError(domain: "HamoTunnelError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to locate the utun control socket (com.apple.net.utun_control)"]))
            return
        }

        os_log("Starting hev-socks5-tunnel with tun_fd=%{public}d", log: logger, type: .info, tunFd)

        // YAML config (plain UTF-8 bytes, not NUL-terminated length).
        let configBytes = Array(buildHevSocks5TunnelConfigYAML().utf8)

        // hev_socks5_tunnel_main_from_str blocks until quit, so it runs on a
        // dedicated thread.
        let thread = Thread {
            let result = configBytes.withUnsafeBufferPointer { buffer in
                hev_socks5_tunnel_main_from_str(buffer.baseAddress, UInt32(buffer.count), tunFd)
            }
            if result != 0 {
                os_log("hev-socks5-tunnel exited with code: %{public}d", log: logger, type: .error, result)
            } else {
                os_log("hev-socks5-tunnel exited cleanly", log: logger, type: .info)
            }
        }
        hevSocks5TunnelThread = thread
        thread.start()

        // Give it a moment to start
        Thread.sleep(forTimeInterval: 0.5)

        os_log("hev-socks5-tunnel bridge started", log: logger, type: .info)
        completion(nil)
    }

    private func buildHevSocks5TunnelConfigYAML() -> String {
        // Keys verified against hev-socks5-tunnel conf/main.yml and
        // src/hev-config.c (root keys tunnel/socks5/mapdns/misc, socks5 keys
        // address/port). The tunnel section is optional; the utun interface is
        // already configured by NEPacketTunnelNetworkSettings.
        return """
        socks5:
          address: "\(xraySocksHost)"
          port: \(xraySocksPort)
        """
    }

    private func stopVPNStack() {
        // Stop hev-socks5-tunnel first (it is the reader/writer of the TUN fd).
        hev_socks5_tunnel_quit()

        // Wait for thread to finish
        hevSocks5TunnelThread?.cancel()
        hevSocks5TunnelThread = nil

        // Stop Xray
        stopXray()
    }

    // MARK: - utun file descriptor discovery
    //
    // NEPacketTunnelFlow has no public file-descriptor property (verified
    // against iPhoneOS15.6/16.5 NEPacketTunnelFlow.h), so the utun control
    // socket is found by scanning the process descriptors, the same approach
    // used by the iOS Tun2SocksKit wrapper around this same hev library.
    private func tunnelFileDescriptor() -> Int32? {
        var ctlInfo = ctl_info()
        withUnsafeMutablePointer(to: &ctlInfo.ctl_name) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: pointer.pointee)) { name in
                _ = strcpy(name, "com.apple.net.utun_control")
            }
        }

        for fd: Int32 in 0...1024 {
            var addr = sockaddr_ctl()
            var length = socklen_t(MemoryLayout<sockaddr_ctl>.size)
            var result: Int32 = -1
            withUnsafeMutablePointer(to: &addr) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                    result = getpeername(fd, sockaddrPointer, &length)
                }
            }

            guard result == 0, addr.sc_family == UInt8(AF_SYSTEM) else { continue }

            if ctlInfo.ctl_id == 0 {
                guard ioctl(fd, CTLIOCGINFO, &ctlInfo) == 0 else { continue }
            }

            if addr.sc_id == ctlInfo.ctl_id {
                return fd
            }
        }

        return nil
    }

    // MARK: - OpenVPN / SSH (Stubs - to be implemented with proper libraries)
    private func startOpenVPNStack(with config: VPNConfiguration, completion: @escaping (Error?) -> Void) {
        os_log("OpenVPN not yet implemented - use OpenVPNAdapter", log: logger, type: .default)
        completion(NSError(domain: "NotImplemented", code: 0, userInfo: [NSLocalizedDescriptionKey: "OpenVPN not yet implemented - integrate OpenVPNAdapter"]))
    }

    private func startSSHStack(with config: VPNConfiguration, completion: @escaping (Error?) -> Void) {
        os_log("SSH not yet implemented - use NMSSH/libssh2", log: logger, type: .default)
        completion(NSError(domain: "NotImplemented", code: 0, userInfo: [NSLocalizedDescriptionKey: "SSH not yet implemented - integrate NMSSH or libssh2"]))
    }

    // MARK: - Stats
    private func getCurrentStats() -> [String: Any] {
        // The only traffic counters available: hev_socks5_tunnel_stats.
        // libXray v26.10.31 has no stats API (runXray/stopXray/getXrayState/
        // xrayVersion only).
        var txPackets = 0
        var txBytes = 0
        var rxPackets = 0
        var rxBytes = 0
        hev_socks5_tunnel_stats(&txPackets, &txBytes, &rxPackets, &rxBytes)

        return [
            "bytesSent": txBytes,
            "bytesReceived": rxBytes,
            "packetsSent": txPackets,
            "packetsReceived": rxPackets,
            "isConnected": isRunning,
            "uptime": ProcessInfo.processInfo.systemUptime
        ]
    }

    private func handleConfigUpdate(_ configData: Data) {
        guard let config = try? JSONDecoder().decode(VPNConfiguration.self, from: configData) else {
            os_log("updateConfig: failed to decode VPNConfiguration", log: logger, type: .error)
            return
        }
        currentConfig = config

        guard isRunning else { return }

        let newConfig = generateXrayConfig(from: config)
        guard !newConfig.isEmpty else { return }

        // libXray has no hot reload: restart = stopXray + runXray.
        os_log("Restarting Xray (stopXray + runXray)", log: logger, type: .info)
        startXray(withConfig: newConfig) { error in
            if let error = error {
                os_log("Xray restart failed: %{public}@", log: logger, type: .error, error.localizedDescription)
            } else {
                os_log("Xray restarted", log: logger, type: .info)
            }
        }
    }
}
