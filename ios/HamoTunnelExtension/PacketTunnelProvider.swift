//
//  PacketTunnelProvider.swift
//  HamoTunnelExtension
//
//  Network Extension Packet Tunnel Provider for Hamo Tunnel VPN
//  Uses: Xray core (libxray-apple-cgo) + hev-socks5-tunnel (TUN2SOCKS bridge)
//  Architecture: iOS TUN → hev-socks5-tunnel → Xray SOCKS (127.0.0.1:10808)
//

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

// MARK: - Packet Tunnel Provider
class PacketTunnelProvider: NEPacketTunnelProvider {
    
    // MARK: - Properties
    private var isRunning = false
    private var currentConfig: VPNConfiguration?
    private let packetQueue = DispatchQueue(label: "com.hamo.hamo_tunnel.packetQueue", qos: .userInteractive)
    
    // Xray SOCKS proxy endpoint
    private let xraySocksHost = "127.0.0.1"
    private let xraySocksPort = 10808
    
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
        os_log("Stopping tunnel, reason: %{public}d", log: logger, type: .info, reason.rawValue)
        
        isRunning = false
        stopVPNStack()
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        os_log("Received app message: %{public}d bytes", log: logger, type: .info, messageData.count)
        
        if let message = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
           let type = message["type"] as? String {
            
            switch type {
            case "getStats":
                let stats = getCurrentStats()
                let response = try? JSONSerialization.data(withJSONObject: stats)
                completionHandler?(response)
            case "updateConfig":
                if let configData = message["config"] as? Data {
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
        
        // Step 1: Generate Xray config
        let xrayConfigJSON = generateXrayConfig(from: config)
        
        // Step 2: Start Xray core as SOCKS proxy (port 10808)
        startXray(withConfig: xrayConfigJSON) { [weak self] error in
            if let error = error {
                os_log("Failed to start Xray: %{public}@", log: logger, type: .error, error.localizedDescription)
                completion(error)
                return
            }
            
            os_log("Xray started on 127.0.0.1:%{public}d", log: logger, type: .info, self?.xraySocksPort ?? 10808)
            
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
        // Use provided config or generate from template
        if let customConfig = config.v2rayConfig, !customConfig.isEmpty {
            return customConfig
        }
        
        // Build config matching Android app's V2rayConfigManager logic
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
            "outbounds": [],
            "routing": [
                "domainStrategy": "IPIfNonMatch",
                "rules": [
                    ["type": "field", "outboundTag": "direct", "ip": ["geoip:private"]],
                    ["type": "field", "outboundTag": "direct", "domain": ["geosite:private"]],
                    ["type": "field", "outboundTag": "proxy", "port": "0-65535"]
                ]
            ],
            "dns": [
                "servers": config.customDns?.components(separatedBy: ",") ?? ["1.1.1.1", "8.8.8.8"]
            ]
        ]
        
        // Build outbound
        let uuid = config.v2rayUuid ?? "a3482e88-686a-4a58-8126-99c9df64b7bf"
        let path = config.v2rayPath ?? "/"
        let host = config.v2rayHost ?? config.serverAddress
        let v2rayType = config.v2rayType ?? 0
        let allowInsecure = config.allowInsecure ?? false
        
        var outbound: [String: Any] = [
            "tag": "proxy",
            "protocol": v2rayType >= 3 ? "vless" : "vmess",
            "settings": [:],
            "streamSettings": [:]
        ]
        
        if v2rayType >= 3 { // VLESS
            outbound["settings"] = [
                "vnext": [[
                    "address": config.serverAddress,
                    "port": config.serverPort,
                    "users": [[
                        "id": uuid,
                        "encryption": "none",
                        "level": 8
                    ]]
                ]]
            ]
        } else { // VMess
            outbound["settings"] = [
                "vnext": [[
                    "address": config.serverAddress,
                    "port": config.serverPort,
                    "users": [[
                        "id": uuid,
                        "alterId": 0,
                        "security": "auto",
                        "level": 8
                    ]]
                ]]
            ]
        }
        
        let isGrpc = v2rayType % 3 == 1
        outbound["streamSettings"] = [
            "network": isGrpc ? "grpc" : "ws",
            "security": allowInsecure ? "none" : "tls"
        ]
        
        if isGrpc {
            outbound["streamSettings"]?["grpcSettings"] = [
                "serviceName": path,
                "mode": v2rayType == 1 ? "gun" : "multi"
            ]
        } else {
            outbound["streamSettings"]?["wsSettings"] = [
                "path": path,
                "headers": ["Host": host]
            ]
        }
        
        if !allowInsecure {
            outbound["streamSettings"]?["tlsSettings"] = [
                "serverName": host,
                "allowInsecure": allowInsecure
            ]
        }
        
        configDict["outbounds"] = [outbound, ["tag": "direct", "protocol": "freedom"], ["tag": "block", "protocol": "blackhole"]]
        
        let jsonData = try? JSONSerialization.data(withJSONObject: configDict)
        return jsonData?.base64EncodedString() ?? ""
    }
    
    // MARK: - Xray Process Management (via libxray C API)
    private func startXray(withConfig configBase64: String, completion: @escaping (Error?) -> Void) {
        os_log("Starting Xray core via libxray C API", log: logger, type: .info)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = XrayStart(configBase64)
            if result == 0 {
                os_log("Xray core started successfully", log: logger, type: .info)
                completion(nil)
            } else {
                os_log("Xray core failed to start: %{public}d", log: logger, type: .error, result)
                completion(NSError(domain: "XrayError", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "XrayStart failed with code \(result)"]))
            }
        }
    }
    
    private func stopXray() {
        XrayStop()
    }
    
    // MARK: - hev-socks5-tunnel Bridge (TUN2SOCKS)
    private func startHevSocks5Tunnel(completion: @escaping (Error?) -> Void) {
        os_log("Starting hev-socks5-tunnel bridge", log: logger, type: .info)
        
        // hev-socks5-tunnel handles: iOS TUN packets -> Xray SOCKS (127.0.0.1:10808)
        // It reads from packetFlow and forwards to Xray SOCKS
        // We initialize it with the Xray SOCKS endpoint
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Initialize hev-socks5-tunnel with Xray SOCKS endpoint
            let result = HevSocks5TunnelInit(self.xraySocksHost, UInt16(self.xraySocksPort))
            if result != 0 {
                os_log("hev-socks5-tunnel init failed: %{public}d", log: logger, type: .error, result)
                completion(NSError(domain: "HevSocks5TunnelError", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "HevSocks5TunnelInit failed with code \(result)"]))
                return
            }
            
            os_log("hev-socks5-tunnel initialized", log: logger, type: .info)
            
            // Set packet callback - hev-socks5-tunnel will call this when it receives packets from Xray
            HevSocks5TunnelSetPacketCallback { data, len in
                // Packets FROM Xray TO network
                let packet = Data(bytes: data, count: Int(len))
                self?.packetFlow.writePackets([packet], withProtocols: [NSNumber(value: AF_INET)]) { error in
                    if let error = error {
                        os_log("Write packet error: %{public}@", log: logger, type: .error, error.localizedDescription)
                    }
                }
            }
            
            // Start reading packets from iOS TUN and forwarding to hev-socks5-tunnel
            self.readPacketsFromTunnel()
            
            completion(nil)
        }
    }
    
    private func readPacketsFromTunnel() {
        guard isRunning else { return }
        
        let packetFlow = self.packetFlow
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self = self, self.isRunning else { return }
            
            for packet in packets {
                // Forward packet to hev-socks5-tunnel (which forwards to Xray SOCKS)
                packet.withUnsafeBytes { bytes in
                    if let baseAddress = bytes.baseAddress {
                        let result = HevSocks5TunnelWritePacket(baseAddress.assumingMemoryBound(to: UInt8.self), packet.count)
                        if result < 0 {
                            os_log("hev-socks5-tunnel write failed: %{public}d", log: logger, type: .error, result)
                        }
                    }
                }
            }
            
            // Continue reading
            self.readPacketsFromTunnel()
        }
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
    
    private func stopVPNStack() {
        HevSocks5TunnelCleanup()
        XrayStop()
    }
    
    // MARK: - Stats
    private func getCurrentStats() -> [String: Any] {
        var sent: Int64 = 0
        var received: Int64 = 0
        XrayGetStats(&sent, &received)
        
        return [
            "bytesSent": sent,
            "bytesReceived": received,
            "isConnected": isRunning,
            "uptime": ProcessInfo.processInfo.systemUptime
        ]
    }
    
    private func handleConfigUpdate(_ configData: Data) {
        guard let config = try? JSONDecoder().decode(VPNConfiguration.self, from: configData) else { return }
        currentConfig = config
        
        // Hot-reload Xray config
        let newConfig = generateXrayConfig(from: config)
        XrayUpdateConfig(newConfig)
    }
}

// MARK: - C API Declarations
// libxray C API (from libxray-apple-cgo.xcframework)
@_silgen_name("XrayStart")
func XrayStart(_ config_base64: UnsafePointer<CChar>) -> Int32

@_silgen_name("XrayStop")
func XrayStop()

@_silgen_name("XrayWritePacket")
func XrayWritePacket(_ data: UnsafePointer<UInt8>, _ len: Int) -> Int32

@_silgen_name("XrayUpdateConfig")
func XrayUpdateConfig(_ config_base64: UnsafePointer<CChar>) -> Int32

@_silgen_name("XrayGetStats")
func XrayGetStats(_ sent: UnsafeMutablePointer<Int64>, _ received: UnsafeMutablePointer<Int64>) -> Int32

// hev-socks5-tunnel C API (from libhev-socks5-tunnel.a)
@_silgen_name("HevSocks5TunnelInit")
func HevSocks5TunnelInit(_ socks_host: UnsafePointer<CChar>, _ socks_port: UInt16) -> Int32

@_silgen_name("HevSocks5TunnelCleanup")
func HevSocks5TunnelCleanup()

@_silgen_name("HevSocks5TunnelWritePacket")
func HevSocks5TunnelWritePacket(_ data: UnsafePointer<UInt8>, _ len: Int) -> Int32

@_silgen_name("HevSocks5TunnelSetPacketCallback")
func HevSocks5TunnelSetPacketCallback(_ callback: @convention(c) (UnsafePointer<UInt8>, Int) -> Void)