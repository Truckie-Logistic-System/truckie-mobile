// Các entity cơ bản
export 'driver.dart';
export 'user.dart';
export 'role.dart';

// Các entity liên quan đến đơn hàng
export 'order.dart';
export 'order_with_details.dart';

// Ẩn Driver trong order_detail.dart để tránh xung đột
export 'order_detail.dart' hide Driver;
