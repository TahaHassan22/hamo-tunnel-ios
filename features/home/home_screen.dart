// Home Screen - Main VPN connection screen
// Mirrors Android HamoTunnelPlusMain UI

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../core/theme/hamo_colors.dart';
import '../../core/constants/hamo_constants.dart';
import '../../core/vpn/vpn_service.dart';
import '../../core/storage/preferences_service.dart';
import '../../shared/widgets/connection_button.dart';
import '../../shared/widgets/status_card.dart';
import '../../shared/widgets/server_selector.dart';
import '../../shared/widgets/stats_row.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<VpnService, PreferencesService>(
      builder: (context, vpnService, prefs, child) {
        return CupertinoPageScaffold(
          backgroundColor: HamoColors.darkBackground,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: HamoColors.darkBackground,
            border: const Border(
              bottom: BorderSide(color: HamoColors.darkDivider, width: 0.5),
            ),
            middle: Text(
              HamoConstants.appName,
              style: const TextStyle(
                fontFamily: 'SFPro',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: HamoColors.darkTextPrimary,
              ),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showQuickActions(context),
              child: const Icon(
                CupertinoIcons.ellipsis_circle,
                color: HamoColors.primaryOrange,
                size: 26,
              ),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Connection Status Card
                  StatusCard(
                    state: vpnService.state,
                    serverName: vpnService.connectedServer,
                    sessionDuration: vpnService.sessionDuration,
                    bytesSent: vpnService.bytesSent,
                    bytesReceived: vpnService.bytesReceived,
                    pulseAnimation: vpnService.isConnected ? _pulseAnimation : null,
                  ),

                  const SizedBox(height: 24),

                  // Connection Button (Main Action)
                  ConnectionButton(
                    state: vpnService.state,
                    onTap: () => _handleConnectionTap(vpnService),
                  ),

                  const SizedBox(height: 24),

                  // Server Selector
                  ServerSelector(
                    currentServer: prefs.selectedServer,
                    onTap: () => _navigateToServers(context),
                  ),

                  const SizedBox(height: 24),

                  // Statistics Row
                  StatsRow(
                    uploadSpeed: 0, // TODO: Real-time from VPN
                    downloadSpeed: 0,
                    totalUpload: vpnService.bytesSent,
                    totalDownload: vpnService.bytesReceived,
                  ),

                  const SizedBox(height: 24),

                  // Protocol Indicator
                  _buildProtocolIndicator(prefs),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleConnectionTap(VpnService vpnService) {
    if (vpnService.isConnected || vpnService.isConnecting) {
      vpnService.disconnect();
    } else {
      vpnService.connect();
    }
  }

  void _navigateToServers(BuildContext context) {
    Navigator.pushNamed(context, '/servers');
  }

  void _showQuickActions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Quick Actions'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _navigateToServers(context);
            },
            child: const Text('Select Server'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/logs');
            },
            child: const Text('View Logs'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
            child: const Text('Settings'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _showClearDataDialog(context);
            },
            child: const Text('Clear All Data'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'Are you sure you want to clear all data associated with Hamo Tunnel? '
          'This action will reset all settings, including preferences, and app configurations. '
          'Please note that clearing data will log you out of the app and remove any saved information.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await PreferencesService.instance.clear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared')),
                );
              }
            },
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolIndicator(PreferencesService prefs) {
    final protocol = HamoConstants.VpnProtocol.fromValue(prefs.vpnMode);
    Color protocolColor;

    switch (protocol) {
      case HamoConstants.VpnProtocol.openvpnTcp:
      case HamoConstants.VpnProtocol.openvpnUdp:
        protocolColor = HamoColors.protocolOpenVPN;
        break;
      case HamoConstants.VpnProtocol.ssh:
      case HamoConstants.VpnProtocol.sshSpecial:
        protocolColor = HamoColors.protocolSSH;
        break;
      case HamoConstants.VpnProtocol.v2ray:
        protocolColor = HamoColors.protocolV2Ray;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: HamoColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: protocolColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: protocolColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Protocol: ${protocol.displayName}',
            style: TextStyle(
              color: protocolColor,
              fontFamily: 'SFPro',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (prefs.tunnelType > 0) ...[
            const SizedBox(width: 16),
            Text(
              'Tunnel: ${HamoConstants.TunnelType.fromValue(prefs.tunnelType).displayName}',
              style: const TextStyle(
                color: HamoColors.darkTextSecondary,
                fontFamily: 'SFPro',
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}