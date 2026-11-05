// VPN Service - Main VPN controller
// Coordinates OpenVPN, SSH, V2Ray connections via iOS Network Extension
// Based on Android RenzInjectorService, RenzOpenVPNservice, SSHVPNService, V2RayServiceManager

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../constants/hamo_constants.dart';
import '../storage/preferences_service.dart';
import 'vpn_method_channel.dart';

enum VpnConnectionState {
  disconnected,
  preparing,
  connecting,
  authenticating,
  connected,
  disconnecting,
  error,
}

class VpnService extends ChangeNotifier {
  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;
  static VpnService get instance => _instance;
  VpnService._internal();

  final PreferencesService _prefs = PreferencesService.instance;

  VpnConnectionState _state = VpnConnectionState.disconnected;
  String _statusMessage = 'Disconnected';
  String? _connectedServer;
  DateTime? _connectionStartTime;
  String? _lastError;

  // Statistics
  int _bytesSent = 0;
  int _bytesReceived = 0;
  Duration _sessionDuration = Duration.zero;

  // Timer
  Timer? _sessionTimer;

  // Getters
  VpnConnectionState get state => _state;
  String get statusMessage => _statusMessage;
  String? get connectedServer => _connectedServer;
  DateTime? get connectionStartTime => _connectionStartTime;
  String? get lastError => _lastError;
  int get bytesSent => _bytesSent;
  int get bytesReceived => _bytesReceived;
  Duration get sessionDuration => _sessionDuration;
  bool get isConnected => _state == VpnConnectionState.connected;
  bool get isConnecting => _state == VpnConnectionState.connecting || _state == VpnConnectionState.preparing || _state == VpnConnectionState.authenticating;

  Future<void> initialize() async {
    await VpnMethodChannel.initialize();
    debugPrint('[VpnService] Initialized with Network Extension bridge');
  }

  Future<bool> connect({String? serverName}) async {
    if (isConnecting || isConnected) return false;

    _setState(VpnConnectionState.preparing, 'Preparing connection...');
    
    try {
      // Load server configuration
      final server = serverName ?? _prefs.selectedServer;
      if (server.isEmpty) {
        throw Exception('No server selected');
      }

      _setState(VpnConnectionState.connecting, 'Connecting to $server...');

      // Build config for Network Extension
      final config = _buildVpnConfig(server);
      
      // Start VPN via Network Extension
      final success = await VpnMethodChannel.startVpn(config);
      
      if (!success) {
        _setState(VpnConnectionState.error, 'Failed to start VPN tunnel');
        return false;
      }

      // Wait for connection confirmation (native will callback)
      return true;
    } catch (e) {
      _setState(VpnConnectionState.error, 'Connection failed: $e');
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Map<String, dynamic> _buildVpnConfig(String serverName) {
    final protocol = VpnProtocol.fromValue(_prefs.vpnMode);
    
    // Find server config from preferences or mock data
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
          'v2rayConfig': _prefs.customV2RayConfig ? _buildCustomV2RayConfig() : null,
        });
        break;
      case VpnProtocol.openvpnTcp:
      case VpnProtocol.openvpnUdp:
        config.addAll({
          'openvpnConfig': _prefs.customV2RayConfig ? null : HamoConstants.defaultOpenVPNConfig,
          'caCert': _prefs.customV2RayConfig ? null : _extractCaCert(),
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

  int _getPortForProtocol(VpnProtocol protocol) {
    switch (protocol) {
      case VpnProtocol.openvpnTcp:
        return _prefs.openVpnTcpPort;
      case VpnProtocol.openvpnUdp:
        return _prefs.udpPort;
      case VpnProtocol.ssh:
      case VpnProtocol.sshSpecial:
        return _prefs.sshPort;
      case VpnProtocol.v2ray:
        return HamoConstants.v2rayHttpPort; // V2Ray HTTP port
    }
  }

  String? _buildCustomV2RayConfig() {
    // Build V2Ray JSON config from preferences
    final config = <String, dynamic>{
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'tag': 'tun-in',
          'protocol': 'dokodemo-door',
          'port': 10808,
          'settings': {'network': 'tcp,udp', 'followRedirect': true},
          'sniffing': {'enabled': true, 'destOverride': ['http', 'tls']}
        }
      ],
      'outbounds': [],
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'rules': [
          {'type': 'field', 'outboundTag': 'direct', 'ip': ['geoip:private']},
          {'type': 'field', 'outboundTag': 'direct', 'domain': ['geosite:private']},
          {'type': 'field', 'outboundTag': 'proxy', 'port': '0-65535'}
        ]
      },
      'dns': {
        'servers': _prefs.customDns.isNotEmpty 
            ? _prefs.customDns.split(',') 
            : ['1.1.1.1', '8.8.8.8']
      }
    };

    // Build outbound based on V2Ray type
    final uuid = _prefs.v2rayUuid.isNotEmpty ? _prefs.v2rayUuid : 'a3482e88-686a-4a58-8126-99c9df64b7bf';
    final path = _prefs.v2rayPath.isNotEmpty ? _prefs.v2rayPath : '/';
    final host = _prefs.v2rayHost.isNotEmpty ? _prefs.v2rayHost : _prefs.serverIp;
    final v2rayType = _prefs.v2rayType;
    final allowInsecure = _prefs.allowInsecure;

    var outbound = <String, dynamic>{
      'tag': 'proxy',
      'protocol': v2rayType >= 3 ? 'vless' : 'vmess',
      'settings': {},
      'streamSettings': {}
    };

    if (v2rayType >= 3) { // VLESS
      outbound['settings'] = {
        'vnext': [{
          'address': _prefs.serverIp,
          'port': _prefs.openVpnTcpPort,
          'users': [{'id': uuid, 'encryption': 'none', 'level': 8}]
        }]
      };
    } else { // VMess
      outbound['settings'] = {
        'vnext': [{
          'address': _prefs.serverIp,
          'port': _prefs.openVpnTcpPort,
          'users': [{'id': uuid, 'alterId': 0, 'security': 'auto', 'level': 8}]
        }]
      };
    }

    // Stream settings
    final isGrpc = v2rayType % 3 == 1;
    outbound['streamSettings'] = {
      'network': isGrpc ? 'grpc' : 'ws',
      'security': allowInsecure ? 'none' : 'tls',
    };

    if (isGrpc) {
      outbound['streamSettings']['grpcSettings'] = {
        'serviceName': path,
        'mode': v2rayType == 1 ? 'gun' : 'multi'
      };
    } else {
      outbound['streamSettings']['wsSettings'] = {
        'path': path,
        'headers': {'Host': host}
      };
    }

    if (!allowInsecure) {
      outbound['streamSettings']['tlsSettings'] = {
        'serverName': host,
        'allowInsecure': allowInsecure
      };
    }

    config['outbounds'] = [outbound, {'tag': 'direct', 'protocol': 'freedom'}, {'tag': 'block', 'protocol': 'blackhole'}];

    return jsonEncode(config);
  }

  String? _extractCaCert() {
    // Extract CA cert from default OpenVPN config
    const regex = r'<ca>(.*?)</ca>';
    final match = RegExp(regex, dotAll: true).firstMatch(HamoConstants.defaultOpenVPNConfig);
    return match?.group(1)?.trim();
  }

  Future<void> disconnect() async {
    if (!isConnected && !isConnecting) return;

    _setState(VpnConnectionState.disconnecting, 'Disconnecting...');
    _stopSessionTimer();

    try {
      await VpnMethodChannel.stopVpn();
    } catch (e) {
      debugPrint('[VpnService] Disconnect error: $e');
    }

    _state = VpnConnectionState.disconnected;
    _statusMessage = 'Disconnected';
    _connectedServer = null;
    _connectionStartTime = null;
    _sessionDuration = Duration.zero;
    _bytesSent = 0;
    _bytesReceived = 0;
    notifyListeners();
  }

  // Called by MethodChannel when native VPN status changes
  void setStateFromNative(String? nativeState, String? message) {
    if (nativeState == null) return;

    VpnConnectionState newState;
    switch (nativeState) {
      case 'preparing':
        newState = VpnConnectionState.preparing;
        break;
      case 'connecting':
        newState = VpnConnectionState.connecting;
        break;
      case 'authenticating':
        newState = VpnConnectionState.authenticating;
        break;
      case 'connected':
        newState = VpnConnectionState.connected;
        break;
      case 'disconnecting':
        newState = VpnConnectionState.disconnecting;
        break;
      case 'error':
        newState = VpnConnectionState.error;
        break;
      default:
        newState = VpnConnectionState.disconnected;
    }

    _state = newState;
    _statusMessage = message ?? nativeState;
    
    if (newState == VpnConnectionState.connected) {
      _connectionStartTime = DateTime.now();
      _bytesSent = 0;
      _bytesReceived = 0;
      _startSessionTimer();
    }
    
    notifyListeners();
  }

  // Called by MethodChannel for native errors
  void setNativeError(String? error) {
    if (error != null) {
      _lastError = error;
      _setState(VpnConnectionState.error, 'Error: $error');
    }
  }

  void _setState(VpnConnectionState newState, String message) {
    _state = newState;
    _statusMessage = message;
    notifyListeners();
  }

  void _startSessionTimer() {
    _stopSessionTimer();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state == VpnConnectionState.connected && _connectionStartTime != null) {
        _sessionDuration = DateTime.now().difference(_connectionStartTime!);
        notifyListeners();
      } else {
        _stopSessionTimer();
      }
    });
  }

  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  // Statistics update (called from Network Extension via MethodChannel)
  void updateStatistics({int? sent, int? received}) {
    if (sent != null) _bytesSent = sent;
    if (received != null) _bytesReceived = received;
    notifyListeners();
  }

  String get formattedBytesSent => _formatBytes(_bytesSent);
  String get formattedBytesReceived => _formatBytes(_bytesReceived);
  String get formattedTotalBytes => _formatBytes(_bytesSent + _bytesReceived);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Get current configuration for debugging/export
  Map<String, dynamic> getCurrentConfig() {
    return {
      'vpn_mode': _prefs.vpnMode,
      'tunnel_type': _prefs.tunnelType,
      'payload_mode': _prefs.payloadMode,
      'http_payload': _prefs.httpPayload,
      'sni_host': _prefs.sniHost,
      'server_ip': _prefs.serverIp,
      'ssh_host': _prefs.sshHost,
      'ssh_port': _prefs.sshPort,
      'openvpn_tcp_port': _prefs.openVpnTcpPort,
      'openvpn_ssl_port': _prefs.openVpnSslPort,
      'udp_port': _prefs.udpPort,
      'proxy_host': _prefs.proxyHost,
      'proxy_port': _prefs.proxyPort,
      'custom_dns': _prefs.customDns,
      'v2ray_uuid': _prefs.v2rayUuid,
      'v2ray_path': _prefs.v2rayPath,
      'v2ray_host': _prefs.v2rayHost,
      'v2ray_type': _prefs.v2rayType,
      'allow_insecure': _prefs.allowInsecure,
    };
  }

  @override
  void dispose() {
    _stopSessionTimer();
    super.dispose();
  }
}