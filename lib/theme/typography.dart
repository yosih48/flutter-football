import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:football/theme/colors.dart';

/// Stadium Editorial typography.
///
/// Three voices:
///   • Display  — Bebas Neue: condensed, all-caps, athletic. Headlines, scores,
///                section labels.
///   • Body     — Sora: humanist sans with editorial proportions. UI text.
///   • Numeric  — JetBrains Mono: tabular figures for scores, odds, points.
class EType {
  // Display (Bebas Neue) — always uppercase, generous tracking.
  static TextStyle display({
    double size = 40,
    Color color = Editorial.ink,
    double letterSpacing = 1.2,
    double height = 0.95,
  }) =>
      GoogleFonts.bebasNeue(
        fontSize: size,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontWeight: FontWeight.w400,
      );

  // Editorial small-caps label, e.g. "MATCH EVENTS", "PREDICTIONS".
  static TextStyle label({
    Color color = Editorial.inkMute,
    double size = 11,
    double letterSpacing = 2.4,
  }) =>
      GoogleFonts.sora(
        fontSize: size,
        color: color,
        letterSpacing: letterSpacing,
        fontWeight: FontWeight.w600,
        height: 1.1,
      );

  static TextStyle body({
    Color color = Editorial.ink,
    double size = 14,
    FontWeight weight = FontWeight.w400,
    double height = 1.4,
  }) =>
      GoogleFonts.sora(
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
        letterSpacing: 0,
      );

  // Tabular numerals — for scores, points, odds. Always feature-locked.
  static TextStyle numeric({
    Color color = Editorial.ink,
    double size = 16,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // Massive scoreboard digits.
  static TextStyle scoreboard({
    Color color = Editorial.ink,
    double size = 64,
  }) =>
      GoogleFonts.bebasNeue(
        fontSize: size,
        color: color,
        height: 0.9,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w400,
      );
}
