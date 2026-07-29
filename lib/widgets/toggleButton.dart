import 'package:flutter/material.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/league_logos.dart';

/// Editorial league rail — horizontally scrolling crests with an
/// underline indicator on the active league. API-compatible with the
/// previous `ToggleButtonsSample`.
class ToggleButtonsSample extends StatefulWidget {
  const ToggleButtonsSample({
    super.key,
    required this.onSelectionChanged,
    required this.options,
    required this.imageUrls,
    this.initialSelection = 0,
  });

  final void Function(int) onSelectionChanged;
  final List<String> options;
  final List<String> imageUrls;
  final int initialSelection;

  @override
  State<ToggleButtonsSample> createState() => _ToggleButtonsSampleState();
}

class _ToggleButtonsSampleState extends State<ToggleButtonsSample> {
  late int _selected;
  late ScrollController _scrollController;
  static const double _itemWidth = 86.0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selected > 0) _scrollTo(_selected);
    });
  }

  // LeagueSelector renders placeholder chips (every supported league) on the
  // first frame, then swaps in the user's chosen subset once the fetch lands.
  // Both the list and the resolved index change, so a _selected latched in
  // initState ends up pointing at the wrong league — typically the next one
  // along, since the real list is the placeholder minus the leagues the user
  // opted out of. Re-sync when the parent hands us a new selection.
  @override
  void didUpdateWidget(ToggleButtonsSample old) {
    super.didUpdateWidget(old);
    if (widget.initialSelection == old.initialSelection &&
        widget.options.length == old.options.length) {
      return;
    }
    final next = widget.initialSelection;
    // No-op when the change is the echo of our own tap, which already set
    // _selected locally before notifying the parent.
    if (next == _selected || next < 0 || next >= widget.options.length) return;
    setState(() => _selected = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollTo(next);
    });
  }

  void _scrollTo(int index) {
    if (!_scrollController.hasClients) return;
    final target = (index * _itemWidth)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    const hPad = 16.0;
    return SizedBox(
      height: 92,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final items = <Widget>[
            for (int i = 0; i < widget.options.length; i++) _buildItem(i, c),
          ];
          // Center a small number of crests; scroll when they overflow.
          return SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: hPad),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth - hPad * 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: items,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItem(int i, EditorialColors c) {
    final isSelected = i == _selected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selected = i);
        widget.onSelectionChanged(i);
        _scrollTo(i);
      },
      child: SizedBox(
        width: _itemWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: isSelected ? c.live : c.hairline,
                  width: isSelected ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Image(
                image: leagueLogoProviderForUrl(widget.imageUrls[i]),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: c.inkDim,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 20,
              child: Text(
                widget.options[i].toUpperCase(),
                style: EType.label(
                  color: isSelected ? c.ink : c.inkDim,
                  size: 9,
                  letterSpacing: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isSelected ? 22 : 0,
              height: 2,
              color: c.live,
            ),
          ],
        ),
      ),
    );
  }
}
