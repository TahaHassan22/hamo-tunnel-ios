// VPN Method Channel - Flutter to iOS Network Extension bridge

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../constants/hamo_constants.dart';
import 'vpn_service.dart';

class VpnMethodChannel {
  static const String _channelName = 'com.hamo.hamo_tunnel/vpn';
  static const MethodChannel _channel = MethodChannel(_channelName);
  
  static bool _isInitialized = false;
  static final StreamController<Map<String, dynamic>> _statsController = StreamController.broadcast();
  
  static Stream<Map<String, dynamic>> get statsStream => _statsController.stream;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    _channel.setMethodCallHandler(_handleMethodCall);
    _isInitialized = true;
    
    debugPrint('[VpnMethodChannel] Initialized');
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onVpnStatusChanged':
        _handleStatusChanged(call.arguments);
        break;
      case 'onVpnStats':
        _handleStats(call.arguments);
        break;
      case 'onVpnError':
        _handleError(call.arguments);
        break;
      default:
        throw MissingPluginException('Method ${call.method} not implemented');
    }
  }

  static void _handleStatusChanged(dynamic args) {
    if (args is Map) {
      final state = args['state'] as String?;
      final message = args['message'] as String?;
      VpnService.instance.setStateFromNative(state, message);
    }
  }

  static void _handleStats(dynamic args) {
    if (args is Map) {
      _statsController.add(Map<String, dynamic>.from(args));
    }
  }

  static void _handleError(dynamic args) {
    if (args is Map) {
      final error = args['error'] as String?;
      VpnService.instance.setNativeError(error);
    }
  }

  // Flutter -> Native calls
  static Future<bool> startVpn(Map<String, dynamic> config) async {
    try {
      final result = await _channel.invokeMethod('startVpn', config);
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      debugPrint('[VpnMethodChannel] startVpn error: ${e.message}');
      return false;
    }
  }

  static Future<bool> stopVpn() async {
    try {
      final result = await _channel.invokeMethod('stopVpn');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      debugPrint('[VpnMethodChannel] stopVpn error: ${e.message}');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getStats() async {
    try {
      final result = await _channel.invokeMethod('getStats');
      return result as Map<String, dynamic>?;
    } on PlatformException catch (e) {
      debugPrint('[VpnMethodChannel] getStats error: ${e.message}');
      return null;
    }
  }

  static Future<void> sendConfigUpdate(Map<String, dynamic> config) async {
    try {
      await _channel.invokeMethod('updateConfig', config);
    } on PlatformException catch (e) {
      debugPrint('[VpnMethodChannel] updateConfig error: ${e.message}');
    }
  }

  static void dispose() {
    _statsController.close();
    _isInitialized = false;
  }
}