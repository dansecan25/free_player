import 'package:flutter/material.dart';

/// The theme color picked in Settings. Stored by name, so keep names stable.
enum AppAccent {
  /// Hair pink from the icon artwork, the default.
  pink('Pink', Color(0xFFF4ABD5), DynamicSchemeVariant.tonalSpot),

  /// The bright blue of the original player.
  blue('Blue', Color(0xFF0F47FF), DynamicSchemeVariant.fidelity),
  purple('Purple', Color(0xFF7C4DFF), DynamicSchemeVariant.fidelity),
  teal('Teal', Color(0xFF00897B), DynamicSchemeVariant.fidelity),
  orange('Orange', Color(0xFFFF6D00), DynamicSchemeVariant.fidelity),
  red('Red', Color(0xFFD50000), DynamicSchemeVariant.fidelity);

  final String label;
  final Color seed;

  /// Fidelity keeps the main color close to [seed], so a vivid color stays vivid.
  final DynamicSchemeVariant variant;

  const AppAccent(this.label, this.seed, this.variant);
}

/// Light and dark themes, built from the chosen [AppAccent].
class AppTheme {
  AppTheme._();

  static ThemeData light(AppAccent accent) => _build(accent, Brightness.light);
  static ThemeData dark(AppAccent accent) => _build(accent, Brightness.dark);

  static ThemeData _build(AppAccent accent, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent.seed,
      brightness: brightness,
      dynamicSchemeVariant: accent.variant,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
        indent: 16,
        endIndent: 16,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withValues(alpha: 0.25),
        thumbColor: scheme.primary,
      ),
      listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
    );
  }
}
