// Hamo Tunnel - Main Entry Point
// iOS VPN Client based on Hamo Tunnel Plus Android architecture

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'core/theme/hamo_colors.dart';
import 'core/constants/hamo_constants.dart';
import 'core/storage/preferences_service.dart';
import 'core/vpn/vpn_service.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/servers/server_list_screen.dart';
import 'features/logs/logs_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await PreferencesService.instance.initialize();
  await VpnService.instance.initialize();
  
  runApp(const HamoTunnelApp());
}

class HamoTunnelApp extends StatelessWidget {
  const HamoTunnelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VpnService.instance),
        ChangeNotifierProvider(create: (_) => PreferencesService.instance),
      ],
      child: MaterialApp(
        title: HamoConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: HamoTheme.darkTheme,
        darkTheme: HamoTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const MainNavigationScreen(),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/servers': (context) => const ServerListScreen(),
          '/logs': (context) => const LogsScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
        onGenerateRoute: (settings) {
          return CupertinoPageRoute(
            builder: (context) => const MainNavigationScreen(),
            settings: settings,
          );
        },
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  final List<Widget> _screens = const [
    HomeScreen(),
    ServerListScreen(),
    LogsScreen(),
    SettingsScreen(),
  ];

  final List<NavigationDestination> _navItems = const [
    NavigationDestination(
      icon: Icon(CupertinoIcons.house),
      selectedIcon: Icon(CupertinoIcons.house_fill),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(CupertinoIcons.cloud),
      selectedIcon: Icon(CupertinoIcons.cloud_fill),
      label: 'Servers',
    ),
    NavigationDestination(
      icon: Icon(CupertinoIcons.doc_text),
      selectedIcon: Icon(CupertinoIcons.doc_text_fill),
      label: 'Logs',
    ),
    NavigationDestination(
      icon: Icon(CupertinoIcons.gear),
      selectedIcon: Icon(CupertinoIcons.gear_alt_fill),
      label: 'Settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          _pageController.animateToPage(
            index,
            duration: HamoConstants.animationDuration,
            curve: Curves.easeInOut,
          );
        },
        destinations: _navItems,
      ),
    );
  }
}