import 'package:dartz/dartz.dart';
import 'dart:io';

import '../../core/errors/failures.dart';

abstract class LoadingDocumentationRepository {
  /// Submit pre-delivery documentation with packing proof images and seal image
  Future<Either<Failure, bool>> submitPreDeliveryDocumentation({
    required String vehicleAssignmentId,
    required String sealCode,
    required List<File>? packingProofImages,
    required File? sealImage,
  });
}
