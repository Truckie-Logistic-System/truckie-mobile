class ApiResponse<T> {
  final bool success;
  final String message;
  final int statusCode;
  final T? data;

  ApiResponse({
    required this.success,
    required this.message,
    required this.statusCode,
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      statusCode: json['statusCode'] ?? 0,
      data: json['data'] != null ? fromJsonT(json['data']) : null,
    );
  }
}
