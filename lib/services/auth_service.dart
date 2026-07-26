import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/network_config.dart';

class AuthUser {
  final String id;
  final String email;
  final String fullName;
  final String role;

  AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'TeaMate User',
      role: json['role']?.toString() ?? 'estate_manager',
    );
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static String get baseUrl => NetworkConfig.authBaseUrl();

  String? _token;
  AuthUser? _currentUser;

  String? get token => _token;
  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _token != null && _currentUser != null;

  Map<String, String> get _authHeaders {
    final token = _token;
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<AuthUser?> register({
    required String fullName,
    required String email,
    required String password,
    String role = 'estate_manager',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'full_name': fullName,
              'email': email,
              'password': password,
              'role': role,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        _currentUser = AuthUser.fromJson(data['user']);
        return _currentUser;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Registration failed.');
      }
    } catch (e) {
      debugPrint('AuthService register error: $e');
      rethrow;
    }
  }

  Future<AuthUser?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        _currentUser = AuthUser.fromJson(data['user']);
        return _currentUser;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
          error['detail'] ?? 'Login failed. Check your credentials.',
        );
      }
    } catch (e) {
      debugPrint('AuthService login error: $e');
      rethrow;
    }
  }

  Future<bool> forgotPassword(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return true;

      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Could not send reset code.');
    } catch (e) {
      debugPrint('AuthService forgotPassword error: $e');
      rethrow;
    }
  }

  Future<bool> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/verify-reset-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return true;

      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Invalid verification code.');
    } catch (e) {
      debugPrint('AuthService verifyResetOtp error: $e');
      rethrow;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'otp': otp,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return true;

      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Could not reset password.');
    } catch (e) {
      debugPrint('AuthService resetPassword error: $e');
      rethrow;
    }
  }

  Future<AuthUser?> fetchProfile() async {
    final token = _token;
    if (token == null || token.isEmpty) return _currentUser;

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/me'), headers: _authHeaders)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        _currentUser = AuthUser.fromJson(jsonDecode(response.body));
        return _currentUser;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        logout();
      }

      return _currentUser;
    } catch (e) {
      debugPrint('AuthService fetchProfile error: $e');
      return _currentUser;
    }
  }

  void logout() {
    _token = null;
    _currentUser = null;
  }
}
