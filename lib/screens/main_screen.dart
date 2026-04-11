import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_notifier.dart';
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

  void _jumpToProfile() {
    setState(() => _currentIndex = 3);
  }

  @override
  Widget build(BuildContext context) {
    const screens = [
      HomeScreen(),
      RegionsScreen(),
      AnalysisScreen(),
      ProfileScreen(),
    ];

    return TabNavigator(
      jumpToProfile: _jumpToProfile,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: _BottomNav(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        border: Border(
            top: BorderSide(color: Color(0xFF242424), width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: const Color(0xFFC0392B),
        unselectedItemColor: const Color(0xFF555555),
        selectedFontSize: 9,
        unselectedFontSize: 9,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Inicio'),
          BottomNavigationBarItem(
              icon: Icon(Icons.language_outlined), label: 'Regiones'),
          BottomNavigationBarItem(
              icon: Icon(Icons.article_outlined), label: 'Análisis'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Text(label,
            style: const TextStyle(color: Color(0xFF555555), fontSize: 16)),
      ),
    );
  }
}