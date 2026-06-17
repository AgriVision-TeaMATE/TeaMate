import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const TeaMateApp());
}

class TeaMateApp extends StatelessWidget {
  const TeaMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriVision',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}
