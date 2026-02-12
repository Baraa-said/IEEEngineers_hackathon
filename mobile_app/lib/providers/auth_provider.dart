import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

/// Global API service provider.
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// Auth state
class AuthState {
  final bool isAuthenticated;
  final String? token;
  final String? userName;
  final String? userRole;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.token,
    this.userName,
    this.userRole,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? token,
    String? userName,
    String? userRole,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;

  AuthNotifier(this._api) : super(const AuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.login(email, password);
      state = AuthState(
        isAuthenticated: true,
        token: data['access_token'],
        userName: data['user']?['full_name'],
        userRole: data['user']?['role'],
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed. Please check your credentials.',
      );
    }
  }

  Future<void> register(
      String email, String password, String fullName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.register(email, password, fullName);
      state = AuthState(
        isAuthenticated: true,
        token: data['access_token'],
        userName: data['user']?['full_name'],
        userRole: data['user']?['role'],
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed.',
      );
    }
  }

  void logout() {
    _api.logout();
    state = const AuthState();
  }

  /// Skip auth for demo
  void skipAuth() {
    state = const AuthState(
      isAuthenticated: true,
      userName: 'Demo User',
      userRole: 'viewer',
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return AuthNotifier(api);
});
