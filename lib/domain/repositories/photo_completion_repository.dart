import 'dart:io';
import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';

abstract class PhotoCompletionRepository {
  Future<Either<Failure, bool>> uploadPhoto(String orderId, String photoPath);
  
  /// Upload multiple photo completion images
  Future<Either<Failure, bool>> uploadMultiplePhotoCompletion({
    required List<File> imageFiles,
    required String vehicleAssignmentId,
    String? description,
  });
}
