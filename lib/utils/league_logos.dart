import 'package:flutter/widgets.dart';

/// Central source of truth for league artwork.
///
/// By default league badges come from API-Football's hosted images. A few
/// leagues ship with a bundled asset that overrides that artwork — e.g. the
/// official FIFA World Cup 2026 emblem (league id 1), which API-Football only
/// serves as a generic placeholder badge.
const String _leagueLogoBase =
    'https://media.api-sports.io/football/leagues/';

/// League id -> bundled asset path. Add an entry to override a league badge
/// app-wide; every display site routes through [leagueLogoProvider].
const Map<int, String> kLeagueAssetOverrides = {
  1: 'assets/icons/world_cup_2026.png', // FIFA World Cup 26
};

/// API-Football network URL for a league badge.
String leagueLogoUrl(int id) => '$_leagueLogoBase$id.png';

/// Bundled override asset for [id], or null if there is none.
String? leagueLogoAsset(int id) => kLeagueAssetOverrides[id];

/// Extracts the league id from a standard API-Football badge URL
/// (`.../leagues/<id>.png`), or null if it doesn't match.
int? leagueIdFromLogoUrl(String url) {
  final m = RegExp(r'/leagues/(\d+)\.png').firstMatch(url);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// Best [ImageProvider] for a league: the bundled asset when one exists,
/// otherwise the API-Football network badge.
ImageProvider leagueLogoProvider(int id) {
  final asset = kLeagueAssetOverrides[id];
  return asset != null
      ? AssetImage(asset)
      : NetworkImage(leagueLogoUrl(id)) as ImageProvider;
}

/// Like [leagueLogoProvider] but takes a pre-built badge URL — convenient for
/// call sites that already hold the API-Football URL string. Falls back to the
/// network image when the id can't be parsed.
ImageProvider leagueLogoProviderForUrl(String url) {
  final id = leagueIdFromLogoUrl(url);
  final asset = id == null ? null : kLeagueAssetOverrides[id];
  return asset != null ? AssetImage(asset) : NetworkImage(url) as ImageProvider;
}
