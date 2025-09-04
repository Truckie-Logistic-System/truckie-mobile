import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/auth_repository.dart';

class LogoutUseCase {
  final AuthRepository repository;

  LogoutUseCase(this.repository);

  Future<Either<Failure, bool>> call(NoParams params) async {
    return await repository.logout();
  }
}

class NoParams {}
