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

  // Team / national-team name in a "display" slot (match cards, hero headers).
  // Latin → Bebas Neue, matching the editorial display voice. Hebrew → Rubik
  // bold: Bebas Neue ships no Hebrew glyphs, so without this Hebrew names fall
  // back to an inconsistent, thin system font. Rubik keeps the heft/weight
  // visually aligned with the Latin display across every screen.
  static TextStyle teamNameDisplay({
    double size = 16,
    Color color = Editorial.ink,
    double letterSpacing = 0.6,
    double height = 1.05,
    bool hebrew = false,
  }) =>
      hebrew
          ? GoogleFonts.rubik(
              fontSize: size,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: height,
            )
          : GoogleFonts.bebasNeue(
              fontSize: size,
              color: color,
              letterSpacing: letterSpacing,
              height: height,
              fontWeight: FontWeight.w400,
            );

  // Screen title in an app-bar slot ("FIXTURES", "משחקים").
  //
  // Same reasoning as [teamNameDisplay]: Bebas Neue carries no Hebrew glyphs,
  // so a Hebrew title styled with [display] silently falls back to a thin,
  // inconsistent system font. Rubik bold gives Hebrew the weight the Latin
  // display voice has.
  static TextStyle screenTitle({
    double size = 26,
    Color color = Editorial.ink,
    double letterSpacing = 1.4,
    bool hebrew = false,
  }) =>
      hebrew
          ? GoogleFonts.rubik(
              fontSize: size,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.15,
            )
          : GoogleFonts.bebasNeue(
              fontSize: size,
              color: color,
              letterSpacing: letterSpacing,
              height: 0.95,
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
