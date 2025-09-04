import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure({required this.message});

  @override
  List<Object> get props => [message];
}

// Lỗi mạng
class NetworkFailure extends Failure {
  const NetworkFailure({String message = 'Lỗi kết nối mạng'})
    : super(message: message);
}

// Lỗi máy chủ
class ServerFailure extends Failure {
  const ServerFailure({String message = 'Lỗi máy chủ'})
    : super(message: message);
}

// Lỗi xác thực
class AuthFailure extends Failure {
  const AuthFailure({String message = 'Lỗi xác thực'})
    : super(message: message);
}

// Lỗi cache
class CacheFailure extends Failure {
  const CacheFailure({String message = 'Lỗi dữ liệu cục bộ'})
    : super(message: message);
}

// Lỗi vị trí
class LocationFailure extends Failure {
  const LocationFailure({String message = 'Không thể lấy vị trí'})
    : super(message: message);
}
