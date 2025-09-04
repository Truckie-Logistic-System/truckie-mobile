import 'package:equatable/equatable.dart';

class Role extends Equatable {
  final String id;
  final String roleName;
  final String description;
  final bool isActive;

  const Role({
    required this.id,
    required this.roleName,
    required this.description,
    required this.isActive,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] ?? '',
      roleName: json['roleName'] ?? '',
      description: json['description'] ?? '',
      isActive: json['isActive'] ?? false,
    );
  }

  @override
  List<Object?> get props => [id, roleName, description, isActive];
}
