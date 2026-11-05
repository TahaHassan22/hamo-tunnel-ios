// Preferences Service - SharedPreferences wrapper
// Mirrors Android's hi.java SharedPreferences contract

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/hamo_constants.dart';

class PreferencesService extends ChangeNotifier {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  static PreferencesService get instance => _instance;
  PreferencesService._internal();

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs => _prefs!;

  // Generic getters/setters
  T? get<T>(String key, {T? defaultValue}) {
    if (_prefs == null) return defaultValue;
    if (T == String) return _prefs!.getString(key) as T? ?? defaultValue;
    if (T == int) return _prefs!.getInt(key) as T? ?? defaultValue;
    if (T == bool) return _prefs!.getBool(key) as T? ?? defaultValue;
    if (T == double) return _prefs!.getDouble(key) as T? ?? defaultValue;
    if (T == List<String>) return _prefs!.getStringList(key) as T? ?? defaultValue;
    return defaultValue;
  }

  Future<bool> set<T>(String key, T value) async {
    if (_prefs == null) return false;
    if (T == String) return _prefs!.setString(key, value as String);
    if (T == int) return _prefs!.setInt(key, value as int);
    if (T == bool) return _prefs!.setBool(key, value as bool);
    if (T == double) return _prefs!.setDouble(key, value as double);
    if (T == List<String>) return _prefs!.setStringList(key, value as List<String>);
    return false;
  }

  Future<bool> remove(String key) async {
    if (_prefs == null) return false;
    return _prefs!.remove(key);
  }

  Future<bool> clear() async {
    if (_prefs == null) return false;
    return _prefs!.clear();
  }

  // Secure storage for sensitive data
  Future<String?> getSecure(String key) async {
    return _secureStorage.read(key: key);
  }

  Future<void> setSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  // VPN-specific getters/setters matching Android hi.java
  int get vpnMode => get<int>(HamoConstants.prefsVpnMode) ?? 0;
  set vpnMode(int value) => set(HamoConstants.prefsVpnMode, value);

  int get tunnelType => get<int>(HamoConstants.prefsTunnelType) ?? 0;
  set tunnelType(int value) => set(HamoConstants.prefsTunnelType, value);

  int get payloadMode => get<int>(HamoConstants.prefsPayloadMode) ?? 0;
  set payloadMode(int value) => set(HamoConstants.prefsPayloadMode, value);

  String get httpPayload => get<String>(HamoConstants.prefsHttpPayload) ?? '';
  set httpPayload(String value) => set(HamoConstants.prefsHttpPayload, value);

  String get sniHost => get<String>(HamoConstants.prefsSniHost) ?? '';
  set sniHost(String value) => set(HamoConstants.prefsSniHost, value);

  String get username => get<String>(HamoConstants.prefsUsername) ?? '';
  set username(String value) => set(HamoConstants.prefsUsername, value);

  String get password => get<String>(HamoConstants.prefsPassword) ?? '';
  set password(String value) => set(HamoConstants.prefsPassword, value);

  String get serverIp => get<String>(HamoConstants.prefsServerIp) ?? '';
  set serverIp(String value) => set(HamoConstants.prefsServerIp, value);

  String get sshHost => get<String>(HamoConstants.prefsSshHost) ?? '';
  set sshHost(String value) => set(HamoConstants.prefsSshHost, value);

  int get sshPort => get<int>(HamoConstants.prefsSshPort) ?? 22;
  set sshPort(int value) => set(HamoConstants.prefsSshPort, value);

  int get openVpnTcpPort => get<int>(HamoConstants.prefsOpenVpnTcpPort) ?? 1194;
  set openVpnTcpPort(int value) => set(HamoConstants.prefsOpenVpnTcpPort, value);

  int get openVpnSslPort => get<int>(HamoConstants.prefsOpenVpnSslPort) ?? 443;
  set openVpnSslPort(int value) => set(HamoConstants.prefsOpenVpnSslPort, value);

  int get udpPort => get<int>(HamoConstants.prefsUdpPort) ?? 1194;
  set udpPort(int value) => set(HamoConstants.prefsUdpPort, value);

  String get proxyHost => get<String>(HamoConstants.prefsProxyHost) ?? '';
  set proxyHost(String value) => set(HamoConstants.prefsProxyHost, value);

  int get proxyPort => get<int>(HamoConstants.prefsProxyPort) ?? 8080;
  set proxyPort(int value) => set(HamoConstants.prefsProxyPort, value);

  String get customDns => get<String>(HamoConstants.prefsCustomDns) ?? '';
  set customDns(String value) => set(HamoConstants.prefsCustomDns, value);

  bool get autoStart => get<bool>(HamoConstants.prefsAutoStart) ?? false;
  set autoStart(bool value) => set(HamoConstants.prefsAutoStart, value);

  String get expiry => get<String>(HamoConstants.prefsExpiry) ?? '';
  set expiry(String value) => set(HamoConstants.prefsExpiry, value);

  bool get pinEnabled => get<bool>(HamoConstants.prefsPinEnabled) ?? false;
  set pinEnabled(bool value) => set(HamoConstants.prefsPinEnabled, value);

  String get pinCode => get<String>(HamoConstants.prefsPinCode) ?? '';
  set pinCode(String value) => set(HamoConstants.prefsPinCode, value);

  bool get customV2RayConfig => get<bool>(HamoConstants.prefsCustomV2RayConfig) ?? false;
  set customV2RayConfig(bool value) => set(HamoConstants.prefsCustomV2RayConfig, value);

  String get v2rayUuid => get<String>(HamoConstants.prefsV2RayUuid) ?? '';
  set v2rayUuid(String value) => set(HamoConstants.prefsV2RayUuid, value);

  String get v2rayPath => get<String>(HamoConstants.prefsV2RayPath) ?? '/';
  set v2rayPath(String value) => set(HamoConstants.prefsV2RayPath, value);

  String get v2rayHost => get<String>(HamoConstants.prefsV2RayHost) ?? '';
  set v2rayHost(String value) => set(HamoConstants.prefsV2RayHost, value);

  int get v2rayType => get<int>(HamoConstants.prefsV2RayType) ?? 0;
  set v2rayType(int value) => set(HamoConstants.prefsV2RayType, value);

  bool get allowInsecure => get<bool>(HamoConstants.prefsAllowInsecure) ?? false;
  set allowInsecure(bool value) => set(HamoConstants.prefsAllowInsecure, value);

  String get selectedServer => get<String>(HamoConstants.prefsSelectedServer) ?? '';
  set selectedServer(String value) => set(HamoConstants.prefsSelectedServer, value);

  // Secure credential storage
  Future<String?> getSecurePassword() => getSecure('secure_password');
  Future<void> setSecurePassword(String password) => setSecure('secure_password', password);

  Future<String?> getSecureV2RayUuid() => getSecure('secure_v2ray_uuid');
  Future<void> setSecureV2RayUuid(String uuid) => setSecure('secure_v2ray_uuid', uuid);
}