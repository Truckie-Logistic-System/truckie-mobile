import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/token_response.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource dataSource;

  AuthRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, User>> login(String username, String password) async {
    try {
      final user = await dataSource.login(username, password);
      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on UnauthorizedException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> logout() async {
    try {
      final result = await dataSource.logout();
      return Right(result);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isLoggedIn() async {
    try {
      final result = await dataSource.isLoggedIn();
      return Right(result);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      final user = await dataSource.getCurrentUser();
      return Right(user);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TokenResponse>> refreshToken() async {
    try {
      // Lấy refresh token từ local storage
      try {
        final user = await dataSource.getCurrentUser();
        final refreshToken = user.refreshToken;
        debugPrint('Got refresh token: ${refreshToken.substring(0, 10)}...');

        // Gọi API để làm mới token
        final tokenResponse = await dataSource.refreshToken(refreshToken);
        return Right(tokenResponse);
      } on CacheException {
        return Left(AuthFailure(message: 'Không tìm thấy thông tin đăng nhập'));
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on UnauthorizedException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(
        ServerFailure(message: 'Làm mới token thất bại: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> changePassword(
    String username,
    String oldPassword,
    String newPassword,
    String confirmNewPassword,
  ) async {
    try {
      final result = await dataSource.changePassword(
        username,
        oldPassword,
        newPassword,
        confirmNewPassword,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on UnauthorizedException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(
        ServerFailure(message: 'Đổi mật khẩu thất bại: ${e.toString()}'),
      );
    }
  }
}
