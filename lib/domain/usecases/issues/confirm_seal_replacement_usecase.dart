import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/issue.dart';
import '../../repositories/issue_repository.dart';

/// UseCase để driver xác nhận đã gắn seal mới
class ConfirmSealReplacementUseCase {
  final IssueRepository repository;

  ConfirmSealReplacementUseCase(this.repository);

  Future<Either<Failure, Issue>> call(ConfirmSealReplacementParams params) async {
    return await repository.confirmSealReplacement(
      issueId: params.issueId,
      newSealAttachedImage: params.newSealAttachedImage,
    );
  }
}

class ConfirmSealReplacementParams {
  final String issueId;
  final String newSealAttachedImage;

  const ConfirmSealReplacementParams({
    required this.issueId,
    required this.newSealAttachedImage,
  });
}
