//
//  VpnManager.swift
//  Runner
//
//  Flutter MethodChannel handler for VPN operations
//  Communicates with Network Extension via NEPacketTunnelProvider
//

import Foundation
import NetworkExtension
import Flutter

class VpnManager: NSObject {
    static let shared = VpnManager()
    
    private let channelName = "com.hamo.hamo_tunnel/vpn"
    private var methodChannel: FlutterMethodChannel?
    private var tunnelProviderManager: NETunnelProviderManager?
    
    // VPN Status callbacks to Flutter
    private var flutterStatusCallback: ((String, String?) -> Void)?
    
    override init() {
        super.init()
        loadProviderManager()
    }
    
    // MARK: - Setup
    func register(with registrar: FlutterPluginRegistrar) {
        methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        methodChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
        
        // Observe VPN status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusChanged(_:)),
            name: .NEVPNStatusDidChange,
            object: nil
        )
    }
    
    private func loadProviderManager() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error = error {
                os_log("Failed to load VPN managers: %{public}@", log: .default, type: .error, error.localizedDescription)
                return
            }
            
            self?.tunnelProviderManager = managers?.first ?? NETunnelProviderManager()
            self?.configureProviderManager()
        }
    }
    
    private func configureProviderManager() {
        guard let manager = tunnelProviderManager else { return }
        
        let providerProtocol = NETunnelProviderProtocol()
        providerProtocol.providerBundleIdentifier = "com.hamo.hamo_tunnel.HamoTunnelExtension"
        providerProtocol.serverAddress = "Hamo Tunnel"
        
        manager.protocolConfiguration = providerProtocol
        manager.localizedDescription = "Hamo Tunnel VPN"
        manager.isEnabled = true
        
        manager.saveToPreferences { [weak self] error in
            if let error = error {
                os_log("Failed to save VPN manager: %{public}@", log: .default, type: .error, error.localizedDescription)
            } else {
                os_log("VPN manager saved successfully", log: .default, type: .info)
                self?.tunnelProviderManager = manager
            }
        }
    }
    
    // MARK: - Method Channel Handler
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startVpn":
            guard let config = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_CONFIG", message: "Missing or invalid config", details: nil))
                return
            }
            startVpn(config: config, result: result)
            
        case "stopVpn":
            stopVpn(result: result)
            
        case "getStats":
            getStats(result: result)
            
        case "updateConfig":
            guard let config = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_CONFIG", message: "Missing config", details: nil))
                return
            }
            updateConfig(config: config, result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - VPN Operations
    private func startVpn(config: [String: Any], result: @escaping FlutterResult) {
        guard let manager = tunnelProviderManager else {
            result(FlutterError(code: "NO_MANAGER", message: "VPN manager not loaded", details: nil))
            return
        }
        
        // Save config to manager
        manager.protocolConfiguration?.providerConfiguration = config
        
        // Save and start
        manager.saveToPreferences { [weak self] error in
            if let error = error {
                os_log("Failed to save config: %{public}@", log: .default, type: .error, error.localizedDescription)
                result(FlutterError(code: "SAVE_FAILED", message: error.localizedDescription, details: nil))
                return
            }
            
            do {
                try manager.connection.startVPNTunnel(options: ["vpnConfig": try JSONSerialization.data(withJSONObject: config)])
                result(true)
            } catch {
                os_log("Failed to start VPN: %{public}@", log: .default, type: .error, error.localizedDescription)
                result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
            }
        }
    }
    
    private func stopVpn(result: @escaping FlutterResult) {
        tunnelProviderManager?.connection.stopVPNTunnel()
        result(true)
    }
    
    private func getStats(result: @escaping FlutterResult) {
        // Send message to tunnel provider to get stats
        guard let session = tunnelProviderManager?.connection as? NETunnelProviderSession else {
            result(["bytesSent": 0, "bytesReceived": 0, "isConnected": false])
            return
        }
        
        let message = ["type": "getStats"]
        if let data = try? JSONSerialization.data(withJSONObject: message) {
            session.sendProviderMessage(data) { responseData in
                if let responseData = responseData,
                   let stats = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                    result(stats)
                } else {
                    result(["bytesSent": 0, "bytesReceived": 0, "isConnected": false])
                }
            }
        } else {
            result(["bytesSent": 0, "bytesReceived": 0, "isConnected": false])
        }
    }
    
    private func updateConfig(config: [String: Any], result: @escaping FlutterResult) {
        guard let session = tunnelProviderManager?.connection as? NETunnelProviderSession else {
            result(FlutterError(code: "NO_SESSION", message: "No active VPN session", details: nil))
            return
        }
        
        let message = ["type": "updateConfig", "config": config]
        if let data = try? JSONSerialization.data(withJSONObject: message) {
            session.sendProviderMessage(data) { _ in
                result(true)
            }
        } else {
            result(FlutterError(code: "ENCODE_FAILED", message: "Failed to encode config", details: nil))
        }
    }
    
    // MARK: - Status Observer
    @objc private func vpnStatusChanged(_ notification: Notification) {
        guard let connection = notification.object as? NEVPNConnection else { return }
        
        let status = connection.status
        let statusString: String
        let message: String?
        
        switch status {
        case .invalid, .disconnected:
            statusString = "disconnected"
            message = "Disconnected"
        case .connecting:
            statusString = "connecting"
            message = "Connecting..."
        case .reasserting:
            statusString = "connecting"
            message = "Reconnecting..."
        case .connected:
            statusString = "connected"
            message = "Connected"
        case .disconnecting:
            statusString = "disconnecting"
            message = "Disconnecting..."
        @unknown default:
            statusString = "disconnected"
            message = "Unknown"
        }
        
        // Notify Flutter
        DispatchQueue.main.async { [weak self] in
            self?.methodChannel?.invokeMethod("onVpnStatusChanged", arguments: [
                "state": statusString,
                "message": message
            ])
        }
        
        // Notify local callback
        flutterStatusCallback?(statusString, message)
    }
    
    // MARK: - Callbacks
    func setStatusCallback(_ callback: @escaping (String, String?) -> Void) {
        flutterStatusCallback = callback
    }
}