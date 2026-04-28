import 'package:flutter/material.dart';

// ── Legacy tokens (kept for backward-compatibility with un-migrated screens).
const Color primary = Color(0xFFFF3378);
const Color secondary = Color(0xFFFF2278);
const Color black = Color(0xFF000000);
const Color white = Color(0xFFFFFFFF);
const Color grey = Colors.grey;
const Color red = Color(0xFFec5766);
const Color green = Color(0xFF43aa8b);
const Color blue = Color(0xFF28c2ff);
const Color background = Color(0xFF16181b);
const Color cards = Color(0xFF21282d);

// ── Stadium Editorial tokens ─────────────────────────────────────────────
// A dark, magazine-grade palette. Use through the `Editorial` namespace so
// the legacy globals above stay untouched until each screen is migrated.
class Editorial {
  // Surfaces — deep, slightly cool black graduating up to elevated chrome.
  static const Color pitch       = Color(0xFF0A0A0B); // app background
  static const Color terrace     = Color(0xFF111216); // section background
  static const Color card        = Color(0xFF15161A); // primary surface
  static const Color cardHi      = Color(0xFF1C1E24); // elevated surface
  static const Color hairline    = Color(0xFF24262C); // 1px dividers
  static const Color hairlineHi  = Color(0xFF34373F); // hover/active dividers

  // Ink — warm cream over black (never pure white) for editorial feel.
  static const Color ink         = Color(0xFFF3EFE6); // primary text
  static const Color inkMute     = Color(0xFFA9ADB5); // secondary text
  static const Color inkDim      = Color(0xFF6B6F76); // tertiary text
  static const Color inkFaint    = Color(0xFF3F424A); // disabled / placeholder

  // Signal colors — high-contrast accents used sparingly.
  static const Color live        = Color(0xFF00D26A); // live, action, save
  static const Color liveSoft    = Color(0x3300D26A);
  static const Color flag        = Color(0xFFFF3D5A); // alerts, red cards, FT
  static const Color amber       = Color(0xFFFFC043); // halftime, postponed
  static const Color chalk       = Color(0xFFE8E2D2); // accent stroke
}

