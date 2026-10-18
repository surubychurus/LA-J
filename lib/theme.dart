import 'package:flutter/material.dart';

class AppColors {
  static const base = Color(0xFFF2F6FF);
  static const normal = Color(0xFF195EFC);
  static const accent = Color(0xFF00093B);
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final bg = dark ? const Color(0xFF00041F) : AppColors.base;
  final surface = dark ? AppColors.accent : Colors.white;
  final onSurface = dark ? AppColors.base : AppColors.accent;
  final scheme = ColorScheme(
    brightness: b,
    primary: dark ? const Color(0xFF5B8DFF) : AppColors.normal,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    error: const Color(0xFFD32F2F),
    onError: Colors.white,
    surface: surface,
    onSurface: onSurface,
  );
  // Museo 700 (tipografía principal de Jazit) solo existe en peso 700:
  // se usa en títulos y etiquetas; el cuerpo va en Poppins (incluida en la app, funciona sin conexión).
  final body = ThemeData(brightness: b)
      .textTheme
      .apply(fontFamily: 'Poppins', bodyColor: onSurface, displayColor: onSurface);
  TextStyle? museo(TextStyle? s) =>
      s?.copyWith(fontFamily: 'Museo', fontWeight: FontWeight.w700);
  final text = body.copyWith(
    displayLarge: museo(body.displayLarge),
    displayMedium: museo(body.displayMedium),
    displaySmall: museo(body.displaySmall),
    headlineLarge: museo(body.headlineLarge),
    headlineMedium: museo(body.headlineMedium),
    headlineSmall: museo(body.headlineSmall),
    titleLarge: museo(body.titleLarge),
    titleMedium: museo(body.titleMedium),
    labelLarge: museo(body.labelLarge),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardTheme(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: onSurface.withValues(alpha: 0.08)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface.withValues(alpha: 0.92),
      elevation: 0,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
    ),
    // Estilo shadcn/ui: bordes de 1px, radio grande (preset Maia), anillo de foco en el color primario.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: onSurface.withValues(alpha: 0.04),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: onSurface.withValues(alpha: 0.16)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: onSurface.withValues(alpha: 0.16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: onSurface,
        side: BorderSide(color: onSurface.withValues(alpha: 0.16)),
        shape: const StadiumBorder(),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
      ),
    ),
    dividerTheme: DividerThemeData(color: onSurface.withValues(alpha: 0.08), space: 1),
  );
}
