import 'package:jellyfin_dart/jellyfin_dart.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.isLoading = false,
    this.user,
    this.userId,
    this.serverUrl,
    this.error,
  });

  final AuthStatus status;
  final bool isLoading;
  final UserDto? user;
  final String? userId;
  final String? serverUrl;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    UserDto? user,
    String? userId,
    String? serverUrl,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      userId: userId ?? this.userId,
      serverUrl: serverUrl ?? this.serverUrl,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
