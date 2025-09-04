import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String avatarUrl;
  final String role;
  final String token;

  const User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.avatarUrl = '',
    required this.role,
    required this.token,
  });

  @override
  List<Object?> get props => [
    id,
    username,
    fullName,
    email,
    phoneNumber,
    avatarUrl,
    role,
    token,
  ];
}
