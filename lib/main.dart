import 'package:archi_manager/core/supabase_config.dart';
import 'package:archi_manager/screens/parametres_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'constants/colors.dart';
import 'models/nav_item.dart';
import 'service/notification_service.dart';
import 'screens/analytics_screen.dart';
import 'screens/carte_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/equipe_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/projets_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'service/auth_service.dart';
import 'widgets/sidebar_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();
  runApp(const ArchiManagerApp());
}

class ArchiManagerApp extends StatelessWidget {
  const ArchiManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ArchiManager',
      debugShowCheckedModeBanner: false,
      // ── Localisation française (requis pour DatePicker en FR) ──────────
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
      // ──────────────────────────────────────────────────────────────────
      theme: ThemeData(
        fontFamily: 'Segoe UI',
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(seedColor: kAccent),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/login':    (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home':     (_) => const _AppShell(),
      },
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();
  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedIndex = 0;
  int _notifCount    = 0;

  @override
  void initState() {
    super.initState();
    _refreshNotifCount();
  }

  Future<void> _refreshNotifCount() async {
    final count = await NotificationService.getUnreadCount();
    if (mounted) setState(() => _notifCount = count);
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:  return const DashboardScreen();
      case 1:  return const ProjetsScreen();
      case 2:  return const ClientsScreen();
      case 3:  return const EquipeScreen();
      case 4:  return const AnalyticsScreen();
      case 5:  return const CarteScreen();
      case 6:  return NotificationsScreen(onNotifChanged: _refreshNotifCount);
      case 7:  return const ParametresScreen();
      default: return _PlaceholderScreen(label: navItems[index].label);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final notifCount = _notifCount;
    final architecte = AuthService.currentUser;

    if (isWide) {
      return Scaffold(
        body: Row(children: [
          SidebarWidget(
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() => _selectedIndex = i),
            notifCount: notifCount,
            architecteNom: architecte?.fullName ?? 'Architecte',
            onLogout: _logout,
          ),
          Expanded(child: _buildPage(_selectedIndex)),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(LucideIcons.menu, color: Colors.white70, size: 22),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Row(children: [
          Icon(LucideIcons.building2, color: Colors.amber),
          SizedBox(width: 8),
          Text('ArchiManager', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        actions: [
          Stack(children: [
            IconButton(
              icon: const Icon(LucideIcons.bell, color: Colors.white70, size: 20),
              onPressed: () => setState(() => _selectedIndex = kNotifNavIndex),
            ),
            if (notifCount > 0)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
                  child: Center(child: Text('$notifCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                ),
              ),
          ]),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1F2937),
        child: SidebarContent(
          selectedIndex: _selectedIndex,
          onSelect: (i) {
            setState(() => _selectedIndex = i);
            Navigator.of(context).pop();
          },
          notifCount: notifCount,
          architecteNom: architecte?.fullName ?? 'Architecte',
          onLogout: _logout,
        ),
      ),
      body: _buildPage(_selectedIndex),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen({required this.label});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(LucideIcons.construction, size: 48, color: kTextSub),
      const SizedBox(height: 12),
      Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kTextMain)),
      const SizedBox(height: 6),
      const Text('Page en cours de développement', style: TextStyle(color: kTextSub, fontSize: 13)),
    ]),
  );
}