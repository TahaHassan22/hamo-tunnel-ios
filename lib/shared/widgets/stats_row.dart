
import 'package:flutter/cupertino.dart';
// Stats Row - Shows upload/download speeds and totals

import 'package:flutter/material.dart';
import '../../core/theme/hamo_colors.dart';
import '../../core/constants/hamo_constants.dart';

class StatsRow extends StatelessWidget {
  final int uploadSpeed; // bytes/sec
  final int downloadSpeed; // bytes/sec
  final int totalUpload;
  final int totalDownload;

  const StatsRow({
    super.key,
    required this.uploadSpeed,
    required this.downloadSpeed,
    required this.totalUpload,
    required this.totalDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Upload',
            speed: uploadSpeed,
            total: totalUpload,
            icon: CupertinoIcons.arrow_up,
            color: HamoColors.infoBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Download',
            speed: downloadSpeed,
            total: totalDownload,
            icon: CupertinoIcons.arrow_down,
            color: HamoColors.connectedGreen,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int speed;
  final int total;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.speed,
    required this.total,
    required this.icon,
    required this.color,
  });

  String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec} B/s';
    if (bytesPerSec < 1024 * 1024) return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String _formatTotal(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HamoColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: HamoColors.darkTextSecondary,
                  fontFamily: 'SFPro',
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatSpeed(speed),
            style: TextStyle(
              color: color,
              fontFamily: 'SFPro',
              fontWeight: FontWeight.w600,
              fontSize: 20,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total: ${_formatTotal(total)}',
            style: const TextStyle(
              color: HamoColors.darkTextDisabled,
              fontFamily: 'SFPro',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}