import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/driver.dart';

/// Repository for driver onboarding operations
abstract class DriverOnboardingRepository {
  /// Submit onboarding data with face image file (change password + upload face image + activate account)
  /// This replaces the old two-step process (uploadFaceImage + submitOnboarding)
  Future<Either<Failure, Driver>> submitOnboardingWithImage({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
    required File faceImageFile,
  });

  /// Check if current driver needs onboarding
  Future<Either<Failure, bool>> needsOnboarding();
}
