import 'package:flutter/material.dart';

import 'factory_home_screen.dart';
import 'factory_settings_screen.dart';
import 'grade_history_screen.dart';

/// Bottom-nav shell for factory_manager users (tea quality grading flow).
/// Estate managers keep the existing MainScreen; this screen never links
/// into estate features.
class FactoryMainScreen extends StatefulWidget {
  const FactoryMainScreen({super.key});

  @override
  State<FactoryMainScreen> createState() => _FactoryMainScreenState();
}

class _FactoryMainScreenState extends State<FactoryMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const FactoryHomeScreen(),
    const GradeHistoryScreen(),
    const FactorySettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
