
import 'package:flutter/cupertino.dart';
// Status Card - Shows connection status, server, session info

import 'package:flutter/material.dart';
import '../../core/theme/hamo_colors.dart';
import '../../core/constants/hamo_constants.dart';
import '../../core/vpn/vpn_service.dart';

class StatusCard extends StatelessWidget {
  final VpnConnectionState state;
  final String? serverName;
  final Duration sessionDuration;
  final int bytesSent;
  final int bytesReceived;
  final Animation<double>? pulseAnimation;

  const StatusCard({
    super.key,
    required this.state,
    this.serverName,
    required this.sessionDuration,
    required this.bytesSent,
    required this.bytesReceived,
    this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final isConnected = state == VpnConnectionState.connected;

    return AnimatedContainer(
      duration: HamoConstants.animationDuration,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: HamoColors.darkCardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(isConnected ? 0.5 : 0.2),
          width: 1.5,
        ),
        boxShadow: isConnected
            ? [
                BoxShadow(
                  color: statusColor.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Row
          Row(
            children: [
              // Status Indicator Dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: isConnected
                      ? [
                          BoxShadow(
                            color: statusColor.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // Status Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusLabel(),
                      style: TextStyle(
                        color: statusColor,
                        fontFamily: 'SFPro',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (isConnected && serverName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        serverName!,
                        style: const TextStyle(
                          color: HamoColors.darkTextSecondary,
                          fontFamily: 'SFPro',
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Session Timer
              if (isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: HamoColors.darkBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatDuration(sessionDuration),
                    style: const TextStyle(
                      color: HamoColors.darkTextPrimary,
                      fontFamily: 'SFPro',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),

          if (isConnected) ...[
            const SizedBox(height: 20),
            const Divider(color: HamoColors.darkDivider, height: 1),
            const SizedBox(height: 16),
            // Data Stats
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Sent',
                    value: _formatBytes(bytesSent),
                    icon: CupertinoIcons.arrow_up,
                    color: HamoColors.infoBlue,
                  ),
                ),
                const VerticalDivider(
                  color: HamoColors.darkDivider,
                  thickness: 1,
                  indent: 8,
                  endIndent: 8,
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Received',
                    value: _formatBytes(bytesReceived),
                    icon: CupertinoIcons.arrow_down,
                    color: HamoColors.connectedGreen,
                  ),
                ),
                const VerticalDivider(
                  color: HamoColors.darkDivider,
                  thickness: 1,
                  indent: 8,
                  endIndent: 8,
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Total',
                    value: _formatBytes(bytesSent + bytesReceived),
                    icon: CupertinoIcons.arrow_up_arrow_down,
                    color: HamoColors.primaryOrange,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (state) {
      case VpnConnectionState.connected:
        return HamoColors.connectedGreen;
      case VpnConnectionState.connecting:
      case VpnConnectionState.preparing:
      case VpnConnectionState.authenticating:
        return HamoColors.connectingOrange;
      case VpnConnectionState.disconnecting:
        return HamoColors.warningAmber;
      case VpnConnectionState.error:
        return HamoColors.disconnectedRed;
      case VpnConnectionState.disconnected:
        return HamoColors.darkTextDisabled;
    }
  }

  String _getStatusLabel() {
    switch (state) {
      case VpnConnectionState.disconnected:
        return 'Disconnected';
      case VpnConnectionState.preparing:
        return 'Preparing...';
      case VpnConnectionState.connecting:
        return 'Connecting...';
      case VpnConnectionState.authenticating:
        return 'Authenticating...';
      case VpnConnectionState.connected:
        return 'Connected';
      case VpnConnectionState.disconnecting:
        return 'Disconnecting...';
      case VpnConnectionState.error:
        return 'Connection Error';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontFamily: 'SFPro',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: HamoColors.darkTextSecondary,
            fontFamily: 'SFPro',
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}