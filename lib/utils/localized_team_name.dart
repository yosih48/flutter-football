import 'package:flutter/widgets.dart';
import 'package:football/models/games.dart';
import 'package:football/resources/remote_config_service.dart';

/// Display-only Hebrew team name lookup. NEVER use the result for navigation,
/// link handling, fuzzy matching, or anywhere the original API name is needed
/// — those paths must keep using `team.name` (English).
String localizedTeamName(BuildContext context, Team team) =>
    localizedTeamNameById(context, team.id, team.name);

String localizedTeamNameById(
    BuildContext context, int id, String fallback) {
  final isHebrew = Localizations.localeOf(context).languageCode == 'he';
  if (!isHebrew) return fallback;
  return RemoteConfigService().hebrewTeamName(id) ?? fallback;
}
