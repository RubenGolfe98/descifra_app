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

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Fundido de la pestaña entrante; IndexedStack conserva el estado de todas
  late final _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: 1,
  );
  DateTime? _lastTabTap;
  final _scrollToTopNotifier = ValueNotifier<int?>(null);

  void _jumpToProfile() => _selectTab(3);

  void _selectTab(int index) {
    if (index != _currentIndex) _tabFade.forward(from: 0);
    setState(() => _currentIndex = index);
  }

  void _onTabTap(int index) {
    final now = DateTime.now();
    final isDoubleTap = index == _currentIndex &&
        _lastTabTap != null &&
        now.difference(_lastTabTap!) < const Duration(milliseconds: 300);
    _lastTabTap = now;
    _selectTab(index);
    if (isDoubleTap) {
      _scrollToTopNotifier.value = index;
      Future.microtask(() => _scrollToTopNotifier.value = null);
    }
  }

  @override
  void dispose() {
    _scrollToTopNotifier.dispose();
    _tabFade.dispose();
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
          body: FadeTransition(
            opacity: CurvedAnimation(parent: _tabFade, curve: Curves.easeOut),
            child: IndexedStack(index: _currentIndex, children: screens),
          ),
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
