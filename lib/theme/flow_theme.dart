import 'package:flutter/material.dart';

abstract final class FlowTheme {
  static const background = Color(0xFF100E17);
  static const videoStage = Color(0xFF08090D);
  static const panel = Color(0xFF1C1827);
  static const raised = Color(0xFF292237);
  static const header = Color(0xFF251B35);
  static const border = Color(0xFF453953);
  static const controlBorder = Color(0xFF705F82);
  static const accent = Color(0xFFC4A5FA);
  static const onAccent = Color(0xFF27123F);
  static const selected = Color(0xFF63418A);
  static const text = Color(0xFFF5EFFB);
  static const muted = Color(0xFFC0B6CD);
  static const positive = Color(0xFF6ED7AE);
  static const negative = Color(0xFFFF8A8A);
  static const neutral = Color(0xFFBCC3D0);
  static const warning = Color(0xFFFFD07A);
  static const warningSurface = Color(0xFF3A2D19);

  static ThemeData get dark {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF9160D5),
          brightness: Brightness.dark,
        ).copyWith(
          surface: panel,
          primary: accent,
          onPrimary: onAccent,
          primaryContainer: selected,
          onPrimaryContainer: text,
          onSurface: text,
          onSurfaceVariant: muted,
          outline: controlBorder,
          outlineVariant: border,
          error: negative,
          onError: background,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      dividerColor: border,
      focusColor: accent,
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
