// Hamo Tunnel App Constants
// Based on Hamo Tunnel Plus Android APK v3.2 analysis

// Top-level enums (Dart doesn't allow enums inside classes)

/// VPN Protocol types matching Android app
enum VpnProtocol {
  openvpnTcp(0, 'OpenVPN TCP', 'OVPN'),
  ssh(1, 'SSH', 'SSH'),
  openvpnUdp(2, 'OpenVPN UDP', 'UDP'),
  v2ray(3, 'V2Ray', 'V2Ray'),
  sshSpecial(4, 'SSH Special', 'SSH+');

  final int value;
  final String displayName;
  final String shortName;

  const VpnProtocol(this.value, this.displayName, this.shortName);

  /// Protocol value expected by the iOS Network Extension (VPNConfiguration).
  String get wireName {
    switch (this) {
      case VpnProtocol.openvpnTcp:
        return 'openvpn_tcp';
      case VpnProtocol.openvpnUdp:
        return 'openvpn_udp';
      case VpnProtocol.ssh:
        return 'ssh';
      case VpnProtocol.sshSpecial:
        return 'ssh_special';
      case VpnProtocol.v2ray:
        return 'v2ray';
    }
  }

  static VpnProtocol fromValue(int value) {
    return VpnProtocol.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VpnProtocol.openvpnTcp,
    );
  }
}

/// Tunnel Types matching Android app
enum TunnelType {
  direct(0, 'Direct'),
  ssl(1, 'SSL'),
  payload(2, 'Payload'),
  v2ray(3, 'V2Ray'),
  sshTunnel(4, 'SSH Tunnel'),
  custom(5, 'Custom'),
  udp(6, 'UDP'),
  slowDns(7, 'SlowDNS'),
  auto(8, 'Auto');

  final int value;
  final String displayName;

  const TunnelType(this.value, this.displayName);

  static TunnelType fromValue(int value) {
    return TunnelType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TunnelType.direct,
    );
  }
}

/// Payload Modes matching Android app
enum PayloadMode {
  raw(0, 'Raw'),
  cdn(1, 'CDN (CloudFront/Speedup)'),
  proxy(2, 'Proxy'),
  runApp(3, 'Run.app'),
  directIp(4, 'Direct IP');

  final int value;
  final String displayName;

  const PayloadMode(this.value, this.displayName);

  static PayloadMode fromValue(int value) {
    return PayloadMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PayloadMode.raw,
    );
  }
}

/// Connection Status
enum ConnectionStatus {
  disconnected('Disconnected'),
  connecting('Connecting...'),
  authenticating('Authenticating...'),
  connected('Connected'),
  disconnecting('Disconnecting...'),
  error('Error');

  final String label;

  const ConnectionStatus(this.label);
}

class HamoConstants {
  // App Identity
  static const String appName = 'Hamo Tunnel';
  static const String bundleId = 'com.hamo.hamo_tunnel';
  static const String version = '3.2.0';
  static const int buildNumber = 32;

  // Remote Config / Update Endpoints (from APK analysis)
  static const String remoteConfigUrl =
      'https://raw.githubusercontent.com/MAKE-MONEY-MILLION-DOLLAR-PER-DAY/ENZ-TUNNEL-Lite/refs/heads/main/ENZ_Tunnel.js';
  static const String githubRepoUrl = 'https://github.com/MAKE-MONEY-MILLION-DOLLAR-PER-DAY/ENZ-TUNNEL-Lite';
  static const String telegramChannelUrl = 'https://t.me/Mohamed891846';

  // Upstream v2rayNG resources (from APK)
  static const String geoIpUrl = 'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat';
  static const String geoSiteUrl = 'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat';
  static const String androidPackageNameListUrl = 'https://raw.githubusercontent.com/2dust/androidpackagenamelist/master/proxy.txt';
  static const String v2rayCustomRoutingListUrl = 'https://raw.githubusercontent.com/2dust/v2rayCustomRoutingList/master/';
  static const String v2rayNGUrl = 'https://github.com/2dust/v2rayNG';
  static const String v2rayNGIssuesUrl = 'https://github.com/2dust/v2rayNG/issues';
  static const String v2rayNGWikiModeUrl = 'https://github.com/2dust/v2rayNG/wiki/Mode';
  static const String delayTestUrl = 'https://www.gstatic.com/generate_204';
  static const String delayTestUrl2 = 'https://www.google.com/generate_204';
  static const String promotionUrl = 'https://9.234456.xyz/abc.html';

  // V2Ray Default Ports (from AppConfig)
  static const int v2raySocksPort = 10808;
  static const int v2rayHttpPort = 10809;
  static const int v2rayDnsPort = 10853;

  // VPN Configuration
  static const String vpnServiceName = 'HamoTunnelVPN';
  static const String vpnProfileIdentifier = 'com.hamo.hamo_tunnel.vpn';

  // Default OpenVPN Configuration (from res/ae/a.ovpn)
  static const String defaultOpenVPNConfig = '''
client
dev tun
proto tcp
remote SERVER_IP_HERE 1194
cipher none
auth none
auth-user-pass
redirect-gateway def1
setenv CLIENT_CERT 0
verb 3
<ca>
-----BEGIN CERTIFICATE-----
MIICMTCCAZqgAwIBAgIUAaQBApMS2dYBqYPcA3Pa7cjjw7cwDQYJKoZIhvcNAQEL
BQAwDzENMAsGA1UEAwwES29iWjAeFw0yMDA3MjIyMjIzMzNaFw0zMDA3MjAyMjIz
MzNaMA8xDTALBgNVBAMMBEtvYlowgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGB
AMF46UVi2O5pZpddOPyzU2EyIrr8NrpXqs8BlYhUjxOcCrkMjFu2G9hk7QIZ4qO0
GWVZpPhYk5qWk+LxCsryrSoe0a5HaqIye8BFJmXV0k+O/3e6k06UGNii3gxBWQpF
7r/2CyQLus9OSpQPYszByBvtkwiBAo/V98jdpm+EVu6tAgMBAAGjgYkwgYYwHQYD
VR0OBBYEFGRJMm/+ZmLxV027kahdvSY+UaTSMEoGA1UdIwRDMEGAFGRJMm/+ZmLx
V027kahdvSY+UaTSoROkETAPMQ0wCwYDVQQDDARLb2JaghQBpAECkxLZ1gGpg9wD
c9rtyOPDtzAMBgNVHRMEBTADAQH/MAsGA1UdDwQEAwIBBjANBgkqhkiG9w0BAQsF
AAOBgQC0f8wb5hyEOEEX64l8QCNpyd/WLjoeE5bE+xnIcKE+XpEoDRZwugLoyQdc
HKa3aRHNqKpR7H696XJReo4+pocDeyj7rATbO5dZmSMNmMzbsjQeXux0XjwmZIHu
eDKMefDi0ZfiZmnU2njmTncyZKxv18Ikjws0Myc8PtAxy2qdcA==
-----END CERTIFICATE-----
</ca>
''';

  // DNS Configuration (from res/ae/cpdnsd_conf)
  static const String defaultDnsConfig = '''
global {
	perm_cache=1024;
	cache_dir="%2\$s";
	server_port = %4\$d;
	server_ip = %3\$s;
	query_method=tcp_only;
	min_ttl=15m;
	max_ttl=1w;
	timeout=10;
	daemon=off;
}

%1\$s

rr {
	name=localhost;
	reverse=on;
	a=127.0.0.1;
	owner=localhost;
	soa=localhost,root.localhost,42,86400,900,86400,86400;
}
''';

  // Default V2Ray Config (from assets/v2ray_config.json)
  static const String defaultV2RayConfig = '''
{
  "stats":{},
  "log": {
    "loglevel": "warning"
  },
  "policy":{
      "levels": {
        "8": {
          "handshake": 4,
          "connIdle": 300,
          "uplinkOnly": 1,
          "downlinkOnly": 1
        }
      },
      "system": {
        "statsOutboundUplink": true,
        "statsOutboundDownlink": true
      }
  },
  "inbounds": [{
    "tag": "socks",
    "port": 10808,
    "protocol": "socks",
    "settings": {
      "auth": "noauth",
      "udp": true,
      "userLevel": 8
    },
    "sniffing": {
      "enabled": true,
      "destOverride": [
        "http",
        "tls"
      ]
    }
  },
  {
    "tag": "http",
    "port": 10809,
    "protocol": "http",
    "settings": {
      "userLevel": 8
    }
  }
  ],
  "outbounds": [{
    "tag": "proxy",
    "protocol": "vmess",
    "settings": {
      "vnext": [
        {
          "address": "v2ray.cool",
          "port": 10086,
          "users": [
            {
              "id": "a3482e88-686a-4a58-8126-99c9df64b7bf",
              "alterId": 0,
              "security": "auto",
              "level": 8
            }
          ]
        }
      ]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "wsSettings": {
        "path": "/"
      },
      "tlsSettings": {
        "allowInsecure": false,
        "serverName": "v2ray.cool"
      }
    }
  },
  {
    "tag": "direct",
    "protocol": "freedom",
    "settings": {}
  },
  {
    "tag": "block",
    "protocol": "blackhole",
    "settings": {}
  }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": []
  },
  "dns": {
      "hosts": {},
      "servers": []
  }
}
''';

  // SharedPreferences / Storage Keys
  static const String prefsSelectedServer = 'selected_server';
  static const String prefsVpnMode = 'vpn_mode';
  static const String prefsTunnelType = 'tunnel_type';
  static const String prefsPayloadMode = 'payload_mode';
  static const String prefsHttpPayload = 'http_payload';
  static const String prefsSniHost = 'sni_host';
  static const String prefsUsername = 'username';
  static const String prefsPassword = 'password';
  static const String prefsServerIp = 'server_ip';
  static const String prefsSshHost = 'ssh_host';
  static const String prefsSshPort = 'ssh_port';
  static const String prefsOpenVpnTcpPort = 'openvpn_tcp_port';
  static const String prefsOpenVpnSslPort = 'openvpn_ssl_port';
  static const String prefsUdpPort = 'udp_port';
  static const String prefsProxyHost = 'proxy_host';
  static const String prefsProxyPort = 'proxy_port';
  static const String prefsCustomDns = 'custom_dns';
  static const String prefsAutoStart = 'auto_start';
  static const String prefsExpiry = 'expiry';
  static const String prefsPinEnabled = 'pin_enabled';
  static const String prefsPinCode = 'pin_code';
  static const String prefsCustomV2RayConfig = 'custom_v2ray_config';
  static const String prefsV2RayUuid = 'v2ray_uuid';
  static const String prefsV2RayPath = 'v2ray_path';
  static const String prefsV2RayHost = 'v2ray_host';
  static const String prefsV2RayType = 'v2ray_type';
  static const String prefsAllowInsecure = 'allow_insecure';

  // Local Config Files
  static const String customPayloadFile = 'custom_payload.json';
  static const String classesDexFile = 'classes.dex';
  static const String rlbEntryName = 'a.rlb';

  // Update Mechanism
  static const int updateCheckRequestCode = 1996;
  static const int vpnPermissionRequestCode = 1997;
  static const int exportConfigRequestCode = 1999;

  // UI Constants
  static const double defaultBorderRadius = 16.0;
  static const double smallBorderRadius = 12.0;
  static const double cardElevation = 0.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Network Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration httpTimeout = Duration(seconds: 15);
  static const Duration updateCheckTimeout = Duration(seconds: 20);

  // Payload Placeholders (from Android injector)
  static const List<String> payloadPlaceholders = [
    '[rlb]',
    '[host]',
    '[host_port]',
    '[port]',
    '[raw]',
    '[real_raw]',
    '[method]',
    '[protocol]',
    '[cr]',
    '[lf]',
    '[crlf]',
    '[lfcr]',
    '[split]',
    '[split_delay]',
    '[split_instant]',
    '[instant_split]',
    '[delay_split]',
    '[random]',
    '[repeat]',
    '[rotate=',
  ];

  // Private IP Ranges for VPN Routing (from SSHVPNService)
  static const List<String> privateIpRanges = [
    '10.0.0.0/8',
    '172.16.0.0/12',
    '192.168.0.0/16',
    '169.254.0.0/16',
  ];

  // V2Ray Private Address Space
  static const String v2rayPrivateV4Client = '10.10.10.1';
  static const String v2rayPrivateV4Router = '10.10.10.2';
  static const String v2rayPrivateV6Client = 'fc00::10:10:10:1';
  static const String v2rayPrivateV6Router = 'fc00::10:10:10:2';

  // DNS Servers
  static const String dnsGooglePrimary = '8.8.8.8';
  static const String dnsGoogleSecondary = '8.8.4.4';
  static const String dnsCloudflarePrimary = '1.1.1.1';
  static const String dnsCloudflareSecondary = '1.0.0.1';
  static const String dnsDirect = '223.5.5.5';

  // Scheme for config import/export
  static const String customScheme = 'hamotunnelplus';
  static const String importPrefix = 'hamotunnelplus://';

  // Log Limits
  static const int maxLogLines = 50;
  static const int maxServersList = 100;

  // Biometric / PIN
  static const String pinKeyPrefix = 'pin_';
  static const int pinMinLength = 4;
  static const int pinMaxLength = 6;
}