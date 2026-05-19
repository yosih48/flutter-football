import 'package:flutter/material.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';

class LeagueSelectorChips extends StatelessWidget {
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
  Widget build(BuildContext context) {
    const hPad = 20.0;
    return SizedBox(
      height: 38,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final children = <Widget>[];
          for (int i = 0; i < options.length; i++) {
            if (i > 0) children.add(const SizedBox(width: 8));
            children.add(_EditorialChip(
              label: options[i],
              selected: selectedIndex == i,
              onTap: () => onSelectionChanged(i),
            ));
          }
          // Force the row to at least fill the viewport so a small number of
          // chips centers; when they overflow, the row grows past minWidth
          // and scrolls horizontally as before.
          return SingleChildScrollView(
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
          );
        },
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
