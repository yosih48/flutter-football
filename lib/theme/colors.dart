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

// ── EditorialColors — ThemeExtension ─────────────────────────────────────
// Dynamic version of the Editorial palette used for light/dark switching.
// Accessed via:  final c = context.col;   →   c.pitch, c.live, etc.
//
// Unmigrated screens still compile fine because they reference the static
// `Editorial` class above.  Migrate a screen by:
//   1. Replacing `Editorial.X` → `c.X`  (where `final c = context.col;`)
//   2. Re-checking any hardcoded `Colors.*` that should also be theme-aware.
@immutable
class EditorialColors extends ThemeExtension<EditorialColors> {
  const EditorialColors({
    required this.pitch,
    required this.terrace,
    required this.card,
    required this.cardHi,
    required this.hairline,
    required this.hairlineHi,
    required this.ink,
    required this.inkMute,
    required this.inkDim,
    required this.inkFaint,
    required this.live,
    required this.liveSoft,
    required this.flag,
    required this.amber,
    required this.chalk,
  });

  final Color pitch;
  final Color terrace;
  final Color card;
  final Color cardHi;
  final Color hairline;
  final Color hairlineHi;
  final Color ink;
  final Color inkMute;
  final Color inkDim;
  final Color inkFaint;
  final Color live;
  final Color liveSoft;
  final Color flag;
  final Color amber;
  final Color chalk;

  // ── Dark preset — mirrors the static Editorial class exactly ────────────
  static const EditorialColors dark = EditorialColors(
    pitch:      Color(0xFF0A0A0B),
    terrace:    Color(0xFF111216),
    card:       Color(0xFF15161A),
    cardHi:     Color(0xFF1C1E24),
    hairline:   Color(0xFF24262C),
    hairlineHi: Color(0xFF34373F),
    ink:        Color(0xFFF3EFE6),
    inkMute:    Color(0xFFA9ADB5),
    inkDim:     Color(0xFF6B6F76),
    inkFaint:   Color(0xFF3F424A),
    live:       Color(0xFF00D26A),
    liveSoft:   Color(0x3300D26A),
    flag:       Color(0xFFFF3D5A),
    amber:      Color(0xFFFFC043),
    chalk:      Color(0xFFE8E2D2),
  );

  // ── Light preset — clean/clinical with accessible contrast ratios ───────
  static const EditorialColors light = EditorialColors(
    pitch:      Color(0xFFF7F8FA), // page background
    terrace:    Color(0xFFFFFFFF), // nav / section surfaces
    card:       Color(0xFFFFFFFF), // card background
    cardHi:     Color(0xFFF0F2F5), // elevated / selected state
    hairline:   Color(0xFFE4E7EC), // 1px dividers
    hairlineHi: Color(0xFFC9CDD6), // stronger dividers
    ink:        Color(0xFF111827), // primary text  (≈16:1 on white)
    inkMute:    Color(0xFF4B5563), // secondary text (≈7:1)
    inkDim:     Color(0xFF9CA3AF), // tertiary text  (≈2.5:1 — icons/labels only)
    inkFaint:   Color(0xFFD1D5DB), // disabled / placeholder
    live:       Color(0xFF007A3E), // green — darkened for 4.5:1 on white
    liveSoft:   Color(0xFFE8F5EE), // green tint background
    flag:       Color(0xFFDC2626), // red   — darkened for contrast
    amber:      Color(0xFFD97706), // amber — darkened for contrast
    chalk:      Color(0xFF374151), // dark stroke on light bg
  );

  // ── ThemeExtension API ───────────────────────────────────────────────────
  @override
  EditorialColors copyWith({
    Color? pitch, Color? terrace, Color? card, Color? cardHi,
    Color? hairline, Color? hairlineHi, Color? ink, Color? inkMute,
    Color? inkDim, Color? inkFaint, Color? live, Color? liveSoft,
    Color? flag, Color? amber, Color? chalk,
  }) => EditorialColors(
    pitch:      pitch      ?? this.pitch,
    terrace:    terrace    ?? this.terrace,
    card:       card       ?? this.card,
    cardHi:     cardHi     ?? this.cardHi,
    hairline:   hairline   ?? this.hairline,
    hairlineHi: hairlineHi ?? this.hairlineHi,
    ink:        ink        ?? this.ink,
    inkMute:    inkMute    ?? this.inkMute,
    inkDim:     inkDim     ?? this.inkDim,
    inkFaint:   inkFaint   ?? this.inkFaint,
    live:       live       ?? this.live,
    liveSoft:   liveSoft   ?? this.liveSoft,
    flag:       flag       ?? this.flag,
    amber:      amber      ?? this.amber,
    chalk:      chalk      ?? this.chalk,
  );

  // Enables AnimatedTheme to smoothly interpolate between dark and light.
  @override
  EditorialColors lerp(ThemeExtension<EditorialColors>? other, double t) {
    if (other is! EditorialColors) return this;
    return EditorialColors(
      pitch:      Color.lerp(pitch,      other.pitch,      t)!,
      terrace:    Color.lerp(terrace,    other.terrace,    t)!,
      card:       Color.lerp(card,       other.card,       t)!,
      cardHi:     Color.lerp(cardHi,     other.cardHi,     t)!,
      hairline:   Color.lerp(hairline,   other.hairline,   t)!,
      hairlineHi: Color.lerp(hairlineHi, other.hairlineHi, t)!,
      ink:        Color.lerp(ink,        other.ink,        t)!,
      inkMute:    Color.lerp(inkMute,    other.inkMute,    t)!,
      inkDim:     Color.lerp(inkDim,     other.inkDim,     t)!,
      inkFaint:   Color.lerp(inkFaint,   other.inkFaint,   t)!,
      live:       Color.lerp(live,       other.live,       t)!,
      liveSoft:   Color.lerp(liveSoft,   other.liveSoft,   t)!,
      flag:       Color.lerp(flag,       other.flag,       t)!,
      amber:      Color.lerp(amber,      other.amber,      t)!,
      chalk:      Color.lerp(chalk,      other.chalk,      t)!,
    );
  }
}

// ── BuildContext shorthand ────────────────────────────────────────────────
// Usage anywhere in a widget build():
//   final c = context.col;
//   Container(color: c.card, child: Text('…', style: EType.label(color: c.ink)))
extension EditorialContext on BuildContext {
  EditorialColors get col =>
      Theme.of(this).extension<EditorialColors>() ?? EditorialColors.dark;
}

