import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/auth_repository.dart';

class ChangePasswordParams {
  final String username;
  final String oldPassword;
  final String newPassword;
  final String confirmNewPassword;

  ChangePasswordParams({
    required this.username,
    required this.oldPassword,
    required this.newPassword,
    required this.confirmNewPassword,
  });
}

class ChangePasswordUseCase {
  final AuthRepository repository;

  ChangePasswordUseCase(this.repository);

  Future<Either<Failure, bool>> call(ChangePasswordParams params) {
    return repository.changePassword(
      params.username,
      params.oldPassword,
      params.newPassword,
      params.confirmNewPassword,
    );
  }
}
