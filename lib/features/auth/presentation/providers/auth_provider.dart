import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';

// Provider del repositorio
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

// Estado de autenticación
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);

    Future.microtask(_checkAuthStatus);

    return const AuthState();
  }

  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.getCurrentUser();

    result.fold(
      (failure) => state = state.copyWith(isLoading: false),
      (user) => state = state.copyWith(isLoading: false, user: user),
    );
  }

  Future<void> login(String email, String password) async {
    state = const AuthState(isLoading: true);

    final result = await _repository.login(email, password);

    result.fold(
      (failure) {
        state = AuthState(isLoading: false, error: failure.message);
      },
      (user) {
        state = AuthState(isLoading: false, user: user);
      },
    );
  }

  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.register(email, password, displayName);

    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (user) => state = state.copyWith(isLoading: false, user: user),
    );
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    final result = await _repository.logout();

    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (_) => state = const AuthState(),
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
