# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`football` — a Flutter score-prediction app (Hebrew-first, RTL). Users guess match scores across configurable leagues, compete in groups, and predict a World Cup bracket. Targets Android, iOS, and web. The app is a pure client; all data and scoring live in a **separate Node backend** (`worldBackend` repo) reached over HTTP.

## Commands

```bash
flutter pub get                      # install deps
flutter run                          # run on attached device/emulator
flutter analyze                      # lint (uses analysis_options.yaml + flutter_lints)
flutter test                         # all tests
flutter test test/widget_test.dart   # a single test file
flutter build appbundle              # Android release (Play)
flutter build apk                    # Android apk
flutter build ios                    # iOS release
dart run flutter_launcher_icons      # regenerate launcher icons after changing the source icon
```

There is no separate build/codegen step for models or localization — both are hand-written and checked in (see below).

## Backend URL is resolved at runtime

There is **no hardcoded API base**. `backendUrl` (in `lib/utils/config.dart`) is a getter that returns `RemoteConfigService().apiUrl`, which is fetched from **Firebase Remote Config** (key `api_url`) at startup, with a baked-in default (`https://scorecast.yossih.dev/`). Every data-layer class builds requests as `'$backendUrl/...'`. To point the app at a local backend, override the Remote Config default in `lib/resources/remote_config_service.dart` rather than editing call sites.

## Startup sequence (order matters)

`main()` in `lib/main.dart` initializes services in a strict order — do not reorder:

1. `Firebase.initializeApp()`
2. `RemoteConfigService().initialize()` — resolves `backendUrl`; everything downstream depends on it
3. `LeagueConfigService().initialize()` — fetches the supported-league list from the backend
4. `FirebaseMessagingService.initialize()` (push)
5. `PlayerNamesHe.load()` — bundled Hebrew player-name asset; falls back to transliteration if absent
6. `AuthProvider().initializeApp()` — restores session from secure storage

The widget tree is `VersionGuard` → `Consumer<AuthProvider>`. `VersionGuard` enforces a forced-update gate: it compares the device version against `min_required_version` (Remote Config) and routes to an update/maintenance screen. Below it, `AuthProvider` gates login; a brand-new user (`isFirstLogin`) is sent to the `Competitions` onboarding screen.

## Architecture

**State management — Provider.** Global providers are registered in a `MultiProvider` in `main.dart`: `AuthProvider` (session/user), `UserProvider`, `ThemeProvider`, `LocaleProvider`, `LeagueDataProvider`. Screens read them via `Consumer`/`Provider.of`.

**Layering.**
- `lib/screens/` — full pages. `lib/widgets/` — reusable components. `lib/responsive/` switches between mobile and web layouts.
- `lib/resources/` — the **data/network layer**: `*Methods.dart` and `*Service.dart` classes wrap raw `http` calls to `$backendUrl/...` and parse responses into models. This is where backend contracts live (e.g. `gamesMethods`, `guessesMethods`, `groupsMethods`, `bracketMethods`, `usersMethods`).
- `lib/models/` — plain Dart models with hand-written `fromJson`/`toJson` (despite `json_annotation` being a dep, there is no build_runner codegen step).

**Config services are singletons, backend-driven.**
- `RemoteConfigService` — Firebase Remote Config: `api_url`, `min_required_version`.
- `LeagueConfigService` — the authoritative list of supported leagues plus per-league metadata (localized names, `hasBracket`), fetched from the backend (`/api/config/leagues`). UI like the league chips and the bracket entry are gated off this, so leagues/features can appear or disappear without an app update. Never filter against the user's `chosenLeagues` in a way that breaks this remote list.

**Game caching.** `GameCacheService` (`lib/utils/game_cache_service.dart`) caches fixtures in `SharedPreferences` with separate TTLs (finished games 24h, upcoming ~15min, a 6h "which leagues have games on date X" master cache) and a daily noon reset. Cache keys embed a fingerprint of the current supported-league list, so changing the league config naturally invalidates stale entries. The live `games.dart` screen additionally keeps fixtures in memory and polls a lightweight live endpoint every 30s.

**Auth.** Google Sign-In + email/password. Tokens are stored in `FlutterSecureStorage`; the user object is mirrored to `SharedPreferences` for fast startup. `AuthProvider.refreshUser()` re-resolves the session against the backend.

## Localization

Hebrew (`he`, primary/RTL) and English (`en`). All user-facing strings must be added to `AppLocalizations` and translated for both locales — never hardcode user-visible text. The localization files are **maintained by hand** (there is no `l10n.yaml` / `gen-l10n` run); edit the generated-style Dart files directly.

When adding a new string:
1. Add the key + value to both `lib/l10n/app_en.arb` and `lib/l10n/app_he.arb`.
2. Add the corresponding `String get <key>;` to `lib/l10n/app_localizations.dart` and `String get <key> => '...';` overrides to `lib/l10n/app_localizations_en.dart` and `lib/l10n/app_localizations_he.dart`.
3. Reference it in code as `AppLocalizations.of(context)!.<key>`.

Note: Hebrew **team names** are display-only — localize them in `Text` widgets, but the raw `team.name` must still flow through navigation, links, and fuzzy matching unchanged.

## Versioning

`pubspec.yaml` `version:` (e.g. `6.31.43+80`) is bumped per release; commit history shows dedicated `version: x.y.z+n` commits. Bumping the build number is part of shipping a change that needs to reach users through the forced-update gate.
