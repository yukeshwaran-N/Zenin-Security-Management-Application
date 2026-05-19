import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isInitializing = true;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get error => _error;

  final Box<UserModel> _userBox = Hive.box<UserModel>('users');

  AuthProvider() {
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    _isLoading = true;
    _isInitializing = true;
    notifyListeners();

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        if (_userBox.isNotEmpty) {
          _currentUser = _userBox.values.first;
        } else {
          _currentUser = await SupabaseService().getCurrentUser();
          if (_currentUser != null) {
            await _userBox.clear();
            await _userBox.add(_currentUser!);
          }
        }
        // Update FCM token on session init
        _updateToken();
      }
    } catch (e) {
      debugPrint('Session initialization error: $e');
    } finally {
      _isLoading = false;
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _updateToken() async {
    if (_currentUser != null) {
      final token = await NotificationService().getFCMToken();
      if (token != null) {
        await SupabaseService().updateFCMToken(_currentUser!.id, token);
      }
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await SupabaseService().signIn(email, password);

      if (user != null) {
        _currentUser = user;
        await _userBox.clear();
        await _userBox.add(user);
        
        // Update FCM token after login
        _updateToken();
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Invalid email or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on AuthException catch (e) {
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

  Future<void> updateProfile({required String name, String? phone}) async {
    if (_currentUser == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      await SupabaseService().updateUserProfile(
        userId: _currentUser!.id,
        updates: {'name': name, 'phone': phone},
      );
      
      // Refresh local user
      _currentUser = await SupabaseService().getCurrentUser();
      if (_currentUser != null) {
        await _userBox.clear();
        await _userBox.add(_currentUser!);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createSupervisor({
    required String email,
    required String password,
    required String name,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await SupabaseService().signUp(
        email: email,
        password: password,
        name: name,
        role: 'supervisor',
      );

      _isLoading = false;
      notifyListeners();
      return user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await SupabaseService().signOut();
      await _userBox.clear();
      _currentUser = null;
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
