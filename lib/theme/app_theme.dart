import "package:flutter/material.dart";

class AppTheme {
  static ThemeData get dark {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff284258),
      brightness: .dark,
    );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: .dark,

      textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 12)),

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 48)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}
