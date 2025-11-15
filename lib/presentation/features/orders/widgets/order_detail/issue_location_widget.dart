import 'package:flutter/material.dart';
import '../../../../../app/di/service_locator.dart';
import '../../../../../core/services/vietmap_service.dart';
import '../../../../theme/app_colors.dart';

/// Widget hiển thị vị trí sự cố với reverse geocoding
class IssueLocationWidget extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? cachedAddress; // Optional cached address

  const IssueLocationWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    this.cachedAddress,
  });

  @override
  State<IssueLocationWidget> createState() => _IssueLocationWidgetState();
}

class _IssueLocationWidgetState extends State<IssueLocationWidget> {
  String _displayText = 'Đang tải địa chỉ...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // If cached address available, use it immediately
    if (widget.cachedAddress != null && widget.cachedAddress!.isNotEmpty) {
      _displayText = widget.cachedAddress!;
      _isLoading = false;
    } else {
      _loadAddress();
    }
  }

  Future<void> _loadAddress() async {
    try {
      final vietMapService = getIt<VietMapService>();
      
      // Try to get from cache first
      String? address = vietMapService.getCachedAddress(
        widget.latitude,
        widget.longitude,
      );

      // If not in cache, fetch from API
      if (address == null) {
        address = await vietMapService.reverseGeocode(
          widget.latitude,
          widget.longitude,
        );
      }

      if (mounted) {
        setState(() {
          _displayText = address ?? 'Vị trí sự cố';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _displayText = 'Không thể tải địa chỉ';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_on,
          size: 16,
          color: AppColors.error,
        ),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            _displayText,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
