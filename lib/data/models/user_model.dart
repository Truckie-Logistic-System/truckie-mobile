import '../../domain/entities/user.dart';
import 'role_model.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.username,
    required super.fullName,
    required super.email,
    required super.phoneNumber,
    required super.gender,
    required super.dateOfBirth,
    required super.imageUrl,
    required super.status,
    required super.role,
    required super.authToken,
    super.refreshToken,
    super.firstTimeLogin = false,
    super.requiredActions,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Parse requiredActions from JSON
    List<String>? requiredActions;
    if (json['requiredActions'] != null) {
      requiredActions = List<String>.from(json['requiredActions']);
    }
    
    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      gender: json['gender'] ?? false,
      dateOfBirth: json['dateOfBirth'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      status: json['status'] ?? '',
      role: json['role'] != null
          ? RoleModel.fromJson(json['role'])
          : const RoleModel(id: '', roleName: '', description: '', isActive: false),
      authToken: json['authToken'] ?? '',
      refreshToken: json['refreshToken'],
      firstTimeLogin: json['firstTimeLogin'] ?? false,
      requiredActions: requiredActions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'gender': gender,
      'dateOfBirth': dateOfBirth,
      'imageUrl': imageUrl,
      'status': status,
      'role': (role as RoleModel).toJson(),
      'authToken': authToken,
      'refreshToken': refreshToken,
      'firstTimeLogin': firstTimeLogin,
      'requiredActions': requiredActions,
    };
  }

  User toEntity() => this;
}
