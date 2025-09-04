import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo service locator
  await setupServiceLocator();

  runApp(const TruckieApp());
}
