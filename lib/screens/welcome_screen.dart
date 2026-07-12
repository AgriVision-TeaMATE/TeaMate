import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF9F9FC),
      body: SafeArea(child: _WelcomeLayout()),
    );
  }
}

class _WelcomeLayout extends StatelessWidget {
  const _WelcomeLayout();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final landscape = width > height;
        final compact = height < 780;

        if (landscape) {
          return _LandscapeLayout(compact: compact);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned.fill(bottom: 72, child: _HeroSection()),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 0,
                      child: _ActionCard(compact: compact),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '© 2024 TeaNexus Systems • Tech for Terroir',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF707A6F),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Expanded(flex: 6, child: _HeroSection()),
          const SizedBox(width: 18),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionCard(compact: compact),
                const SizedBox(height: 18),
                const Text(
                  '© 2024 TeaNexus Systems • Tech for Terroir',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF707A6F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/tea_welcome_card.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.1),
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/images/tea_background.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.1),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFF9F9FC).withValues(alpha: 0.82),
                  const Color(0xFFF9F9FC).withValues(alpha: 0.18),
                  Colors.transparent,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.17, 0.34, 1.0],
              ),
            ),
          ),
          const Positioned(left: 20, top: 18, child: _BrandPill()),
          Positioned(
            right: 18,
            top: 98,
            child: Icon(
              Icons.scatter_plot_outlined,
              size: 20,
              color: const Color(0xFF7A8174).withValues(alpha: 0.45),
            ),
          ),
          const Positioned(left: 26, right: 24, top: 168, child: _HeroCopy()),
        ],
      ),
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: ClipOval(
              child: Image.asset(
                'assets/images/teamate_logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) => Container(
                  color: const Color(0xFF005F26),
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'TeaMate',
            style: TextStyle(
              fontSize: 24,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: Color(0xFF00481D),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.9,
              color: Color(0xFF1A1C1E),
            ),
            children: [
              TextSpan(text: 'Smarter Tea Production\n'),
              TextSpan(
                text: 'Starts Here',
                style: TextStyle(color: Color(0xFF00692C)),
              ),
            ],
          ),
        ),
        SizedBox(height: 18),
        Text(
          'Optimize yield, detect diseases early,\nand grade tea quality with AI-powered\ninsights.',
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFBFC9BD).withValues(alpha: 0.30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PrimaryAction(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: const Color(0xFFBFC9BD).withValues(alpha: 0.30),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 1,
                  color: const Color(0xFFBFC9BD).withValues(alpha: 0.30),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SecondaryAction(
            compact: compact,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SignupScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00481D),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              Icon(Icons.login_rounded, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Login',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({required this.compact, required this.onPressed});

  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFDADEDB).withValues(alpha: 0.50),
          foregroundColor: const Color(0xFF5C645F),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide(
            color: const Color(0xFFBFC9BD).withValues(alpha: 0.20),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              Icon(
                Icons.person_add_alt_1_rounded,
                size: compact ? 18 : 19,
                color: const Color(0xFF5C645F),
              ),
              const SizedBox(width: 8),
              const Text(
                'Register Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5C645F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
