import 'dart:io';
import 'package:dartz/dartz.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/photo_completion_repository.dart';
import '../datasources/photo_completion_data_source.dart';

class PhotoCompletionRepositoryImpl implements PhotoCompletionRepository {
  final PhotoCompletionDataSource dataSource;

  PhotoCompletionRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, bool>> uploadPhoto(String orderId, String photoPath) async {
    // This method is deprecated - use uploadPhotoCompletion from datasource directly
    // For now, return a simple implementation
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> uploadMultiplePhotoCompletion({
    required List<File> imageFiles,
    required String vehicleAssignmentId,
    String? description,
  }) async {
    return dataSource.uploadMultiplePhotoCompletion(
      imageFiles: imageFiles,
      vehicleAssignmentId: vehicleAssignmentId,
      description: description,
    );
  }
}
