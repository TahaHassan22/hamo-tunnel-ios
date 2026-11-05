// Logs Screen - VPN connection logs
// Mirrors Android HamoTunnelPlusLog and LogcatActivity

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/hamo_colors.dart';
import '../../core/constants/hamo_constants.dart';
import '../../core/vpn/vpn_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final List<LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _addLog(LogEntry.info('Hamo Tunnel iOS started'));
    _addLog(LogEntry.info('Waiting for connection...'));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addLog(LogEntry entry) {
    setState(() {
      _logs.insert(0, entry);
      if (_logs.length > HamoConstants.maxLogLines) {
        _logs.removeLast();
      }
    });
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _clearLogs() {
    setState(() => _logs.clear());
  }

  void _copyLogs() {
    final text = _logs.map((e) => e.toString()).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VpnService>(
      builder: (context, vpnService, child) {
        return CupertinoPageScaffold(
          backgroundColor: HamoColors.darkBackground,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: HamoColors.darkBackground,
            border: const Border(bottom: BorderSide(color: HamoColors.darkDivider, width: 0.5)),
            middle: const Text(
              'Logs',
              style: TextStyle(
                fontFamily: 'SFPro',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: HamoColors.darkTextPrimary,
              ),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showLogActions(context),
              child: const Icon(
                CupertinoIcons.ellipsis_circle,
                color: HamoColors.primaryOrange,
                size: 26,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Log List
                Expanded(
                  child: _logs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.doc_text,
                                color: HamoColors.darkTextDisabled,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No logs yet',
                                style: TextStyle(
                                  color: HamoColors.darkTextSecondary,
                                  fontFamily: 'SFPro',
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return _LogTile(log: log);
                          },
                        ),
                ),

                // Auto-scroll toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: HamoColors.darkSurface,
                    border: Border(top: BorderSide(color: HamoColors.darkDivider)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoSwitch(
                        value: _autoScroll,
                        onChanged: (value) => setState(() => _autoScroll = value),
                        activeColor: HamoColors.primaryOrange,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Auto-scroll',
                        style: TextStyle(
                          color: HamoColors.darkTextSecondary,
                          fontFamily: 'SFPro',
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogActions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Log Actions'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _copyLogs();
            },
            child: const Text('Copy All Logs'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _clearLogs();
            },
            child: const Text('Clear Logs'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;

  LogEntry._(this.timestamp, this.level, this.message);

  factory LogEntry.info(String message) => LogEntry._(DateTime.now(), LogLevel.info, message);
  factory LogEntry.warning(String message) => LogEntry._(DateTime.now(), LogLevel.warning, message);
  factory LogEntry.error(String message) => LogEntry._(DateTime.now(), LogLevel.error, message);
  factory LogEntry.debug(String message) => LogEntry._(DateTime.now(), LogLevel.debug, message);

  Color get color {
    switch (level) {
      case LogLevel.info:
        return HamoColors.infoBlue;
      case LogLevel.warning:
        return HamoColors.warningAmber;
      case LogLevel.error:
        return HamoColors.disconnectedRed;
      case LogLevel.debug:
        return HamoColors.darkTextDisabled;
    }
  }

  IconData get icon {
    switch (level) {
      case LogLevel.info:
        return CupertinoIcons.info;
      case LogLevel.warning:
        return CupertinoIcons.exclamationmark_triangle;
      case LogLevel.error:
        return CupertinoIcons.xmark_circle;
      case LogLevel.debug:
        return CupertinoIcons.chevron_left_slash_chevron_right;
    }
  }

  String get levelLabel {
    switch (level) {
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.debug:
        return 'DEBUG';
    }
  }

  @override
  String toString() {
    return '[${timestamp.toIso8601String()}] [$levelLabel] $message';
  }
}

enum LogLevel { info, warning, error, debug }

class _LogTile extends StatelessWidget {
  final LogEntry log;

  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HamoColors.darkSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: log.color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(log.icon, color: log.color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      log.levelLabel,
                      style: TextStyle(
                        color: log.color,
                        fontFamily: 'SFPro',
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(log.timestamp),
                      style: const TextStyle(
                        color: HamoColors.darkTextDisabled,
                        fontFamily: 'SFPro',
                        fontSize: 10,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  log.message,
                  style: const TextStyle(
                    color: HamoColors.darkTextPrimary,
                    fontFamily: 'SFPro',
                    fontSize: 13,
                    fontFamilyFallback: ['Menlo', 'Monospace'],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}.${dt.millisecond.toString().padLeft(3, '0')}';
  }
}