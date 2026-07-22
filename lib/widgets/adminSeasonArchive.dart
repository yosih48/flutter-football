import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/utils/config.dart';
import 'package:football/utils/utils.dart';
import 'package:http/http.dart' as http;

/// Admin-only "close season" tool. Picks a league + season (year) and calls
/// the backend POST /api/archive-season, which COPIES the current league
/// standing into every participant's seasonScores for the Trophy Cabinet.
/// It never resets the live points. Preview (dry run) first, then confirm.
Future<void> showAdminSeasonArchiveDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(16),
      child: _AdminSeasonArchiveSheet(),
    ),
  );
}

class _LeagueOption {
  const _LeagueOption(this.id, this.label);
  final String id;
  final String label;
}

class _AdminSeasonArchiveSheet extends StatefulWidget {
  const _AdminSeasonArchiveSheet();

  @override
  State<_AdminSeasonArchiveSheet> createState() =>
      _AdminSeasonArchiveSheetState();
}

class _AdminSeasonArchiveSheetState extends State<_AdminSeasonArchiveSheet> {
  String? _leagueId;
  // Prefill with the current year — correct for tournaments like the World Cup
  // (season 2026) and a sensible default otherwise. Admin can edit.
  late final TextEditingController _seasonCtrl =
      TextEditingController(text: '${DateTime.now().year}');
  bool _busy = false;
  String? _resultText;

  @override
  void dispose() {
    _seasonCtrl.dispose();
    super.dispose();
  }

  List<_LeagueOption> _leagues(AppLocalizations l, BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    String labelFor(int id) {
      final remote = LeagueConfigService().nameFor(id, lang);
      if (remote != null) return remote;
      switch (id) {
        case 39:
          return l.premierleague;
        case 140:
          return l.laliga;
        case 2:
          return l.championsleague;
        case 3:
          return l.europaleague;
        case 848:
          return l.conferenceleague;
        case 383:
          return l.ligathaal;
        default:
          return '$id';
      }
    }

    return LeagueConfigService()
        .supportedLeagues
        .map((id) => _LeagueOption(id.toString(), labelFor(id)))
        .toList();
  }

  Future<void> _archive({required bool dryRun}) async {
    final l = AppLocalizations.of(context)!;
    final season = int.tryParse(_seasonCtrl.text.trim());
    if (_leagueId == null || season == null) return;
    setState(() {
      _busy = true;
      _resultText = null;
    });
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/archive-season'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'leagueId': _leagueId,
          'season': season,
          'dryRun': dryRun,
        }),
      );
      final body = jsonDecode(response.body);
      final ok = response.statusCode == 200 && body['success'] == true;
      final r = body['result'] ?? body;

      setState(() =>
          _resultText = const JsonEncoder.withIndent('  ').convert(body));

      if (!mounted) return;
      if (!ok) {
        showSnackBar(context, l.adminSettleFailed, tone: SnackTone.error);
      } else if (dryRun) {
        final n = r['wouldArchive'] ?? 0;
        showSnackBar(context, '${l.archiveWillArchive}: $n',
            tone: SnackTone.neutral);
      } else {
        final n = r['archivedCount'] ?? 0;
        showSnackBar(context, '${l.archiveDoneMessage}: $n',
            tone: SnackTone.success);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _resultText = 'Error: $e');
        showSnackBar(context, l.adminSettleFailed, tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = context.col;
    final canRun = _leagueId != null &&
        int.tryParse(_seasonCtrl.text.trim()) != null &&
        !_busy;

    return Container(
      constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, color: c.live, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.closeSeasonTitle,
                    style: TextStyle(
                        color: c.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: Icon(Icons.close, color: c.inkDim),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l.adminLeagueLabel,
              style: TextStyle(color: c.inkDim, fontSize: 12)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _leagueId,
            isExpanded: true,
            dropdownColor: c.card,
            decoration: _decoration(c),
            style: TextStyle(color: c.ink),
            items: _leagues(l, context)
                .map((o) =>
                    DropdownMenuItem(value: o.id, child: Text(o.label)))
                .toList(),
            onChanged:
                _busy ? null : (v) => setState(() => _leagueId = v),
          ),
          const SizedBox(height: 14),
          Text(l.seasonNumberLabel,
              style: TextStyle(color: c.inkDim, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _seasonCtrl,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: c.ink),
            decoration: _decoration(c),
            onChanged: (_) => setState(() {}),
          ),
          if (_resultText != null) ...[
            const SizedBox(height: 12),
            Flexible(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.pitch,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.hairline),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _resultText!,
                    style: TextStyle(
                        color: c.inkMute,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.hairline),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: canRun ? () => _archive(dryRun: true) : null,
                  child: _busy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: c.ink))
                      : Text(l.adminPreview,
                          style: TextStyle(color: c.ink)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.live,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: canRun ? () => _archive(dryRun: false) : null,
                  child: Text(l.archiveConfirmButton,
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(EditorialColors c) => InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: c.pitch,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.live),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.hairline),
        ),
      );
}
