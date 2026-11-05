// Server Card - Individual server item in list

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../core/theme/hamo_colors.dart';
import '../../core/constants/hamo_constants.dart';

class ServerCard extends StatelessWidget {
  final Map<String, dynamic> server;
  final bool isSelected;
  final bool isConnected;
  final VoidCallback onTap;

  const ServerCard({
    super.key,
    required this.server,
    required this.isSelected,
    required this.isConnected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final protocol = server['protocol'] as VpnProtocol;
    final tunnelType = server['tunnelType'] as TunnelType;
    final flag = server['flag'] as String? ?? '🌐';

    Color protocolColor;
    switch (protocol) {
      case VpnProtocol.openvpnTcp:
      case VpnProtocol.openvpnUdp:
        protocolColor = HamoColors.protocolOpenVPN;
        break;
      case VpnProtocol.ssh:
      case VpnProtocol.sshSpecial:
        protocolColor = HamoColors.protocolSSH;
        break;
      case VpnProtocol.v2ray:
        protocolColor = HamoColors.protocolV2Ray;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? HamoColors.primaryOrange.withOpacity(0.1) : HamoColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? HamoColors.primaryOrange : HamoColors.darkDivider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Flag/Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: protocolColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(flag, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            // Server Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          server['name'] as String,
                          style: const TextStyle(
                            color: HamoColors.darkTextPrimary,
                            fontFamily: 'SFPro',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: HamoColors.primaryOrange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'SELECTED',
                            style: TextStyle(
                              color: HamoColors.darkTextOnPrimary,
                              fontFamily: 'SFPro',
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _ProtocolBadge(
                        label: protocol.shortName,
                        color: protocolColor,
                      ),
                      const SizedBox(width: 8),
                      _ProtocolBadge(
                        label: tunnelType.displayName,
                        color: HamoColors.darkTextSecondary,
                        backgroundColor: HamoColors.darkDivider,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Connection Status / Chevron
            if (isConnected)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HamoColors.connectedGreen.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.checkmark,
                  color: HamoColors.connectedGreen,
                  size: 20,
                ),
              )
            else
              const Icon(
                CupertinoIcons.chevron_right,
                color: HamoColors.darkTextDisabled,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProtocolBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? backgroundColor;

  const _ProtocolBadge({
    required this.label,
    required this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: backgroundColor != null ? HamoColors.darkTextSecondary : color,
          fontFamily: 'SFPro',
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}