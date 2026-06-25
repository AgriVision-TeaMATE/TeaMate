import 'package:flutter/material.dart';
import '../models/field_model.dart';
import 'dashboard_screen.dart';
import 'fields_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const FieldsScreen(),
    const NotificationsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FieldManager(),
      builder: (context, _) {
        final unreadCount = FieldManager().unreadNotificationCount;

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
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.agriculture_outlined),
                  activeIcon: Icon(Icons.agriculture),
                  label: 'Yield',
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  activeIcon: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Icon(Icons.notifications),
                  ),
                  label: 'Alerts',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
