import 'package:equatable/equatable.dart';
import 'user.dart';

class AuthResponse extends Equatable {
  final String authToken;
  final String refreshToken;
  final User user;

  const AuthResponse({
    required this.authToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      authToken: json['authToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      user: User.fromJson(json['user'] ?? {}),
    );
  }

  @override
  List<Object?> get props => [authToken, refreshToken, user];
}
