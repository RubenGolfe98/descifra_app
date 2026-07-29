import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_notifier.dart';
import '../../theme/app_colors.dart';
import '../../widgets/offline_banner.dart';
import 'home_screen.dart';
import '../regions/regions_screen.dart';
import '../explore/explore_screen.dart';
import '../auth/profile_screen.dart';
import '../../widgets/access_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  DateTime? _lastTabTap;
  final _scrollToTopNotifier = ValueNotifier<int?>(null);

  void _jumpToProfile() => setState(() => _currentIndex = 3);

  void _onTabTap(int index) {
    final now = DateTime.now();
    final isDoubleTap = index == _currentIndex &&
        _lastTabTap != null &&
        now.difference(_lastTabTap!) < const Duration(milliseconds: 300);
    _lastTabTap = now;
    setState(() => _currentIndex = index);
    if (isDoubleTap) {
      _scrollToTopNotifier.value = index;
      Future.microtask(() => _scrollToTopNotifier.value = null);
    }
  }

  @override
  void dispose() {
    _scrollToTopNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);

    const screens = [
      HomeScreen(),
      RegionsScreen(),
      ExploreScreen(),
      ProfileScreen(),
    ];

    return TabNavigator(
      jumpToProfile: _jumpToProfile,
      child: ChangeNotifierProvider.value(
        value: _scrollToTopNotifier,
        child: Scaffold(
          backgroundColor: AppColors.bg(isDark),
          body: IndexedStack(index: _currentIndex, children: screens),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OfflineBanner(),
              _BottomNav(
                currentIndex: _currentIndex,
                onTap: _onTabTap,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _BottomNav(
      {required this.currentIndex, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surf(isDark),
        border:
            Border(top: BorderSide(color: AppColors.bord(isDark), width: 0.5)),
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
        iconSize: 30,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio'),
          BottomNavigationBarItem(
              icon: Icon(Icons.language_outlined),
              activeIcon: Icon(Icons.language),
              label: 'Regiones'),
          BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Explorar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil'),
        ],
      ),
    );
  }
}
