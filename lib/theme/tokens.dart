import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Palette ──────────────────────────────────────────────────────────────────

class SGPalette {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color text;
  final Color textDim;
  final Color textFaint;
  final Color border;
  final Color borderStrong;
  final Color accent;
  final Color success;
  final Color warn;
  final Color chipBg;
  final Color inputBg;
  final Color railBg;

  const SGPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.textDim,
    required this.textFaint,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.success,
    required this.warn,
    required this.chipBg,
    required this.inputBg,
    required this.railBg,
  });

  static const light = SGPalette(
    bg: Color(0xFFF4F1EA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFAF7F0),
    text: Color(0xFF1A1916),
    textDim: Color(0xFF725C3E),
    textFaint: Color(0xFFAFA084),
    border: Color(0x0F14120E),
    borderStrong: Color(0x2414120E),
    accent: Color(0xFFE08585),
    success: Color(0xFF8FBB6F),
    warn: Color(0xFFE5C74D),
    chipBg: Color(0x0A14120E),
    inputBg: Color(0x0814120E),
    railBg: Color(0x0D14120E),
  );

  static const dark = SGPalette(
    bg: Color(0xFF0E0F12),
    surface: Color(0xFF181A1F),
    surface2: Color(0xFF22252B),
    text: Color(0xFFF2EFE8),
    textDim: Color(0xFFB8AD9E),
    textFaint: Color(0xFF77715D),
    border: Color(0x12FFFFFF),
    borderStrong: Color(0x24FFFFFF),
    accent: Color(0xFFF0A8A8),
    success: Color(0xFFB8D996),
    warn: Color(0xFFF5DF66),
    chipBg: Color(0x14FFFFFF),
    inputBg: Color(0x0FFFFFFF),
    railBg: Color(0x0DFFFFFF),
  );
}

SGPalette pal(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light ? SGPalette.light : SGPalette.dark;

// ── Typography ────────────────────────────────────────────────────────────────

class SGText {
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w800,
    double ls = -0.4,
    double? lh,
    Color? color,
  }) =>
      GoogleFonts.archivo(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: ls,
        height: lh,
        color: color,
      );

  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    FontStyle style = FontStyle.normal,
  }) =>
      GoogleFonts.interTight(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontStyle: style,
      );

  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w600,
    double ls = 0.5,
    Color? color,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: ls,
        color: color,
      );
}

// ── Radii ─────────────────────────────────────────────────────────────────────

class SGRadius {
  static const chip = 999.0;
  static const btn = 14.0;
  static const card = 22.0;
  static const hero = 28.0;
  static const sheet = 28.0;
  static const stepper = 14.0;
  static const stat = 16.0;
}

// ── Theme ─────────────────────────────────────────────────────────────────────

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.light ? SGPalette.light : SGPalette.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: brightness,
      surface: p.bg,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SGRadius.sheet)),
      ),
      modalBarrierColor: const Color(0x59000000),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: SGText.body(14, style: FontStyle.italic, color: p.textFaint),
    ),
  );
}
