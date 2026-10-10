import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const forest = Color(0xFF143D2B);
  static const emerald = Color(0xFF1A936F);
  static const offWhite = Color(0xFFF7F8F2);
  static const muted = Color(0xFF65746B);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: offWhite,
    colorScheme: ColorScheme.fromSeed(
      seedColor: forest,
      primary: forest,
      secondary: emerald,
      surface: offWhite,
    ),
  );
}
