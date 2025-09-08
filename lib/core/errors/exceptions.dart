class ServerException implements Exception {
  final String message;
  final int statusCode;

  ServerException({this.message = 'Lỗi máy chủ', this.statusCode = 500});

  @override
  String toString() => message;
}

class CacheException implements Exception {
  final String message;

  CacheException({this.message = 'Lỗi dữ liệu cục bộ'});

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;

  NetworkException({this.message = 'Lỗi kết nối mạng'});

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException({this.message = 'Không có quyền truy cập'});

  @override
  String toString() => message;
}
