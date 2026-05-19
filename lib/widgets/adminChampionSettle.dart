import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/theme/colors.dart';
import 'package:football/utils/config.dart';
import 'package:football/utils/utils.dart';
import 'package:http/http.dart' as http;

/// Admin-only end-of-season tool. Picks a league + champion team and calls
/// the backend POST /api/settle-champion. Always preview (dry run) first,
/// then confirm. Per-user idempotent on the server side.
Future<void> showAdminChampionSettleDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(16),
      child: _AdminChampionSettleSheet(),
    ),
  );
}

class _LeagueOption {
  const _LeagueOption(this.id, this.label);
  final String id;
  final String label;
}

class _AdminChampionSettleSheet extends StatefulWidget {
  const _AdminChampionSettleSheet();

  @override
  State<_AdminChampionSettleSheet> createState() =>
      _AdminChampionSettleSheetState();
}

class _AdminChampionSettleSheetState extends State<_AdminChampionSettleSheet> {
  String? _leagueId;
  String? _championTeam;
  List<String> _teams = [];
  bool _loadingTeams = false;
  bool _busy = false;
  bool _force = false;
  String? _resultText;

  List<_LeagueOption> _leagues(AppLocalizations l) => [
        _LeagueOption('39', l.premierleague),
        _LeagueOption('140', l.laliga),
        _LeagueOption('2', l.championsleague),
        _LeagueOption('3', l.europaleague),
        _LeagueOption('848', l.conferenceleague),
        _LeagueOption('383', l.ligathaal),
      ];

  Future<void> _loadTeams(String leagueId) async {
    setState(() {
      _loadingTeams = true;
      _teams = [];
      _championTeam = null;
    });
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/getTeams'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'data': leagueId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['games'] as List<dynamic>? ?? [])
            .map((t) => t['team']?['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toList()
          ..sort();
        if (mounted) setState(() => _teams = list);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to load teams: $e',
            tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _loadingTeams = false);
    }
  }

  Future<void> _settle({required bool dryRun}) async {
    final l = AppLocalizations.of(context)!;
    if (_leagueId == null || _championTeam == null) return;
    setState(() {
      _busy = true;
      _resultText = null;
    });
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/settle-champion'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'leagueId': _leagueId,
          'championName': _championTeam,
          'dryRun': dryRun,
          'force': _force,
        }),
      );
      final body = jsonDecode(response.body);
      final ok = response.statusCode == 200 && body['success'] == true;
      final r = body['result'] ?? body;

      setState(() => _resultText =
          const JsonEncoder.withIndent('  ').convert(body));

      if (!mounted) return;
      if (!ok) {
        showSnackBar(context, l.adminSettleFailed, tone: SnackTone.error);
      } else if (dryRun) {
        final n = r['wouldAward'] ?? 0;
        final already = r['alreadyAwarded'] ?? 0;
        showSnackBar(
          context,
          '${l.adminWillAward}: $n  •  ${l.adminAlreadyAwarded}: $already',
          tone: SnackTone.neutral,
        );
      } else if (r['refused'] == true) {
        showSnackBar(context, l.adminSettleFailed, tone: SnackTone.warning);
      } else {
        final n = r['awardedNow'] ?? 0;
        showSnackBar(context, '${l.adminSettleSuccess}: +$n',
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
    final canRun = _leagueId != null && _championTeam != null && !_busy;

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
              Icon(Icons.emoji_events, color: c.live, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.settleChampionTitle,
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
            items: _leagues(l)
                .map((o) => DropdownMenuItem(
                    value: o.id, child: Text(o.label)))
                .toList(),
            onChanged: _busy
                ? null
                : (v) {
                    setState(() => _leagueId = v);
                    if (v != null) _loadTeams(v);
                  },
          ),
          const SizedBox(height: 14),
          Text(l.adminChampionLabel,
              style: TextStyle(color: c.inkDim, fontSize: 12)),
          const SizedBox(height: 6),
          if (_loadingTeams)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: c.live)),
                const SizedBox(width: 10),
                Text('...', style: TextStyle(color: c.inkDim)),
              ]),
            )
          else
            DropdownButtonFormField<String>(
              value: _championTeam,
              isExpanded: true,
              dropdownColor: c.card,
              decoration: _decoration(c),
              style: TextStyle(color: c.ink),
              items: _teams
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (_leagueId == null || _busy)
                  ? null
                  : (v) => setState(() => _championTeam = v),
            ),
          const SizedBox(height: 6),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: c.live,
            value: _force,
            onChanged:
                _busy ? null : (v) => setState(() => _force = v ?? false),
            title: Text(l.adminForceOverride,
                style: TextStyle(color: c.inkDim, fontSize: 13)),
          ),
          if (_resultText != null) ...[
            const SizedBox(height: 8),
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
                  onPressed: canRun ? () => _settle(dryRun: true) : null,
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
                  onPressed: canRun ? () => _settle(dryRun: false) : null,
                  child: Text(l.adminConfirmAward,
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
