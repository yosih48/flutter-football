import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/bracket.dart';
import 'package:football/resources/bracketMethods.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/utils/config.dart';
import 'package:football/utils/utils.dart';
import 'package:http/http.dart' as http;

/// Admin-only bracket settlement tool. Picks a tournament league + a stage and
/// calls POST /api/settle-bracket (per stage, with dry-run preview), or the
/// "all stages" sweep via POST /api/auto-settle-bracket. Per-user idempotent on
/// the server side — the same sweep the cron runs automatically.
Future<void> showAdminBracketSettleDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(16),
      child: _AdminBracketSettleSheet(),
    ),
  );
}

// Sentinel stage value for the "sweep every stage" option.
const String _kAllStages = '__all__';

class _LeagueOption {
  const _LeagueOption(this.id, this.label);
  final String id;
  final String label;
}

class _AdminBracketSettleSheet extends StatefulWidget {
  const _AdminBracketSettleSheet();

  @override
  State<_AdminBracketSettleSheet> createState() =>
      _AdminBracketSettleSheetState();
}

class _AdminBracketSettleSheetState extends State<_AdminBracketSettleSheet> {
  final BracketMethods _api = BracketMethods();

  String? _leagueId;
  String? _stage; // a stage key, or _kAllStages
  List<BracketStage> _stages = [];
  bool _loadingStages = false;
  bool _busy = false;
  bool _force = false;
  String? _resultText;

  // Only leagues that actually have a bracket configured.
  List<_LeagueOption> _leagues(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return LeagueConfigService()
        .supportedLeagues
        .where((id) => LeagueConfigService().hasBracket(id))
        .map((id) => _LeagueOption(
            id.toString(), LeagueConfigService().nameFor(id, lang) ?? '$id'))
        .toList();
  }

  Future<void> _loadStages(String leagueId) async {
    setState(() {
      _loadingStages = true;
      _stages = [];
      _stage = null;
    });
    try {
      final structure = await _api.fetchStructure(int.parse(leagueId));
      if (mounted) {
        setState(() => _stages = structure?.stages ?? []);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to load stages: $e',
            tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _loadingStages = false);
    }
  }

  Future<void> _settle({required bool dryRun}) async {
    final l = AppLocalizations.of(context)!;
    if (_leagueId == null || _stage == null) return;
    setState(() {
      _busy = true;
      _resultText = null;
    });
    try {
      final isAll = _stage == _kAllStages;
      final uri = Uri.parse(isAll
          ? '$backendUrl/api/auto-settle-bracket'
          : '$backendUrl/api/settle-bracket');
      final payload = isAll
          ? {'leagueId': _leagueId}
          : {
              'leagueId': _leagueId,
              'stage': _stage,
              'dryRun': dryRun,
              'force': _force,
            };
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      final body = jsonDecode(response.body);
      final ok = response.statusCode == 200 && body['success'] == true;
      final r = body['result'] ?? body;

      setState(() =>
          _resultText = const JsonEncoder.withIndent('  ').convert(body));

      if (!mounted) return;
      if (!ok) {
        showSnackBar(context, l.adminSettleFailed, tone: SnackTone.error);
      } else if (isAll) {
        showSnackBar(context, l.adminBracketSettleSuccess,
            tone: SnackTone.success);
      } else if (dryRun) {
        final n = r['wouldAward'] ?? 0;
        final pts = r['totalPoints'] ?? 0;
        showSnackBar(
          context,
          '${l.adminWillAward}: $n  •  $pts ${l.bracketPointsLabel}',
          tone: SnackTone.neutral,
        );
      } else if (r['refused'] == true) {
        showSnackBar(context, l.adminSettleFailed, tone: SnackTone.warning);
      } else {
        final n = r['awardedNow'] ?? 0;
        showSnackBar(context, '${l.adminBracketSettleSuccess}: +$n',
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
    final lang = Localizations.localeOf(context).languageCode;
    final isAll = _stage == _kAllStages;
    final canRun = _leagueId != null && _stage != null && !_busy;

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
              Icon(Icons.account_tree_outlined, color: c.live, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.settleBracketTitle,
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
            items: _leagues(context)
                .map((o) =>
                    DropdownMenuItem(value: o.id, child: Text(o.label)))
                .toList(),
            onChanged: _busy
                ? null
                : (v) {
                    setState(() => _leagueId = v);
                    if (v != null) _loadStages(v);
                  },
          ),
          const SizedBox(height: 14),
          Text(l.adminStageLabel,
              style: TextStyle(color: c.inkDim, fontSize: 12)),
          const SizedBox(height: 6),
          if (_loadingStages)
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
              value: _stage,
              isExpanded: true,
              dropdownColor: c.card,
              decoration: _decoration(c),
              style: TextStyle(color: c.ink),
              items: [
                DropdownMenuItem(
                    value: _kAllStages,
                    child: Text(l.adminAutoSettleAllStages)),
                ..._stages.map((s) => DropdownMenuItem(
                    value: s.key, child: Text(s.label(lang)))),
              ],
              onChanged: (_leagueId == null || _busy)
                  ? null
                  : (v) => setState(() => _stage = v),
            ),
          const SizedBox(height: 6),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: c.live,
            value: _force,
            // Force only applies to a single-stage settle.
            onChanged: (_busy || isAll)
                ? null
                : (v) => setState(() => _force = v ?? false),
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
                  // Preview is a dry-run; the all-stages sweep has no preview.
                  onPressed:
                      (canRun && !isAll) ? () => _settle(dryRun: true) : null,
                  child: _busy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: c.ink))
                      : Text(l.adminPreview, style: TextStyle(color: c.ink)),
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
                          color: Colors.black, fontWeight: FontWeight.bold)),
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
