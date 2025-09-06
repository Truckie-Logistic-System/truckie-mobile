import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../entities/token_response.dart';
import '../../core/errors/failures.dart';

abstract class AuthRepository {
  /// Đăng nhập với tên đăng nhập và mật khẩu
  Future<Either<Failure, User>> login(String username, String password);

  /// Đăng xuất
  Future<Either<Failure, bool>> logout();

  /// Kiểm tra trạng thái đăng nhập
  Future<Either<Failure, bool>> isLoggedIn();

  /// Lấy thông tin người dùng hiện tại
  Future<Either<Failure, User>> getCurrentUser();

  /// Làm mới token
  Future<Either<Failure, TokenResponse>> refreshToken();
}
