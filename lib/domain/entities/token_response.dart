import 'package:equatable/equatable.dart';

class TokenResponse extends Equatable {
  final String accessToken;
  final String refreshToken;

  const TokenResponse({required this.accessToken, required this.refreshToken});

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken];
}
