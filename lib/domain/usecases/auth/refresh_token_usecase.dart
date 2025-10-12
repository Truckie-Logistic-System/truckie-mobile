import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/token_response.dart';
import '../../repositories/auth_repository.dart';
import 'logout_usecase.dart';

class RefreshTokenUseCase {
  final AuthRepository repository;

  RefreshTokenUseCase(this.repository);

  Future<Either<Failure, TokenResponse>> call(NoParams params) async {
    return await repository.refreshToken();
  }
}
