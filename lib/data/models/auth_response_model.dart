import '../../domain/entities/auth_response.dart';
import 'user_model.dart';

class AuthResponseModel extends AuthResponse {
  const AuthResponseModel({
    required super.authToken,
    required super.refreshToken,
    required super.user,
    super.firstTimeLogin = false,
    super.requiredActions,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    // Parse requiredActions from JSON
    List<String>? requiredActions;
    if (json['requiredActions'] != null) {
      requiredActions = List<String>.from(json['requiredActions']);
    }
    
    return AuthResponseModel(
      authToken: json['authToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      user: UserModel.fromJson(json['user'] ?? {}),
      firstTimeLogin: json['firstTimeLogin'] ?? false,
      requiredActions: requiredActions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'authToken': authToken,
      'refreshToken': refreshToken,
      'user': (user as UserModel).toJson(),
      'firstTimeLogin': firstTimeLogin,
      'requiredActions': requiredActions,
    };
  }

  AuthResponse toEntity() => this;
}
