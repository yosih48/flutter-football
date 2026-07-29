import 'package:flutter/material.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/league_logos.dart';

class LeagueSelectorChips extends StatefulWidget {
  const LeagueSelectorChips({
    super.key,
    required this.onSelectionChanged,
    required this.options,
    this.selectedIndex = -1,
    this.leagueIds,
  });

  final void Function(int) onSelectionChanged;
  final List<String> options;
  final int selectedIndex;

  /// Parallel to [options]. When provided, each chip shows that league's crest.
  final List<int>? leagueIds;

  @override
  State<LeagueSelectorChips> createState() => _LeagueSelectorChipsState();
}

class _LeagueSelectorChipsState extends State<LeagueSelectorChips> {
  final ScrollController _controller = ScrollController();
  // Visual edges: true when there's more content past that side of the row.
  bool _moreLeft = false;
  bool _moreRight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateEdges);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdges());
  }

  @override
  void didUpdateWidget(covariant LeagueSelectorChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The set of chips may have changed (new league added / removed) — re-check
    // overflow state after the next layout pass.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdges());
  }

  @override
  void dispose() {
    _controller.removeListener(_updateEdges);
    _controller.dispose();
    super.dispose();
  }

  void _updateEdges() {
    if (!mounted || !_controller.hasClients) return;
    final pos = _controller.position;
    // Use the scroll position's own axisDirection so the visual mapping is
    // correct regardless of textDirection. In an RTL horizontal scroll the
    // axis is AxisDirection.left → pos.pixels=0 sits at the VISUAL right,
    // so extentBefore lives on the visual right and extentAfter on the
    // visual left (mirror of LTR).
    final isReversed = pos.axisDirection == AxisDirection.left;
    final hiddenBefore = pos.extentBefore > 1;
    final hiddenAfter = pos.extentAfter > 1;
    final visualLeftHasMore = isReversed ? hiddenAfter : hiddenBefore;
    final visualRightHasMore = isReversed ? hiddenBefore : hiddenAfter;
    if (visualLeftHasMore != _moreLeft || visualRightHasMore != _moreRight) {
      setState(() {
        _moreLeft = visualLeftHasMore;
        _moreRight = visualRightHasMore;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const hPad = 20.0;
    final c = context.col;
    return SizedBox(
      height: 42,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final children = <Widget>[];
          for (int i = 0; i < widget.options.length; i++) {
            if (i > 0) children.add(const SizedBox(width: 8));
            final ids = widget.leagueIds;
            children.add(_EditorialChip(
              label: widget.options[i],
              selected: widget.selectedIndex == i,
              // Guard the index: options may be placeholders while the real
              // league list is still loading, so the two can be out of step.
              leagueId: (ids != null && i < ids.length) ? ids[i] : null,
              onTap: () => widget.onSelectionChanged(i),
            ));
          }
          // Force the row to at least fill the viewport so a small number of
          // chips centers; when they overflow, the row grows past minWidth
          // and scrolls horizontally as before.
          return Stack(
            children: [
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  // Recompute when scroll metrics change (e.g. content size
                  // shifts after a chip relayout).
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _updateEdges());
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: hPad),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth - hPad * 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: children,
                    ),
                  ),
                ),
              ),
              _EdgeHint(
                visible: _moreLeft,
                alignmentLeft: true,
                color: c,
              ),
              _EdgeHint(
                visible: _moreRight,
                alignmentLeft: false,
                color: c,
              ),
            ],
          );
        },
      ),
    );
  }
}

// Tiny chevron at one visual edge that fades in only when there are more chips
// to scroll to in that direction. The icon sits over a short gradient that
// softens the chip beneath, so it reads as "more this way" rather than as a
// button.
class _EdgeHint extends StatelessWidget {
  const _EdgeHint({
    required this.visible,
    required this.alignmentLeft,
    required this.color,
  });

  final bool visible;
  final bool alignmentLeft;
  final EditorialColors color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: alignmentLeft ? 0 : null,
      right: alignmentLeft ? null : 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1.0 : 0.0,
          child: Container(
            width: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: alignmentLeft
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                end: alignmentLeft
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                colors: [
                  color.pitch,
                  color.pitch.withOpacity(0.0),
                ],
              ),
            ),
            alignment:
                alignmentLeft ? Alignment.centerLeft : Alignment.centerRight,
            padding: EdgeInsets.only(
              left: alignmentLeft ? 2 : 0,
              right: alignmentLeft ? 0 : 2,
            ),
            // Force LTR on the icon — chevron_left/chevron_right have
            // matchTextDirection=true and would auto-mirror in an RTL app,
            // making the "left" chevron actually point right (and vice
            // versa). We want the arrows to always point OUTWARD from the
            // edge they sit on, same in both directionalities.
            child: Icon(
              alignmentLeft ? Icons.chevron_left : Icons.chevron_right,
              size: 16,
              color: color.inkDim,
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorialChip extends StatelessWidget {
  const _EditorialChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leagueId,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// When supplied the chip leads with that league's crest; otherwise it falls
  /// back to a generic trophy glyph.
  final int? leagueId;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final fg = selected ? Colors.white : c.inkMute;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          // Filled green when active, plain surface with a hairline when not.
          color: selected ? c.live : c.card,
          border: Border.all(
            color: selected ? c.live : c.hairline,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: EType.body(
                color: fg,
                size: 13,
                weight: FontWeight.w600,
                hebrew: isHe,
              ),
            ),
            const SizedBox(width: 7),
            _chipIcon(c, fg),
          ],
        ),
      ),
    );
  }

  Widget _chipIcon(EditorialColors c, Color fg) {
    if (leagueId == null) {
      return Icon(Icons.emoji_events_outlined, size: 15, color: fg);
    }
    // White backplate so dark crests stay legible on the green fill — same
    // treatment the league grid in favorits.dart uses.
    return Container(
      width: 19,
      height: 19,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Image(
        image: leagueLogoProvider(leagueId!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.emoji_events_outlined, size: 12, color: c.inkDim),
      ),
    );
  }
}
