// Hamo Tunnel Color Palette
// Extracted from Hamo Tunnel Plus Android APK (v3.2)
// Primary: Orange #F97910
// Dark Background: #121212

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Hamo Tunnel brand colors extracted from the Android APK
class HamoColors {
  // Primary brand colors
  static const Color primaryOrange = Color(0xFFF97910);
  static const Color primaryOrangeLight = Color(0xFFFF9F43);
  static const Color primaryOrangeDark = Color(0xFFE66B00);

  // Dark theme colors (primary app theme)
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceElevated = Color(0xFF2C2C2C);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color darkDivider = Color(0xFF333333);

  // Light theme colors (fallback)
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF5F5F5);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE0E0E0);

  // Text colors
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextDisabled = Color(0xFF666666);
  static const Color darkTextOnPrimary = Color(0xFF000000);

  static const Color lightTextPrimary = Color(0xFF121212);
  static const Color lightTextSecondary = Color(0xFF666666);
  static const Color lightTextDisabled = Color(0xFF999999);
  static const Color lightTextOnPrimary = Color(0xFFFFFFFF);

  // Status colors
  static const Color connectedGreen = Color(0xFF00C853);
  static const Color connectingOrange = Color(0xFFF97910);
  static const Color disconnectedRed = Color(0xFFFF3D00);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color infoBlue = Color(0xFF2979FF);

  // VPN Protocol colors (for UI indicators)
  static const Color protocolOpenVPN = Color(0xFF00BFA5); // Teal
  static const Color protocolSSH = Color(0xFF673AB7);      // Deep Purple
  static const Color protocolV2Ray = Color(0xFFF97910);    // Orange (brand)
  static const Color protocolUDP = Color(0xFF00BCD4);      // Cyan

  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryOrange, primaryOrangeLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [darkSurface, darkSurfaceElevated],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient connectedGradient = LinearGradient(
    colors: [connectedGreen, Color(0xFF00E676)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient disconnectedGradient = LinearGradient(
    colors: [disconnectedRed, Color(0xFFFF5252)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Hamo Tunnel theme configuration
class HamoTheme {
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: HamoColors.primaryOrange,
      secondary: HamoColors.primaryOrangeLight,
      tertiary: HamoColors.primaryOrangeDark,
      surface: HamoColors.darkSurface,
      surfaceContainer: HamoColors.darkSurfaceElevated,
      surfaceContainerHighest: HamoColors.darkCard,
      onPrimary: HamoColors.darkTextOnPrimary,
      onSecondary: HamoColors.darkTextOnPrimary,
      onSurface: HamoColors.darkTextPrimary,
      onSurfaceVariant: HamoColors.darkTextSecondary,
      outline: HamoColors.darkDivider,
      outlineVariant: HamoColors.darkDivider,
      error: HamoColors.disconnectedRed,
      onError: HamoColors.darkTextOnPrimary,
    ),
    scaffoldBackgroundColor: HamoColors.darkBackground,
    cardColor: HamoColors.darkCard,
    dividerColor: HamoColors.darkDivider,
    appBarTheme: const AppBarTheme(
      backgroundColor: HamoColors.darkBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: HamoColors.darkTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: 'SFPro',
      ),
      iconTheme: IconThemeData(color: HamoColors.darkTextPrimary),
    ),
    cardTheme: CardTheme(
      color: HamoColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HamoColors.darkDivider, width: 0.5),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HamoColors.primaryOrange,
        foregroundColor: HamoColors.darkTextOnPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'SFPro',
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: HamoColors.primaryOrange,
        side: const BorderSide(color: HamoColors.primaryOrange, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'SFPro',
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: HamoColors.primaryOrange,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'SFPro',
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: HamoColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HamoColors.darkDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HamoColors.darkDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HamoColors.primaryOrange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HamoColors.disconnectedRed),
      ),
      labelStyle: const TextStyle(
        color: HamoColors.darkTextSecondary,
        fontFamily: 'SFPro',
      ),
      hintStyle: const TextStyle(
        color: HamoColors.darkTextDisabled,
        fontFamily: 'SFPro',
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: HamoColors.darkSurface,
      selectedItemColor: HamoColors.primaryOrange,
      unselectedItemColor: HamoColors.darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontFamily: 'SFPro', fontWeight: FontWeight.w500),
      unselectedLabelStyle: TextStyle(fontFamily: 'SFPro', fontWeight: FontWeight.w400),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: HamoColors.darkSurface,
      indicatorColor: HamoColors.primaryOrange.withOpacity(0.15),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: HamoColors.primaryOrange,
            fontFamily: 'SFPro',
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }
        return const TextStyle(
          color: HamoColors.darkTextSecondary,
          fontFamily: 'SFPro',
          fontWeight: FontWeight.w400,
          fontSize: 12,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: HamoColors.primaryOrange, size: 24);
        }
        return const IconThemeData(color: HamoColors.darkTextSecondary, size: 24);
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: HamoColors.primaryOrange,
      inactiveTrackColor: HamoColors.darkDivider,
      thumbColor: HamoColors.primaryOrange,
      overlayColor: HamoColors.primaryOrange.withOpacity(0.2),
      trackHeight: 4,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return HamoColors.primaryOrange;
        }
        return HamoColors.darkDivider;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return HamoColors.primaryOrange.withOpacity(0.5);
        }
        return HamoColors.darkDivider;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return HamoColors.primaryOrange;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(HamoColors.darkTextOnPrimary),
      side: const BorderSide(color: HamoColors.darkDivider, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return HamoColors.primaryOrange;
        }
        return HamoColors.darkDivider;
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: HamoColors.primaryOrange,
      linearTrackColor: HamoColors.darkDivider,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: HamoColors.darkSurfaceElevated,
      contentTextStyle: const TextStyle(
        color: HamoColors.darkTextPrimary,
        fontFamily: 'SFPro',
      ),
      actionTextColor: HamoColors.primaryOrange,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: HamoColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        color: HamoColors.darkTextPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'SFPro',
      ),
      contentTextStyle: const TextStyle(
        color: HamoColors.darkTextSecondary,
        fontSize: 16,
        fontFamily: 'SFPro',
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: HamoColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      modalBarrierColor: Color(0xCC000000),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: HamoColors.primaryOrange,
      unselectedLabelColor: HamoColors.darkTextSecondary,
      indicatorColor: HamoColors.primaryOrange,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(fontFamily: 'SFPro', fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontFamily: 'SFPro', fontWeight: FontWeight.w400),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: HamoColors.darkTextPrimary,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w700,
        fontSize: 32,
      ),
      displayMedium: TextStyle(
        color: HamoColors.darkTextPrimary,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w600,
        fontSize: 28,
      ),
      displaySmall: TextStyle(
        color: HamoColors.darkTextPrimary,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w600,
        fontSize: 24,
      ),
      headlineLarge: TextStyle(
        color: HamoColors.darkTextPrimary,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w600,
        fontSize: 22,
      ),
      headlineMedium: TextStyle(
        color: HamoColors.darkTextPrimary,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
      headlineSmall: TextStyle(
        color: HamoColors.darkTextPrimary,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      titleLarge: TextStyle(
        color: HamoColors.darkTextPrimary,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      titleMedium: TextStyle(
        color: HamoColors.darkTextPrimary,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      titleSmall: TextStyle(
        color: HamoColors.darkTextSecondary,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      bodyLarge: TextStyle(
        color: HamoColors.darkTextPrimary,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w400,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: HamoColors.darkTextSecondary,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w400,
        fontSize: 14,
      ),
      bodySmall: TextStyle(
        color: HamoColors.darkTextDisabled,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w400,
        fontSize: 12,
      ),
      labelLarge: TextStyle(
        color: HamoColors.darkTextPrimary,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      labelMedium: TextStyle(
        color: HamoColors.darkTextSecondary,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
      labelSmall: TextStyle(
        color: HamoColors.darkTextDisabled,
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w500,
        fontSize: 10,
      ),
    ),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: HamoColors.primaryOrange,
      secondary: HamoColors.primaryOrangeLight,
      tertiary: HamoColors.primaryOrangeDark,
      surface: HamoColors.lightSurface,
      surfaceContainer: HamoColors.lightSurfaceElevated,
      surfaceContainerHighest: HamoColors.lightCard,
      onPrimary: HamoColors.lightTextOnPrimary,
      onSecondary: HamoColors.lightTextOnPrimary,
      onSurface: HamoColors.lightTextPrimary,
      onSurfaceVariant: HamoColors.lightTextSecondary,
      outline: HamoColors.lightDivider,
      outlineVariant: HamoColors.lightDivider,
      error: HamoColors.disconnectedRed,
      onError: HamoColors.lightTextOnPrimary,
    ),
    scaffoldBackgroundColor: HamoColors.lightBackground,
    cardColor: HamoColors.lightCard,
    dividerColor: HamoColors.lightDivider,
    fontFamily: 'SFPro',
  );
}

/// Cupertino theme for iOS-style widgets
class HamoCupertinoTheme {
  static CupertinoThemeData darkTheme = const CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: HamoColors.primaryOrange,
    scaffoldBackgroundColor: HamoColors.darkBackground,
    barBackgroundColor: HamoColors.darkBackground,
    textTheme: CupertinoTextThemeData(
      primaryColor: HamoColors.darkTextPrimary,
      textStyle: TextStyle(fontFamily: 'SFPro', color: HamoColors.darkTextPrimary),
      navTitleTextStyle: TextStyle(
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w600,
        fontSize: 17,
        color: HamoColors.darkTextPrimary,
      ),
      navLargeTitleTextStyle: TextStyle(
        fontFamily: 'SFPro',
        fontWeight: FontWeight.w700,
        fontSize: 34,
        color: HamoColors.darkTextPrimary,
      ),
      tabLabelTextStyle: TextStyle(
        fontFamily: 'SFPro',
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  static CupertinoThemeData lightTheme = const CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: HamoColors.primaryOrange,
    scaffoldBackgroundColor: HamoColors.lightBackground,
    barBackgroundColor: HamoColors.lightBackground,
    textTheme: CupertinoTextThemeData(
      primaryColor: HamoColors.lightTextPrimary,
      textStyle: TextStyle(fontFamily: 'SFPro', color: HamoColors.lightTextPrimary),
    ),
  );
}