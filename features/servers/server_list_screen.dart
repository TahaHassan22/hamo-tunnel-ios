// Server List Screen - Manage VPN servers
// Mirrors Android server list with protocol/tunnel type filtering

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../core/theme/hamo_colors.dart';
import '../../core/constants/hamo_constants.dart';
import '../../core/storage/preferences_service.dart';
import '../../core/vpn/vpn_service.dart';
import '../../shared/widgets/server_card.dart';

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  HamoConstants.VpnProtocol? _filterProtocol;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PreferencesService>(
      builder: (context, prefs, child) {
        // Get servers from custom_payload.json equivalent
        final servers = _getMockServers(); // TODO: Load from actual config

        final filteredServers = servers.where((server) {
          final matchesSearch = server['name'].toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesProtocol = _filterProtocol == null || server['protocol'] == _filterProtocol;
          return matchesSearch && matchesProtocol;
        }).toList();

        return CupertinoPageScaffold(
          backgroundColor: HamoColors.darkBackground,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: HamoColors.darkBackground,
            border: const Border(bottom: BorderSide(color: HamoColors.darkDivider, width: 0.5)),
            middle: const Text(
              'Servers',
              style: TextStyle(
                fontFamily: 'SFPro',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: HamoColors.darkTextPrimary,
              ),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showAddServerDialog(context),
              child: const Icon(
                CupertinoIcons.add_circled,
                color: HamoColors.primaryOrange,
                size: 26,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Search & Filter Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CupertinoSearchTextField(
                        controller: _searchController,
                        placeholder: 'Search servers...',
                        style: const TextStyle(color: HamoColors.darkTextPrimary, fontFamily: 'SFPro'),
                        backgroundColor: HamoColors.darkSurface,
                        borderColor: HamoColors.darkDivider,
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                      const SizedBox(height: 12),
                      // Protocol Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All',
                              selected: _filterProtocol == null,
                              onTap: () => setState(() => _filterProtocol = null),
                            ),
                            const SizedBox(width: 8),
                            ...HamoConstants.VpnProtocol.values.map((p) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _FilterChip(
                                label: p.shortName,
                                selected: _filterProtocol == p,
                                onTap: () => setState(() => _filterProtocol = p),
                                color: _getProtocolColor(p),
                              ),
                            )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Server List
                Expanded(
                  child: filteredServers.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredServers.length,
                          itemBuilder: (context, index) {
                            final server = filteredServers[index];
                            final isSelected = prefs.selectedServer == server['name'];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ServerCard(
                                server: server,
                                isSelected: isSelected,
                                isConnected: false, // TODO: Check actual connection
                                onTap: () => _selectServer(context, server, prefs),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _getMockServers() {
    // TODO: Load from custom_payload.json / remote config
    return [
      {
        'name': 'US East - New York',
        'host': 'us-east.example.com',
        'protocol': HamoConstants.VpnProtocol.openvpnTcp,
        'tunnelType': HamoConstants.TunnelType.ssl,
        'payloadMode': HamoConstants.PayloadMode.cdn,
        'port': 443,
        'flag': '🇺🇸',
      },
      {
        'name': 'EU West - London',
        'host': 'eu-west.example.com',
        'protocol': HamoConstants.VpnProtocol.ssh,
        'tunnelType': HamoConstants.TunnelType.direct,
        'payloadMode': HamoConstants.PayloadMode.raw,
        'port': 22,
        'flag': '🇬🇧',
      },
      {
        'name': 'Asia - Singapore',
        'host': 'sg.example.com',
        'protocol': HamoConstants.VpnProtocol.v2ray,
        'tunnelType': HamoConstants.TunnelType.v2ray,
        'payloadMode': HamoConstants.PayloadMode.raw,
        'port': 10086,
        'flag': '🇸🇬',
      },
      {
        'name': 'US West - Los Angeles',
        'host': 'us-west.example.com',
        'protocol': HamoConstants.VpnProtocol.openvpnUdp,
        'tunnelType': HamoConstants.TunnelType.udp,
        'payloadMode': HamoConstants.PayloadMode.proxy,
        'port': 1194,
        'flag': '🇺🇸',
      },
    ];
  }

  Color _getProtocolColor(HamoConstants.VpnProtocol protocol) {
    switch (protocol) {
      case HamoConstants.VpnProtocol.openvpnTcp:
      case HamoConstants.VpnProtocol.openvpnUdp:
        return HamoColors.protocolOpenVPN;
      case HamoConstants.VpnProtocol.ssh:
      case HamoConstants.VpnProtocol.sshSpecial:
        return HamoColors.protocolSSH;
      case HamoConstants.VpnProtocol.v2ray:
        return HamoColors.protocolV2Ray;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HamoColors.darkSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.server,
              color: HamoColors.darkTextDisabled,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Servers Found',
            style: TextStyle(
              color: HamoColors.darkTextPrimary,
              fontFamily: 'SFPro',
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a server configuration to get started',
            style: TextStyle(
              color: HamoColors.darkTextSecondary,
              fontFamily: 'SFPro',
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: () => _showAddServerDialog(context),
            color: HamoColors.primaryOrange,
            child: const Text('Add Server'),
          ),
        ],
      ),
    );
  }

  void _selectServer(BuildContext context, Map<String, dynamic> server, PreferencesService prefs) {
    prefs.set(HamoConstants.prefsSelectedServer, server['name']);
    prefs.vpnMode = server['protocol'].value;
    prefs.tunnelType = server['tunnelType'].value;
    prefs.payloadMode = server['payloadMode'].value;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected ${server['name']}'),
        backgroundColor: HamoColors.darkSurface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddServerDialog(BuildContext context) {
    // TODO: Implement add server dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add Server dialog - TODO'),
        backgroundColor: HamoColors.darkSurface,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? HamoColors.primaryOrange;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? effectiveColor : HamoColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? effectiveColor : HamoColors.darkDivider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? HamoColors.darkTextOnPrimary : HamoColors.darkTextSecondary,
            fontFamily: 'SFPro',
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}