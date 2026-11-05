// Settings Screen - App configuration
// Mirrors Android settings + v2rayNG SettingsActivity

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/hamo_colors.dart';
import '../../core/constants/hamo_constants.dart';
import '../../core/storage/preferences_service.dart';
import '../../core/vpn/vpn_service.dart';
import '../../shared/widgets/settings_section.dart';
import '../../shared/widgets/settings_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PreferencesService>(
      builder: (context, prefs, child) {
        return CupertinoPageScaffold(
          backgroundColor: HamoColors.darkBackground,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: HamoColors.darkBackground,
            border: const Border(bottom: BorderSide(color: HamoColors.darkDivider, width: 0.5)),
            middle: const Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'SFPro',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: HamoColors.darkTextPrimary,
              ),
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // VPN Settings
                SettingsSection(
                  title: 'VPN Configuration',
                  children: [
                    SettingsTile(
                      title: 'Protocol',
                      subtitle: VpnProtocol.fromValue(prefs.vpnMode).displayName,
                      leading: const Icon(CupertinoIcons.antenna_radiowaves_left_right, color: HamoColors.primaryOrange),
                      onTap: () => _showProtocolPicker(context, prefs),
                    ),
                    SettingsTile(
                      title: 'Tunnel Type',
                      subtitle: TunnelType.fromValue(prefs.tunnelType).displayName,
                      leading: const Icon(CupertinoIcons.cloud, color: HamoColors.infoBlue),
                      onTap: () => _showTunnelTypePicker(context, prefs),
                    ),
                    SettingsTile(
                      title: 'Payload Mode',
                      subtitle: PayloadMode.fromValue(prefs.payloadMode).displayName,
                      leading: const Icon(CupertinoIcons.doc_text, color: HamoColors.connectedGreen),
                      onTap: () => _showPayloadModePicker(context, prefs),
                    ),
                    SettingsTile(
                      title: 'Custom DNS',
                      subtitle: prefs.customDns.isEmpty ? 'Default (1.1.1.1)' : prefs.customDns,
                      leading: const Icon(CupertinoIcons.globe, color: HamoColors.warningAmber),
                      onTap: () => _showCustomDnsDialog(context, prefs),
                    ),
                    SettingsTile(
                      title: 'Auto Connect on Launch',
                      trailing: CupertinoSwitch(
                        value: prefs.autoStart,
                        onChanged: (value) => prefs.set(HamoConstants.prefsAutoStart, value),
                        activeColor: HamoColors.primaryOrange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // V2Ray Settings
                SettingsSection(
                  title: 'V2Ray Configuration',
                  children: [
                    SettingsTile(
                      title: 'V2Ray UUID',
                      subtitle: prefs.v2rayUuid.isEmpty ? 'Not configured' : '${prefs.v2rayUuid.substring(0, 8)}...',
                      leading: const Icon(CupertinoIcons.lock_shield, color: HamoColors.protocolV2Ray),
                      onTap: () => _showV2RayUuidDialog(context, prefs),
                    ),
                    SettingsTile(
                      title: 'V2Ray Type',
                      subtitle: _getV2RayTypeLabel(prefs.v2rayType),
                      leading: const Icon(CupertinoIcons.arrow_2_squarepath, color: HamoColors.protocolV2Ray),
                      onTap: () => _showV2RayTypePicker(context, prefs),
                    ),
                    SettingsTile(
                      title: 'Allow Insecure TLS',
                      trailing: CupertinoSwitch(
                        value: prefs.allowInsecure,
                        onChanged: (value) => prefs.set(HamoConstants.prefsAllowInsecure, value),
                        activeColor: HamoColors.primaryOrange,
                      ),
                    ),
                    SettingsTile(
                      title: 'Custom V2Ray Config',
                      subtitle: prefs.customV2RayConfig ? 'Enabled' : 'Disabled',
                      trailing: CupertinoSwitch(
                        value: prefs.customV2RayConfig,
                        onChanged: (value) => prefs.set(HamoConstants.prefsCustomV2RayConfig, value),
                        activeColor: HamoColors.primaryOrange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Security Settings
                SettingsSection(
                  title: 'Security',
                  children: [
                    SettingsTile(
                      title: 'PIN Protection',
                      subtitle: prefs.pinEnabled ? 'Enabled' : 'Disabled',
                      trailing: CupertinoSwitch(
                        value: prefs.pinEnabled,
                        onChanged: (value) {
                          if (value && prefs.pinCode.isEmpty) {
                            _showSetPinDialog(context, prefs);
                          } else {
                            prefs.set(HamoConstants.prefsPinEnabled, value);
                          }
                        },
                        activeColor: HamoColors.primaryOrange,
                      ),
                    ),
                    SettingsTile(
                      title: 'Change PIN',
                      subtitle: prefs.pinEnabled ? '\u2022\u2022\u2022\u2022\u2022\u2022' : 'Not set',
                      leading: const Icon(CupertinoIcons.lock, color: HamoColors.warningAmber),
                      onTap: prefs.pinEnabled ? () => _showSetPinDialog(context, prefs) : null,
                    ),
                    SettingsTile(
                      title: 'Clear All Data',
                      subtitle: 'Reset app to defaults',
                      isDestructive: true,
                      leading: const Icon(CupertinoIcons.trash, color: HamoColors.disconnectedRed),
                      onTap: () => _showClearDataDialog(context),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // About & Links
                SettingsSection(
                  title: 'About',
                  children: [
                    SettingsTile(
                      title: 'Version',
                      subtitle: '${HamoConstants.version} (${HamoConstants.buildNumber})',
                      leading: const Icon(CupertinoIcons.info, color: HamoColors.darkTextDisabled),
                    ),
                    SettingsTile(
                      title: 'Telegram Channel',
                      subtitle: 'Join for updates & support',
                      leading: const Icon(CupertinoIcons.paperplane, color: HamoColors.infoBlue),
                      onTap: () => _launchUrl(HamoConstants.telegramChannelUrl),
                    ),
                    SettingsTile(
                      title: 'GitHub Repository',
                      subtitle: 'View source & report issues',
                      leading: const Icon(CupertinoIcons.link, color: HamoColors.darkTextSecondary),
                      onTap: () => _launchUrl(HamoConstants.githubRepoUrl),
                    ),
                    SettingsTile(
                      title: 'OpenVPN Config Template',
                      subtitle: 'View default configuration',
                      leading: const Icon(CupertinoIcons.doc_text, color: HamoColors.protocolOpenVPN),
                      onTap: () => _showOpenVPNTemplate(context),
                    ),
                    SettingsTile(
                      title: 'V2Ray Config Template',
                      subtitle: 'View default configuration',
                      leading: const Icon(CupertinoIcons.doc_text, color: HamoColors.protocolV2Ray),
                      onTap: () => _showV2RayTemplate(context),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Build info
                Center(
                  child: Text(
                    'Hamo Tunnel ${HamoConstants.version}\nBuild ${HamoConstants.buildNumber} \u2022 iOS 15.0+',
                    style: const TextStyle(
                      color: HamoColors.darkTextDisabled,
                      fontFamily: 'SFPro',
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getV2RayTypeLabel(int type) {
    switch (type) {
      case 0:
        return 'VMess WS';
      case 1:
        return 'VMess gRPC (gun)';
      case 2:
        return 'VMess gRPC (multi)';
      case 3:
        return 'VLESS WS';
      case 4:
        return 'VLESS gRPC';
      case 5:
        return 'VLESS WS (none)';
      default:
        return 'Unknown';
    }
  }

  void _showProtocolPicker(BuildContext context, PreferencesService prefs) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Protocol'),
        actions: VpnProtocol.values.map((p) => CupertinoActionSheetAction(
          onPressed: () {
            prefs.vpnMode = p.value;
            Navigator.pop(context);
          },
          child: Text(p.displayName),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showTunnelTypePicker(BuildContext context, PreferencesService prefs) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Tunnel Type'),
        actions: TunnelType.values.map((t) => CupertinoActionSheetAction(
          onPressed: () {
            prefs.tunnelType = t.value;
            Navigator.pop(context);
          },
          child: Text(t.displayName),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showPayloadModePicker(BuildContext context, PreferencesService prefs) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Payload Mode'),
        actions: PayloadMode.values.map((p) => CupertinoActionSheetAction(
          onPressed: () {
            prefs.payloadMode = p.value;
            Navigator.pop(context);
          },
          child: Text(p.displayName),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showCustomDnsDialog(BuildContext context, PreferencesService prefs) {
    final controller = TextEditingController(text: prefs.customDns);
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Custom DNS'),
        content: CupertinoTextField(
          controller: controller,
          placeholder: 'e.g., 1.1.1.1, 8.8.8.8',
          style: const TextStyle(color: HamoColors.darkTextPrimary, fontFamily: 'SFPro'),
          decoration: BoxDecoration(
            color: HamoColors.darkSurface,
            border: Border.all(color: HamoColors.darkDivider),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              prefs.customDns = controller.text.trim();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showV2RayUuidDialog(BuildContext context, PreferencesService prefs) {
    final controller = TextEditingController(text: prefs.v2rayUuid);
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('V2Ray UUID'),
        content: CupertinoTextField(
          controller: controller,
          placeholder: 'Enter UUID',
          style: const TextStyle(color: HamoColors.darkTextPrimary, fontFamily: 'SFPro'),
          decoration: BoxDecoration(
            color: HamoColors.darkSurface,
            border: Border.all(color: HamoColors.darkDivider),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              prefs.v2rayUuid = controller.text.trim();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showV2RayTypePicker(BuildContext context, PreferencesService prefs) {
    final types = [
      (0, 'VMess WS'),
      (1, 'VMess gRPC (gun)'),
      (2, 'VMess gRPC (multi)'),
      (3, 'VLESS WS'),
      (4, 'VLESS gRPC'),
      (5, 'VLESS WS (none)'),
    ];

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select V2Ray Type'),
        actions: types.map((t) => CupertinoActionSheetAction(
          onPressed: () {
            prefs.v2rayType = t.$1;
            Navigator.pop(context);
          },
          child: Text(t.$2),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showSetPinDialog(BuildContext context, PreferencesService prefs) {
    final controller = TextEditingController(text: prefs.pinCode);
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(prefs.pinCode.isEmpty ? 'Set PIN' : 'Change PIN'),
        content: CupertinoTextField(
          controller: controller,
          placeholder: '4-6 digits',
          keyboardType: TextInputType.number,
          obscureText: true,
          style: const TextStyle(color: HamoColors.darkTextPrimary, fontFamily: 'SFPro'),
          decoration: BoxDecoration(
            color: HamoColors.darkSurface,
            border: Border.all(color: HamoColors.darkDivider),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final pin = controller.text.trim();
              if (pin.length >= HamoConstants.pinMinLength && pin.length <= HamoConstants.pinMaxLength) {
                prefs.pinCode = pin;
                prefs.pinEnabled = true;
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'Are you sure you want to clear all data? This will reset all settings, '
          'server configurations, and credentials. This action cannot be undone.',
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showOpenVPNTemplate(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('OpenVPN Template'),
        message: Text(HamoConstants.defaultOpenVPNConfig),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: HamoConstants.defaultOpenVPNConfig));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy to Clipboard'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ),
    );
  }

  void _showV2RayTemplate(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('V2Ray Template'),
        message: Text(HamoConstants.defaultV2RayConfig),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: HamoConstants.defaultV2RayConfig));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy to Clipboard'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ),
    );
  }
}