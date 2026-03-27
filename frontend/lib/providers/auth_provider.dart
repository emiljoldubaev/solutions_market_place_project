import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  Map<String, dynamic>? _user;
  String? _token;
  bool _isLoading = false;
  bool _isInitialized = false;

  Map<String, dynamic>? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    loadUserFromStorage();
  }

  Future<void> loadUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    
    if (_token != null) {
      try {
        _user = await _authService.getMe(_token!);
      } catch (e) {
        // Token invalid or expired
        _token = null;
        await prefs.remove('auth_token');
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _authService.login(email, password);
      _token = data['access_token'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      
      _user = await _authService.getMe(_token!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String fullName, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.register(fullName, email, password);
      await login(email, password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }
}
