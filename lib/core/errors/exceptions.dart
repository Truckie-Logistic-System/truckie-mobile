class ServerException implements Exception {
  final String message;
  final int statusCode;

  ServerException({this.message = 'Lỗi máy chủ', this.statusCode = 500});

  @override
  String toString() => 'ServerException: $message (Status: $statusCode)';
}

class CacheException implements Exception {
  final String message;

  CacheException({this.message = 'Lỗi dữ liệu cục bộ'});

  @override
  String toString() => 'CacheException: $message';
}

class NetworkException implements Exception {
  final String message;

  NetworkException({this.message = 'Lỗi kết nối mạng'});

  @override
  String toString() => 'NetworkException: $message';
}

class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException({this.message = 'Không có quyền truy cập'});

  @override
  String toString() => 'UnauthorizedException: $message';
}
