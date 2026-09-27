import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const brand = Color(0xFFF08E19);      // possibleOrange 500
  static const brandPressed = Color(0xFFE57F14); // 600
  static const brandSoft = Color(0xFFFFF0E6);  // 50
  static const ink = Color(0xFF212121);        // header / dark chrome
  // Neutrals
  static const bg = Color(0xFFF6F6F7);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E4E7);
  static const textPrimary = Color(0xFF18181B);
  static const textSecondary = Color(0xFF6B6B73);
  // Semantic (never reuse brand orange for a status except "Nueva")
  static const created = Color(0xFF16A34A);   // asignada OK
  static const verified = Color(0xFF2563EB);  // verificada
  static const conflict = Color(0xFFDC2626);  // conflicto
  static const pending = Color(0xFFD97706);   // en cola / sin conexión
  static const reassigned = Color(0xFF7C3AED); // reasignada (violeta)
  static const reassignedSoft = Color(0xFFF5F3FF); // reasignada tinte suave
  static const warning = Color(0xFFD97706);   // advertencia (ámbar)
  static const warningSoft = Color(0xFFFFFBEB); // advertencia tinte suave
  static const tagNew = brand;                // etiqueta nueva sin asignar
}

class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

class AppSize {
  static const touch = 56.0;
  static const primaryButton = 64.0;
}

class AppMotion {
  static const fast = Duration(milliseconds: 120);  // press feedback
  static const base = Duration(milliseconds: 180);  // state swaps
  static const slow = Duration(milliseconds: 240);  // sheets
  static const easeOut = Cubic(0.23, 1, 0.32, 1);   // strong ease-out (Emil)
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);
}

class AppTypography {
  static const display = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
    color: AppColors.textPrimary,
  );

  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppColors.textSecondary,
  );

  static const epc = TextStyle(
    fontFamily: 'monospace',
    fontSize: 17,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );

  static const tabularNumbers = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    primary: AppColors.brand,
  ).copyWith(
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.conflict,
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: colorScheme,
    appBarTheme: const AppBarTheme(
      toolbarHeight: 64,
      backgroundColor: AppColors.ink,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleSpacing: AppSpace.lg,
      iconTheme: IconThemeData(color: Colors.white, size: 24),
      actionsIconTheme: IconThemeData(color: Colors.white, size: 24),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.brand, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.conflict, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.conflict, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      floatingLabelStyle: const TextStyle(color: AppColors.brand),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSize.primaryButton),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSize.primaryButton),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSize.touch),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
  );
}
