import 'package:flutter/material.dart';
import '../../../app/di/service_locator.dart';
import '../../../domain/repositories/issue_repository.dart';
import '../../features/delivery/widgets/confirm_seal_replacement_sheet.dart';
import '../../../domain/entities/issue.dart';
import '../../../core/services/notification_service.dart';

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
  State<SealAssignmentNotificationDialog> createState() => _SealAssignmentNotificationDialogState();
}

class _SealAssignmentNotificationDialogState extends State<SealAssignmentNotificationDialog> {
  @override
  void initState() {
    super.initState();
    
    // 🆕 Fetch pending seals ngay khi show dialog
    if (widget.vehicleAssignmentId != null) {
      debugPrint('🔄 [SealAssignmentDialog] Fetching pending seals for VA: ${widget.vehicleAssignmentId}');
      _fetchPendingSeals();
    }
  }
  
  Future<void> _fetchPendingSeals() async {
    try {
      final issueRepository = getIt<IssueRepository>();
      final pendingIssues = await issueRepository.getPendingSealReplacements(
        widget.vehicleAssignmentId!,
      );
      
      debugPrint('🔄 [SealAssignmentDialog] Fetched ${pendingIssues.length} pending seals');
      
      // 🆕 Trigger navigation screen refresh to show banner
      if (pendingIssues.isNotEmpty) {
        debugPrint('🔄 [SealAssignmentDialog] Triggering navigation screen refresh for banner...');
        getIt<NotificationService>().triggerNavigationScreenRefresh();
      }
    } catch (e) {
      debugPrint('❌ [SealAssignmentDialog] Error fetching pending seals: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header compact
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade600, Colors.orange.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Yêu cầu thay seal',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content compact
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Message compact
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Staff ${widget.staffName} đã gán seal mới',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Seal comparison compact
                  Row(
                    children: [
                      Expanded(child: _buildSealCard(
                        label: 'Seal cũ',
                        code: widget.oldSealCode,
                        icon: Icons.lock_open,
                        color: Colors.red,
                      )),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, color: Colors.grey.shade400, size: 18),
                      ),
                      Expanded(child: _buildSealCard(
                        label: 'Seal mới',
                        code: widget.newSealCode,
                        icon: Icons.lock,
                        color: Colors.green,
                      )),
                    ],
                  ),
                ],
              ),
            ),

            // Actions compact
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  // Primary button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
            Navigator.of(context).pop();
            
            // 🆕 Open ConfirmSealReplacementSheet directly
            debugPrint('📱 [SealAssignmentDialog] Opening seal replacement confirmation sheet...');
            
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
                    final issueRepository = getIt<IssueRepository>();
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
            debugPrint('🔍 [SealAssignmentDialog] Checking result: result=$result, mounted=${context.mounted}');
            
            if (result == true) {
              debugPrint('✅ [SealAssignmentDialog] Bottom sheet returned success!');
              
              // Trigger navigation screen refresh FIRST (before checking mounted)
              // This is critical - refresh must happen even if dialog is unmounted
              debugPrint('🔄 [SealAssignmentDialog] ========================================');
              debugPrint('🔄 [SealAssignmentDialog] Triggering navigation screen refresh...');
              debugPrint('🔄 [SealAssignmentDialog] This should:');
              debugPrint('🔄 [SealAssignmentDialog]   1. Fetch pending seals (should be empty)');
              debugPrint('🔄 [SealAssignmentDialog]   2. Hide banner (if list empty)');
              debugPrint('🔄 [SealAssignmentDialog]   3. Resume simulation (if in sim mode)');
              debugPrint('🔄 [SealAssignmentDialog] ========================================');
              
              // Wait a bit for backend to update issue status
              await Future.delayed(const Duration(milliseconds: 500));
              
              getIt<NotificationService>().triggerNavigationScreenRefresh();
              
              debugPrint('✅ [SealAssignmentDialog] Refresh signal sent!');
              
              // Show snackbar only if context is still mounted
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Đã xác nhận gắn seal mới thành công'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                debugPrint('⚠️ [SealAssignmentDialog] Context unmounted, skipping snackbar');
              }
            } else {
              debugPrint('⚠️ [SealAssignmentDialog] Bottom sheet result: $result (not success)');
            }
          },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Xử lý ngay',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Secondary button
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        debugPrint('🔄 [SealAssignmentDialog] Closing dialog - pending seals already fetched');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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
    );
  }

  Widget _buildSealCard({
    required String label,
    required String code,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
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
