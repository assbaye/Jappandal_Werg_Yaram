import 'package:flutter/material.dart';

/// Charte JWY : blanc, un seul bleu, gris neutres. Cartes plates à bordure fine.
class AppTheme {
  // ── Couleurs ──────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1565C0);
  /// Fond bleu très pâle : pastilles d'icônes, éléments sélectionnés
  static const Color primarySoft = Color(0xFFEAF2FC);
  /// Bleu secondaire pour les états (« confirmé », informations)
  static const Color secondary = Color(0xFF2F7BE0);

  static const Color background = Color(0xFFF6F8FB);
  static const Color cardColor = Colors.white;
  static const Color border = Color(0xFFE3E8EF);

  /// Texte principal, secondaire et discret
  static const Color ink = Color(0xFF0F1B2D);
  static const Color inkSoft = Color(0xFF4B5869);
  static const Color inkMuted = Color(0xFF8A96A6);

  static const Color errorColor = Color(0xFFD03A2F);
  static const Color successColor = Color(0xFF1E8E4F);
  static const Color warningColor = Color(0xFFD7820B);
  static const Color warningSoft = Color(0xFFFDF3E3);

  static const String police = 'PlusJakartaSans';

  static final BorderRadius rayon = BorderRadius.circular(14);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: cardColor,
      error: errorColor,
      brightness: Brightness.light,
    ).copyWith(
      onSurface: ink,
      onSurfaceVariant: inkSoft,
      outline: border,
      outlineVariant: border,
      surfaceContainerHighest: background,
      surfaceTint: Colors.transparent,
    );

    final texte = ThemeData.light().textTheme.apply(
          fontFamily: police,
          bodyColor: ink,
          displayColor: ink,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: police,
      textTheme: texte.copyWith(
        titleLarge: texte.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleMedium: texte.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: texte.bodyMedium?.copyWith(color: ink, height: 1.4),
        bodySmall: texte.bodySmall?.copyWith(color: inkSoft),
      ),
      scaffoldBackgroundColor: background,
      dividerColor: border,
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),

      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: border,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: police,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: ink, size: 24),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: rayon, side: const BorderSide(color: border)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: border,
          disabledForegroundColor: inkMuted,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: police, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: police, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: border),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: police, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontFamily: police, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        extendedTextStyle: TextStyle(fontFamily: police, fontWeight: FontWeight.w600),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: inkMuted),
        labelStyle: const TextStyle(color: inkSoft),
        prefixIconColor: inkMuted,
        suffixIconColor: inkMuted,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary, width: 1.5)),
        errorBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: errorColor)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primarySoft,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontFamily: police,
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? primary : inkMuted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 24,
              color: s.contains(WidgetState.selected) ? primary : inkMuted,
            )),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: inkMuted,
        indicatorColor: primary,
        dividerColor: border,
        labelStyle: TextStyle(fontFamily: police, fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontFamily: police, fontWeight: FontWeight.w500, fontSize: 14),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: cardColor,
        selectedColor: primarySoft,
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(fontFamily: police, fontSize: 13, color: ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        showCheckmark: false,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(BorderSide(color: border)),
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled)
              ? background
              : s.contains(WidgetState.selected)
                  ? primarySoft
                  : cardColor),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled)
              ? inkMuted.withValues(alpha: 0.6)
              : s.contains(WidgetState.selected)
                  ? primary
                  : inkSoft),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: police, fontWeight: FontWeight.w600)),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: inkSoft,
        titleTextStyle: TextStyle(fontFamily: police, fontSize: 15, fontWeight: FontWeight.w600, color: ink),
        subtitleTextStyle: TextStyle(fontFamily: police, fontSize: 13, color: inkSoft),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(fontFamily: police, color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: const TextStyle(fontFamily: police, fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary, linearTrackColor: primarySoft),
      badgeTheme: const BadgeThemeData(backgroundColor: errorColor),
    );
  }
}
