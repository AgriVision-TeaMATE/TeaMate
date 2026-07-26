import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../services/auth_service.dart';
import 'factory_main_screen.dart';
import 'login_screen.dart';
import 'shell/main_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.role = UserRole.estateManager});

  final String role;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = await AuthService().register(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: widget.role,
      );

      if (!mounted) return;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created! Welcome, ${user.fullName}!'),
            backgroundColor: const Color(0xFF335C47),
            behavior: SnackBarBehavior.floating,
          ),
        );
        final home = user.role == UserRole.factoryManager
            ? const FactoryMainScreen()
            : const MainScreen();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => home),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    const borderColor = Color(0xFFE3E8E5);
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF9AA6A0),
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFFBFCFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF8FA99B), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE27D7D)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE27D7D), width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 780;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, compact ? 18 : 28, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE7ECE9)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F0EB),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1_rounded,
                                size: 17,
                                color: Color(0xFF335C47),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'TeaMate',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                color: Color(0xFF183126),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 28 : 40),
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.1,
                          color: Color(0xFF18212B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Join the AI agricultural yield optimization platform today.',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.55,
                          color: Color(0xFF7A8794),
                        ),
                      ),
                      SizedBox(height: compact ? 28 : 36),
                      const Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF425466),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1B2430),
                        ),
                        decoration: _fieldDecoration(
                          hintText: 'John Doe',
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            color: Color(0xFF8FA99B),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Enter full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF425466),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1B2430),
                        ),
                        decoration: _fieldDecoration(
                          hintText: 'manager@teamate.ai',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: Color(0xFF8FA99B),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Enter email address';
                          }
                          if (!val.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF425466),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1B2430),
                        ),
                        decoration: _fieldDecoration(
                          hintText: 'At least 6 characters',
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xFF8FA99B),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF9AA6A0),
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Enter password';
                          }
                          if (val.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Confirm Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF425466),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1B2430),
                        ),
                        decoration: _fieldDecoration(
                          hintText: 'Repeat your password',
                          prefixIcon: const Icon(
                            Icons.lock_reset_rounded,
                            color: Color(0xFF8FA99B),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF9AA6A0),
                            ),
                            onPressed: () {
                              setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              );
                            },
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Confirm your password';
                          }
                          if (val != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: compact ? 24 : 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF335C47),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : const Text(
                                  'Sign Up & Get Started',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: compact ? 22 : 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account?',
                            style: TextStyle(
                              color: Color(0xFF7A8794),
                              fontSize: 15,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      LoginScreen(expectedRole: widget.role),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF335C47),
                            ),
                            child: const Text(
                              'Log In',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
