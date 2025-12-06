import 'package:flutter/material.dart';
import '../../../app/di/service_locator.dart';
import '../../../domain/repositories/issue_repository.dart';
import '../../features/delivery/widgets/confirm_seal_replacement_sheet.dart';
import '../../../domain/entities/issue.dart';
import '../../../core/services/notification_service.dart';
import '../../../app/app_routes.dart';

/// Dialog hiển thị thông báo gán seal mới từ staff
/// Hiển thị khi driver nhận được notification realtime
class SealAssignmentNotificationDialog extends StatefulWidget {
  final String title;
  final String message;
  final String issueId;
  final String newSealCode;
  final String oldSealCode;
  final String staffName;
  final String? vehicleAssignmentId;

  const SealAssignmentNotificationDialog({
    Key? key,
    required this.title,
    required this.message,
    required this.issueId,
    required this.newSealCode,
    required this.oldSealCode,
    required this.staffName,
    this.vehicleAssignmentId,
  }) : super(key: key);

  @override
  State<SealAssignmentNotificationDialog> createState() =>
      _SealAssignmentNotificationDialogState();
}

class _SealAssignmentNotificationDialogState
    extends State<SealAssignmentNotificationDialog> {
  @override
  void initState() {
    super.initState();

    // 🆕 Fetch pending seals ngay khi show dialog
    if (widget.vehicleAssignmentId != null) {
      _fetchPendingSeals();
    }
  }

  Future<void> _fetchPendingSeals() async {
    try {
      final issueRepository = getIt<IssueRepository>();
      final pendingIssues = await issueRepository.getPendingSealReplacements(
        widget.vehicleAssignmentId!,
      );

      // 🆕 Trigger navigation screen refresh to show banner
      if (pendingIssues.isNotEmpty) {
        getIt<NotificationService>().triggerNavigationScreenRefresh();
      }
    } catch (e) { // Ignore: Error handling not implemented
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient (compact, full width)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    // Icon shield compact
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.security,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Title
                    const Text(
                      'Seal Mới Đã Được Gán',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Yêu cầu thay seal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Content (compact padding)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Staff info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.shade100,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nhân viên',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Staff ${widget.staffName}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Instruction text (compact)
                    Center(
                      child: Text(
                        'Vui lòng xác nhận gắn seal mới lên kiện hàng',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Seal comparison với arrow (compact)
                    Row(
                      children: [
                        Expanded(
                          child: _buildSealCard(
                            label: 'Seal cũ',
                            code: widget.oldSealCode,
                            icon: Icons.lock_open_rounded,
                            color: Colors.red.shade600,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.grey.shade400,
                                size: 24,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Thay',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _buildSealCard(
                            label: 'Seal mới',
                            code: widget.newSealCode,
                            icon: Icons.lock_rounded,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions (compact)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    // Primary button với gradient
                    Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade600, Colors.blue.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade300.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();

                          // 🆕 Open ConfirmSealReplacementSheet directly

                          // Create Issue object from the data
                          final issue = Issue(
                            id: widget.issueId,
                            description: widget.message,
                            locationLatitude: 0.0, // Will be filled by backend
                            locationLongitude: 0.0, // Will be filled by backend
                            status: IssueStatus.inProgress,
                            issueCategory: IssueCategory.sealReplacement,
                            reportedAt: DateTime.now(),
                            resolvedAt: null,
                            // 🆕 Create Seal objects with seal codes from notification
                            oldSeal: Seal(
                              id: '', // Not needed for display
                              sealCode: widget.oldSealCode,
                              status: SealStatus.removed,
                            ),
                            newSeal: Seal(
                              id: '', // Not needed for display
                              sealCode: widget.newSealCode,
                              status: SealStatus.inUse,
                            ),
                          );

                          // Show confirmation bottom sheet
                          final result = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => ConfirmSealReplacementSheet(
                              issue: issue,
                              onConfirm: (imageBase64) async {
                                try {
                                  final issueRepository =
                                      getIt<IssueRepository>();
                                  await issueRepository.confirmSealReplacement(
                                    issueId: widget.issueId,
                                    newSealAttachedImage: imageBase64,
                                  );

                                  // Return success to close bottom sheet and handle navigation outside
                                  return;
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Lỗi: $e')),
                                    );
                                  }
                                  rethrow;
                                }
                              },
                            ),
                          );

                          // After bottom sheet is closed, check result before showing success

                          if (result == true) {
                            // Wait a bit for backend to update issue status
                            await Future.delayed(
                              const Duration(milliseconds: 500),
                            );

                            // ✅ CRITICAL: Trigger navigation screen refresh for return journey
                            // Navigation screen will:
                            // 1. Refetch pending seal replacements (now empty)
                            // 2. Refetch route data (now includes return journey)
                            // 3. Auto-resume simulation for return journey
                            getIt<NotificationService>()
                                .triggerNavigationScreenRefresh();

                            // Check if currently on navigation screen
                            final currentRoute = ModalRoute.of(
                              context,
                            )?.settings.name;
                            final isOnNavigationScreen =
                                currentRoute == AppRoutes.navigation;

                            if (!isOnNavigationScreen && context.mounted) {
                              // Not on navigation screen → Pop back to show navigation screen with return journey
                              // This allows driver to see the updated route and auto-resumed simulation
                              Navigator.of(context).popUntil(
                                (route) =>
                                    route.settings.name ==
                                        AppRoutes.navigation ||
                                    route.settings.name == AppRoutes.home,
                              );
                            }

                            // Show snackbar only if context is still mounted
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '✅ Đã xác nhận gắn seal mới thành công. Bắt đầu hành trình trả hàng...',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Xác Nhận Gán Seal',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Secondary button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Để sau',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSealCard({
    required String label,
    required String code,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            code,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
