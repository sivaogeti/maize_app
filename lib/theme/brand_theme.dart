// lib/theme/brand_theme.dart  (or keep next to your router)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

ThemeData buildBrandTheme() {
  const kBrand = Color(0xFF1B5E20); // deep/dark green you want
  const kBg    = Color(0xFFF4F7F2); // soft off-white background (optional)

  final scheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    brightness: Brightness.light,
  ).copyWith(
    primary: kBrand,
    onPrimary: Colors.white,
    primaryContainer: kBrand,
    onPrimaryContainer: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,

    // <- this is what fixes the header color
    appBarTheme: const AppBarTheme(
      backgroundColor: kBrand,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent, // no pastel overlay
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: kBrand,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600,
      ),
    ),

    // prevent pastel tint on cards/sheets if you use them
    cardTheme: const CardThemeData(surfaceTintColor: Colors.transparent),
    bottomSheetTheme:
    const BottomSheetThemeData(surfaceTintColor: Colors.transparent),
    dialogTheme: const DialogThemeData(surfaceTintColor: Colors.transparent),
  );
}
