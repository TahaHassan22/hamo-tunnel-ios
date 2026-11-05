// Settings Section - Grouped settings with title

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../core/theme/hamo_colors.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: HamoColors.darkTextDisabled,
              fontFamily: 'SFPro',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: HamoColors.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HamoColors.darkDivider),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}