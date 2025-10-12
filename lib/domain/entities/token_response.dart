import 'package:equatable/equatable.dart';

class TokenResponse extends Equatable {
  final String accessToken;

  const TokenResponse({required this.accessToken});

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(accessToken: json['accessToken'] ?? '');
  }

  @override
  List<Object?> get props => [accessToken];
}
