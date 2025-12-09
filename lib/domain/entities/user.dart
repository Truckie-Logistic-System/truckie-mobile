import 'package:equatable/equatable.dart';
import 'role.dart';

class User extends Equatable {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String phoneNumber;
  final bool gender;
  final String dateOfBirth;
  final String imageUrl;
  final String status;
  final Role role;
  final String authToken;
  final String? refreshToken;
  
  /// Indicates if this is the driver's first login (status = INACTIVE).
  /// If true, driver must complete onboarding before accessing the app.
  final bool firstTimeLogin;
  
  /// List of required actions for first-time login.
  /// e.g., ["CHANGE_PASSWORD", "UPLOAD_FACE"]
  final List<String>? requiredActions;

  const User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.gender,
    required this.dateOfBirth,
    required this.imageUrl,
    required this.status,
    required this.role,
    required this.authToken,
    this.refreshToken,
    this.firstTimeLogin = false,
    this.requiredActions,
  });
  
  /// Check if user needs to complete onboarding
  bool get needsOnboarding => firstTimeLogin || status == 'INACTIVE';

  @override
  List<Object?> get props => [
    id,
    username,
    fullName,
    email,
    phoneNumber,
    gender,
    dateOfBirth,
    imageUrl,
    status,
    role,
    authToken,
    refreshToken,
    firstTimeLogin,
    requiredActions,
  ];
}
