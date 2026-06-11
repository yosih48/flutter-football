import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/bracket.dart';
import 'package:football/resources/bracketMethods.dart';
import 'package:football/resources/groupsMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/utils.dart';
import 'package:football/widgets/bracketLeaderboard.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A single private bracket league: its members-only standings, its roster,
/// the shareable invite code, and owner/member actions (rename, delete, leave).
class BracketLeagueScreen extends StatefulWidget {
  const BracketLeagueScreen({
    super.key,
    required this.league,
    required this.userId,
    required this.userName,
    required this.structure,
  });

  final BracketLeagueInfo league;
  final String userId;
  final String userName;
  final BracketStructure? structure;

  @override
  State<BracketLeagueScreen> createState() => _BracketLeagueScreenState();
}

class _BracketLeagueScreenState extends State<BracketLeagueScreen> {
  late BracketLeagueInfo _league;
  bool _loading = true;
  // True if anything changed that the parent list should reflect on pop.
  bool _changed = false;

  List<BracketStanding> _rows = [];

  @override
  void initState() {
    super.initState();
    _league = widget.league;
    _load();
  }

  // Rank this league's members by their BRACKET points, read from the same
  // user docs the normal leaderboard uses (no separate bracket-league store).
  Future<void> _load() async {
    setState(() => _loading = true);
    final allUsers = await UsersMethods().fetchAllUsers();
    if (!mounted) return;
    final name = _league.name;
    final lid = '${_league.leagueId}';

    bool isMember(Map<String, dynamic> u) {
      final gid = u['groupID'];
      return gid is Map && gid.values.map((v) => v.toString()).contains(name);
    }

    final rows = allUsers.where(isMember).map((u) {
      final bp = u['bracketPoints'];
      final sp = u['bracketStagePoints'];
      final pts = (bp is Map && bp[lid] is num) ? (bp[lid] as num).toInt() : 0;
      final stages = <String, int>{};
      if (sp is Map && sp[lid] is Map) {
        (sp[lid] as Map).forEach((k, v) {
          if (v is num) stages[k.toString()] = v.toInt();
        });
      }
      return BracketStanding(
        userID: u['_id']?.toString(),
        name: (u['displayName'] ?? '—').toString(),
        points: pts,
        stages: stages,
        isOwner: u['_id']?.toString() == _league.ownerUserId,
      );
    }).toList()
      ..sort((a, b) => b.points.compareTo(a.points));

    _rows = rows;
    setState(() => _loading = false);
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _league.code));
    if (!mounted) return;
    showSnackBar(context, AppLocalizations.of(context)!.bracketLeagueCodeCopied,
        tone: SnackTone.success);
  }

  Future<void> _confirmLeave() async {
    final l = AppLocalizations.of(context)!;
    final ok = await _confirm(l.bracketLeagueLeave, l.bracketLeagueLeaveConfirm);
    if (ok != true) return;
    final success =
        await GroupsMethods().leaveGroup(widget.userId, _league.name);
    if (!mounted) return;
    if (success) {
      _changed = true;
      Navigator.of(context).pop(true);
    } else {
      showSnackBar(context, l.bracketLeagueActionFailed, tone: SnackTone.error);
    }
  }

  Future<void> _confirmDelete() async {
    final l = AppLocalizations.of(context)!;
    final ok =
        await _confirm(l.bracketLeagueDelete, l.bracketLeagueDeleteConfirm);
    if (ok != true) return;
    final success =
        await GroupsMethods().deleteGroup(_league.id, _league.name);
    if (!mounted) return;
    if (success) {
      _changed = true;
      Navigator.of(context).pop(true);
    } else {
      showSnackBar(context, l.bracketLeagueActionFailed, tone: SnackTone.error);
    }
  }

  Future<bool?> _confirm(String title, String body) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: c.hairline, width: 1),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 18, height: 1, color: c.live),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title.toUpperCase(),
                        style: EType.label(
                            color: c.ink, size: 11, letterSpacing: 2.4)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(body, style: EType.body(color: c.inkMute, size: 13)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    child: Text(l.cancel.toUpperCase(),
                        style: EType.label(
                            color: c.inkMute, size: 11, letterSpacing: 1.8)),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: c.live,
                    borderRadius: BorderRadius.circular(2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(2),
                      onTap: () => Navigator.pop(ctx, true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        child: Text(l.confirm.toUpperCase(),
                            style: EType.label(
                                color: c.pitch,
                                size: 11,
                                letterSpacing: 1.8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: c.pitch,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: c.pitch,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: c.ink),
          actions: [
            if (_league.isOwner)
              IconButton(
                tooltip: l.bracketLeagueDelete,
                icon: Icon(Icons.delete_outline, color: c.live),
                onPressed: _confirmDelete,
              )
            else
              TextButton(
                onPressed: _confirmLeave,
                child: Text(l.bracketLeagueLeave,
                    style: TextStyle(color: c.live)),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _header(c, l),
              Divider(height: 1, color: c.hairline),
              Expanded(
                child: Skeletonizer(
                  enabled: _loading,
                  child: BracketLeaderboardList(
                    rows: _rows,
                    structure: widget.structure,
                    highlightUserId: widget.userId,
                    highlightName: widget.userName,
                    loading: _loading,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(EditorialColors c, AppLocalizations l) {
    return Container(
      color: c.pitch,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_league.name.toUpperCase(),
              style: EType.display(size: 26, color: c.ink, letterSpacing: 1),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.group_outlined, size: 15, color: c.inkDim),
              const SizedBox(width: 5),
              Text(
                '${_league.memberCount}',
                style: EType.numeric(color: c.inkMute, size: 13),
              ),
              const SizedBox(width: 16),
              // Tappable invite code chip.
              Expanded(
                child: InkWell(
                  onTap: _copyCode,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.hairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 14, color: c.inkDim),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(_league.code,
                              style: EType.numeric(
                                  color: c.ink, size: 13, weight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
