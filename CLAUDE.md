# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Localization

All user-facing strings must be added to `AppLocalizations` and translated for both supported locales — Hebrew (`he`) and English (`en`). Never hardcode user-visible text.

When adding a new string:
1. Add the key + value to both `lib/l10n/app_en.arb` and `lib/l10n/app_he.arb`.
2. Add the corresponding `String get <key>;` to `lib/l10n/app_localizations.dart` and `String get <key> => '...';` overrides to `lib/l10n/app_localizations_en.dart` and `lib/l10n/app_localizations_he.dart`.
3. Reference it in code as `AppLocalizations.of(context)!.<key>`.
