import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_notifier.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/offline_banner.dart';
import 'home_screen.dart';
import 'regions_screen.dart';
import 'analysis_screen.dart';
import 'profile_screen.dart';
import '../widgets/paywall_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void _jumpToProfile() => setState(() => _currentIndex = 3);

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;

    const screens = [
      HomeScreen(),
      RegionsScreen(),
      AnalysisScreen(),
      ProfileScreen(),
    ];

    return TabNavigator(
      jumpToProfile: _jumpToProfile,
      child: Scaffold(
        backgroundColor: AppColors.bg(isDark),
        body: IndexedStack(index: _currentIndex, children: screens),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OfflineBanner(),
            _BottomNav(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _BottomNav({required this.currentIndex, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surf(isDark),
        border: Border(top: BorderSide(color: AppColors.bord(isDark), width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSec(isDark),
        selectedFontSize: 9,
        unselectedFontSize: 9,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.language_outlined), label: 'Regiones'),
          BottomNavigationBarItem(icon: Icon(Icons.article_outlined), label: 'Análisis'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}