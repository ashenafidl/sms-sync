import "package:flutter/material.dart";
import "package:sms_sync/theme/app_theme.dart";
import "package:sms_sync/ui/home_screen.dart";

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      darkTheme: AppTheme.dark,
      themeMode: .dark,
      home: const HomeScreen(),
    );
  }
}
