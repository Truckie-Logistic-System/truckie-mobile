import '../entities/issue.dart';

/// Repository interface for Issue operations
abstract class IssueRepository {
  /// Create a new issue
  Future<Issue> createIssue({
    required String description,
    required String issueTypeId,
    String? vehicleAssignmentId,
    double? locationLatitude,
    double? locationLongitude,
  });

  /// Get issue by ID
  Future<Issue> getIssueById(String id);

  /// Get all issue types
  Future<List<IssueType>> getAllIssueTypes();

  /// Report seal removal issue (Driver)
  Future<Issue> reportSealIssue({
    required String vehicleAssignmentId,
    required String issueTypeId,
    required String sealId,
    required String description,
    required String sealRemovalImage,
    double? locationLatitude,
    double? locationLongitude,
  });

  /// Confirm new seal attachment (Driver)
  Future<Issue> confirmNewSeal({
    required String issueId,
    required String newSealAttachedImage,
  });

  /// Get IN_USE seal for vehicle assignment (seal currently attached to container)
  Future<dynamic> getInUseSeal(String vehicleAssignmentId);

  /// Get active issue types only
  Future<List<IssueType>> getActiveIssueTypes();

  /// Get pending seal replacement issues for vehicle assignment
  /// Returns issues with status IN_PROGRESS and has newSeal assigned
  Future<List<Issue>> getPendingSealReplacements(String vehicleAssignmentId);

  /// Confirm seal replacement (alias for confirmNewSeal)
  Future<Issue> confirmSealReplacement({
    required String issueId,
    required String newSealAttachedImage,
  }) => confirmNewSeal(
        issueId: issueId,
        newSealAttachedImage: newSealAttachedImage,
      );

  /// Report damaged goods issue (Driver)
  Future<Issue> reportDamageIssue({
    required String vehicleAssignmentId,
    required String issueTypeId,
    required String orderDetailId,
    required String description,
    required List<String> damageImagePaths,
    double? locationLatitude,
    double? locationLongitude,
  });

  /// Report traffic penalty violation issue (Driver)
  Future<void> reportPenaltyIssue({
    required String vehicleAssignmentId,
    required String issueTypeId,
    required String violationType,
    required String violationImagePath,
    double? locationLatitude,
    double? locationLongitude,
  });

  /// Get predefined traffic violation reasons for penalty reporting
  Future<List<String>> getTrafficViolationReasons();

  // ===== ORDER_REJECTION flow methods =====

  /// Report order rejection by recipient (Driver)
  /// Driver selects packages to return, server auto-fills issue type and description
  Future<Issue> reportOrderRejection({
    required String vehicleAssignmentId,
    required List<String> orderDetailIds,
    double? locationLatitude,
    double? locationLongitude,
  });

  /// Get ORDER_REJECTION issue detail
  Future<dynamic> getOrderRejectionDetail(String issueId);

  /// Confirm return delivery at pickup location (Driver)
  Future<Issue> confirmReturnDelivery({
    required String issueId,
    required List<dynamic> returnDeliveryImages,
  });

  // ===== REROUTE flow methods =====
  
  /// Report reroute issue when driver encounters problem on journey segment (Driver)
  Future<Issue> reportRerouteIssue({
    required String vehicleAssignmentId,
    required String issueTypeId,
    required String affectedSegmentId,
    required String description,
    double? locationLatitude,
    double? locationLongitude,
    List<dynamic>? images, // Optional images for reroute
  });
}
