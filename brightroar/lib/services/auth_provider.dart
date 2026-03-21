import 'package:flutter/material.dart';
import 'api_client.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _user;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get user => _user;

  Future<void> checkAuth() async {
    _isLoggedIn = await ApiClient.isLoggedIn();
    if (_isLoggedIn) {
      try {
        _user = await ApiClient.getMe();
      } catch (e) {
        _isLoggedIn = false;
        await ApiClient.clearTokens();
      }
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.login(email: email, password: password);
      _user = await ApiClient.getMe();
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({required String companyName, required String email, required String contactPerson, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiClient.register(companyName: companyName, email: email, contactPerson: contactPerson, password: password);
      return await login(email, password);
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await ApiClient.logout();
    _isLoggedIn = false;
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
