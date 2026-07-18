import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/onboarding/splash_screen.dart';

void main() {
  runApp(const TeaMateApp());
}

class TeaMateApp extends StatelessWidget {
  const TeaMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeaMate',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
