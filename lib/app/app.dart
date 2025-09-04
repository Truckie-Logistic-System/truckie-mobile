import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../presentation/theme/app_theme.dart';
import 'app_router.dart';

class TruckieApp extends StatelessWidget {
  const TruckieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Truckie Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'), // Vietnamese
      ],
      locale: const Locale('vi', 'VN'),
      initialRoute: '/login',
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
