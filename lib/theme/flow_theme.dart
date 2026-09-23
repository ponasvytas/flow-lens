import 'package:flutter/material.dart';

abstract final class FlowTheme {
  static const background = Color(0xFF100E17);
  static const panel = Color(0xFF1C1827);
  static const raised = Color(0xFF292237);
  static const border = Color(0xFF453953);
  static const accent = Color(0xFFC4A5FA);
  static const muted = Color(0xFFC0B6CD);

  static ThemeData get dark {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF9160D5),
          brightness: Brightness.dark,
        ).copyWith(
          surface: panel,
          primary: accent,
          onPrimary: const Color(0xFF27123F),
          onSurface: const Color(0xFFF5EFFB),
          onSurfaceVariant: muted,
          outline: border,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      dividerColor: border,
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 500),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: raised,
        border: OutlineInputBorder(),
      ),
      popupMenuTheme: const PopupMenuThemeData(color: raised),
      dialogTheme: const DialogThemeData(backgroundColor: panel),
    );
  }
}
