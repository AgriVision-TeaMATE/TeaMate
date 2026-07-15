import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _green = Color.fromARGB(255, 116, 195, 19);
  static const _buttonBlack = Color.fromARGB(255, 48, 48, 48);
  static const _background = Color.fromARGB(255, 254, 255, 253);
  static const _darkText = Color(0xFF1D1F22);
  static const _mutedText = Color(0xFF777D85);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compactHeight = constraints.maxHeight < 720;
              final bottomHeight = compactHeight ? 404.0 : 372.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 0,
                        right: 0,
                        top: compactHeight ? 0 : 8,
                        bottom: compactHeight ? 0 : 8,
                      ),
                      child: const _LeafHero(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: SizedBox(
                      height: bottomHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome to',
                            style: TextStyle(
                              color: _darkText,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'TeaMate',
                            style: TextStyle(
                              color: _green,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'AI-Powered insights for better yield, quality and healthier tea gardens with smart field tracking.',
                            style: TextStyle(
                              color: _mutedText,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.34,
                            ),
                          ),
                          SizedBox(height: compactHeight ? 42 : 52),
                          _WelcomeButton(
                            label: 'Login',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _WelcomeButton(
                            label: 'Create Account',
                            outlined: true,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignupScreen(),
                                ),
                              );
                            },
                          ),
                          const Spacer(),
                          Center(
                            child: Text(
                              'Copyright 2026 TeaMate. All rights reserved.',
                              style: TextStyle(
                                color: _mutedText.withValues(alpha: 0.72),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(height: compactHeight ? 12 : 18),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LeafHero extends StatelessWidget {
  const _LeafHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.asset(
        'assets/images/welcome.png',
        fit: BoxFit.contain,
        errorBuilder: (context, _, __) =>
            const Icon(Icons.eco, color: WelcomeScreen._green, size: 140),
      ),
    );
  }
}

class _WelcomeButton extends StatelessWidget {
  const _WelcomeButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: WelcomeScreen._buttonBlack,
                side: const BorderSide(
                  color: WelcomeScreen._buttonBlack,
                  width: 1.4,
                ),
                shape: shape,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(label),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: WelcomeScreen._buttonBlack,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: shape,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(label),
            ),
    );
  }
}
