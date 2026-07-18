import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<AuthUser?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthService().fetchProfile();
  }

  void _logout() {
    AuthService().logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Log out?'),
          content: const Text('You will need to sign in again to use TeaMate.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && mounted) {
      _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<AuthUser?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final user = snapshot.data ?? AuthService().currentUser;
          final name = user?.fullName ?? 'TeaMate User';
          final email = user?.email ?? 'Not available';
          final role = (user?.role ?? 'estate_manager').replaceAll('_', ' ');

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE4E9DE)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryButton.withValues(alpha: 0.06),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.brandGreen.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppTheme.primaryButton,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brandGreen.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          color: AppTheme.primaryButton,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryButton,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
