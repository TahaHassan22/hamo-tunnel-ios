// Server Selector - Tap to navigate to server list

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../core/theme/hamo_colors.dart';
import '../../core/constants/hamo_constants.dart';
import '../../core/storage/preferences_service.dart';
import '../../core/vpn/vpn_service.dart';

class ServerSelector extends StatelessWidget {
  final String currentServer;
  final VoidCallback onTap;

  const ServerSelector({
    super.key,
    required this.currentServer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<VpnService>(
      builder: (context, vpnService, child) {
        final isConnected = vpnService.isConnected;
        final displayName = currentServer.isNotEmpty ? currentServer : 'Select Server';
        final subtitle = isConnected
            ? 'Connected • Tap to change'
            : 'Tap to select a server';

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HamoColors.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HamoColors.darkDivider),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HamoColors.primaryOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.cloud,
                    color: HamoColors.primaryOrange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: HamoColors.darkTextPrimary,
                          fontFamily: 'SFPro',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: HamoColors.darkTextSecondary,
                          fontFamily: 'SFPro',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: HamoColors.darkTextDisabled,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}