import 'package:flutter/material.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';

class LeagueSelectorChips extends StatefulWidget {
  const LeagueSelectorChips({
    super.key,
    required this.onSelectionChanged,
    required this.options,
    this.selectedIndex = -1,
  });

  final void Function(int) onSelectionChanged;
  final List<String> options;
  final int selectedIndex;

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
    final awayFromStart = pos.pixels > 1;
    final beforeEnd = pos.pixels < pos.maxScrollExtent - 1;
    // Map logical scroll position to *visual* left/right (RTL flips them).
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final newLeft = isRtl ? beforeEnd : awayFromStart;
    final newRight = isRtl ? awayFromStart : beforeEnd;
    if (newLeft != _moreLeft || newRight != _moreRight) {
      setState(() {
        _moreLeft = newLeft;
        _moreRight = newRight;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const hPad = 20.0;
    final c = context.col;
    return SizedBox(
      height: 38,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final children = <Widget>[];
          for (int i = 0; i < widget.options.length; i++) {
            if (i > 0) children.add(const SizedBox(width: 8));
            children.add(_EditorialChip(
              label: widget.options[i],
              selected: widget.selectedIndex == i,
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
            alignment: alignmentLeft
                ? Alignment.centerLeft
                : Alignment.centerRight,
            padding: EdgeInsets.only(
              left: alignmentLeft ? 2 : 0,
              right: alignmentLeft ? 0 : 2,
            ),
            child: Icon(
              alignmentLeft ? Icons.chevron_left : Icons.chevron_right,
              size: 16,
              color: color.inkDim,
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? c.ink : Colors.transparent,
          border: Border.all(
            color: selected ? c.ink : c.hairline,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label.toUpperCase(),
          style: EType.label(
            color: selected ? c.pitch : c.inkMute,
            size: 11,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }
}
