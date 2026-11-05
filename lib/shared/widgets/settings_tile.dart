// Settings Tile - Individual setting row

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../core/theme/hamo_colors.dart';

class SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: HamoColors.darkDivider.withOpacity(0.5),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive
                            ? HamoColors.disconnectedRed
                            : (enabled ? HamoColors.darkTextPrimary : HamoColors.darkTextDisabled),
                        fontFamily: 'SFPro',
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: enabled ? HamoColors.darkTextSecondary : HamoColors.darkTextDisabled,
                          fontFamily: 'SFPro',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ] else if (onTap != null) ...[
                const SizedBox(width: 12),
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: HamoColors.darkTextDisabled,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}