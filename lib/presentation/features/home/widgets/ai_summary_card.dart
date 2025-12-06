import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_extensions.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị tóm tắt AI cho tài xế
class AiSummaryCard extends StatelessWidget {
  final String? summary;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  const AiSummaryCard({
    super.key,
    this.summary,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (summary == null && !isLoading && error == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.purple.shade50,
              Colors.blue.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.purple,
                      size: 20.r,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Tóm tắt AI',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const Spacer(),
                  if (error != null && onRetry != null)
                    IconButton(
                      onPressed: onRetry,
                      icon: Icon(
                        Icons.refresh,
                        color: Colors.purple.shade600,
                        size: 20.r,
                      ),
                      tooltip: 'Thử lại',
                    ),
                ],
              ),
              SizedBox(height: 12.h),
              if (isLoading)
                _buildLoadingState()
              else if (error != null)
                _buildErrorState()
              else
                _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Row(
      children: [
        Text(
          'Đang phân tích',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(width: 4.w),
        // Animated loading dots
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAnimatedDot(0),
            SizedBox(width: 2.w),
            _buildAnimatedDot(1),
            SizedBox(width: 2.w),
            _buildAnimatedDot(2),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedDot(int index) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -8 * value * (index == 0 ? 1 : index == 1 ? 0.5 : 0.3)),
          child: Opacity(
            opacity: 0.3 + (0.7 * value),
            child: Container(
              width: 4.r,
              height: 4.r,
              decoration: BoxDecoration(
                color: Colors.purple.shade400,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade600,
            size: 20.r,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Không thể tải tóm tắt AI. ${error ?? ''}',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.red.shade700,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Thử lại',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return _buildFormattedText(summary ?? 'Đang phân tích dữ liệu...');
  }

  /// Parse markdown bold (**text**) và hiển thị
  Widget _buildFormattedText(String text) {
    final List<InlineSpan> spans = [];
    final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in boldPattern.allMatches(text)) {
      // Text trước bold
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            height: 1.5,
          ),
        ));
      }
      // Bold text
      spans.add(TextSpan(
        text: match.group(1),
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.purple.shade700,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ));
      lastEnd = match.end;
    }

    // Text còn lại
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
