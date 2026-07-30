import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _usuario;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get usuario => _usuario;
  String? get error => _error;

  // Verificar sesión al iniciar la app
  Future<void> checkSession() async {
    final hasToken = await _authService.hasToken();
    if (hasToken) {
      _usuario = await _authService.getUsuarioGuardado();
      _isLoggedIn = true;
    }
    notifyListeners();
  }

  // Login
  Future<bool> login(String usuario, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.login(usuario, password);

    _isLoading = false;

    if (result['success']) {
      _isLoggedIn = true;
      _usuario = result['data']['usuario'];
      _error = null;
      notifyListeners();
      return true;
    } else {
      _error = result['message'];
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _authService.logout();
    _isLoggedIn = false;
    _usuario = null;
    notifyListeners();
  }
}
