import 'package:equatable/equatable.dart';
import 'user.dart';

class AuthResponse extends Equatable {
  final String authToken;
  final String refreshToken;
  final User user;
  
  /// Indicates if this is the driver's first login (status = INACTIVE).
  final bool firstTimeLogin;
  
  /// List of required actions for first-time login.
  final List<String>? requiredActions;

  const AuthResponse({
    required this.authToken,
    required this.refreshToken,
    required this.user,
    this.firstTimeLogin = false,
    this.requiredActions,
  });
  
  /// Check if user needs to complete onboarding
  bool get needsOnboarding => firstTimeLogin || user.status == 'INACTIVE';

  @override
  List<Object?> get props => [authToken, refreshToken, user, firstTimeLogin, requiredActions];
}
