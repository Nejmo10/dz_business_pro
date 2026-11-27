import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// DzBusiness Pro original visual identity.
class C {
  static const bg = Color(0xFFF5F7FC);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF3867F4);
  static const secondary = Color(0xFF7357E8);
  static const accent = Color(0xFF16B8A6);
  static const success = Color(0xFF16A879);
  static const warning = Color(0xFFF2A93B);
  static const danger = Color(0xFFEF5261);
  static const textPrimary = Color(0xFF192338);
  static const textSecondary = Color(0xFF7B879C);
  static const border = Color(0xFFE8EDF5);
  static const sidebar = Color(0xFF101A33);
  static const sidebarHover = Color(0xFF1A2749);
  static const gradientPrimary = LinearGradient(
    colors: [Color(0xFF3867F4), Color(0xFF7357E8)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientSuccess = LinearGradient(
    colors: [Color(0xFF16A879), Color(0xFF16B8A6)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientDanger = LinearGradient(
    colors: [Color(0xFFEF5261), Color(0xFFF2A93B)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

const _latin = 'Inter';
const _arabic = 'Cairo';

ThemeData buildTheme(String locale) {
  final arabic = locale == 'ar';
  final font = arabic ? _arabic : _latin;
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: font,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.primary,
      primary: C.primary,
      secondary: C.secondary,
      surface: C.surface,
      error: C.danger,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: C.bg,
    textTheme: _textTheme(font),
    cardTheme: CardThemeData(
      color: C.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: C.border),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      hintStyle: const TextStyle(color: C.textSecondary, fontSize: 13.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: C.primary, width: 1.6),
      ),
      floatingLabelStyle: const TextStyle(color: C.primary, fontSize: 12.5),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titleTextStyle: TextStyle(
          fontFamily: font, fontSize: 17, fontWeight: FontWeight.w700, color: C.textPrimary),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: C.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: C.textPrimary, borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      waitDuration: const Duration(milliseconds: 500),
    ),
    dividerTheme: const DividerThemeData(color: C.border, thickness: 1),
    splashColor: C.primary.withValues(alpha: 0.06),
    highlightColor: C.primary.withValues(alpha: 0.04),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.textPrimary,
      contentTextStyle: TextStyle(fontFamily: font, color: Colors.white, fontSize: 13.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(surface: C.surface),
  );
}

TextTheme _textTheme(String font) => const TextTheme(
      displaySmall: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: C.textPrimary, letterSpacing: -0.5),
      headlineSmall: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: C.textPrimary, letterSpacing: -0.3),
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.textPrimary),
      titleMedium: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: C.textPrimary),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textPrimary),
      bodyLarge: TextStyle(fontSize: 15, color: C.textPrimary),
      bodyMedium: TextStyle(fontSize: 13.5, color: C.textPrimary, height: 1.45),
      bodySmall: TextStyle(fontSize: 12, color: C.textSecondary, height: 1.4),
      labelLarge: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: C.textPrimary),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: C.textSecondary),
    ).apply(fontFamily: font);

const SystemUiOverlayStyle appOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: C.bg,
);
