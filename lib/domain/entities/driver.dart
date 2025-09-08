import 'package:equatable/equatable.dart';
import 'user.dart';
import 'role.dart';

class Driver extends Equatable {
  final String id;
  final String identityNumber;
  final String driverLicenseNumber;
  final String cardSerialNumber;
  final String placeOfIssue;
  final DateTime dateOfIssue;
  final DateTime dateOfExpiry;
  final String licenseClass;
  final DateTime dateOfPassing;
  final String status;
  final User userResponse;

  const Driver({
    required this.id,
    required this.identityNumber,
    required this.driverLicenseNumber,
    required this.cardSerialNumber,
    required this.placeOfIssue,
    required this.dateOfIssue,
    required this.dateOfExpiry,
    required this.licenseClass,
    required this.dateOfPassing,
    required this.status,
    required this.userResponse,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] ?? '',
      identityNumber: json['identityNumber'] ?? '',
      driverLicenseNumber: json['driverLicenseNumber'] ?? '',
      cardSerialNumber: json['cardSerialNumber'] ?? '',
      placeOfIssue: json['placeOfIssue'] ?? '',
      dateOfIssue: json['dateOfIssue'] != null
          ? DateTime.parse(json['dateOfIssue'])
          : DateTime.now(),
      dateOfExpiry: json['dateOfExpiry'] != null
          ? DateTime.parse(json['dateOfExpiry'])
          : DateTime.now(),
      licenseClass: json['licenseClass'] ?? '',
      dateOfPassing: json['dateOfPassing'] != null
          ? DateTime.parse(json['dateOfPassing'])
          : DateTime.now(),
      status: json['status'] ?? '',
      userResponse: json['userResponse'] != null
          ? User.fromJson(json['userResponse'])
          : User(
              id: '',
              username: '',
              fullName: '',
              email: '',
              phoneNumber: '',
              gender: false,
              dateOfBirth: '',
              imageUrl: '',
              status: '',
              role: json['userResponse']?['role'] != null
                  ? Role.fromJson(json['userResponse']['role'])
                  : Role(
                      id: '',
                      roleName: '',
                      description: '',
                      isActive: false,
                    ),
              authToken: '',
              refreshToken: '',
            ),
    );
  }

  @override
  List<Object?> get props => [
    id,
    identityNumber,
    driverLicenseNumber,
    cardSerialNumber,
    placeOfIssue,
    dateOfIssue,
    dateOfExpiry,
    licenseClass,
    dateOfPassing,
    status,
    userResponse,
  ];
}
