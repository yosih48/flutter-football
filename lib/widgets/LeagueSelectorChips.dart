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
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = selectedIndex == index;
          return _EditorialChip(
            label: options[index],
            selected: isSelected,
            onTap: () => onSelectionChanged(index),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Editorial.ink : Colors.transparent,
            border: Border.all(
              color: selected ? Editorial.ink : Editorial.hairline,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            label.toUpperCase(),
            style: EType.label(
              color: selected ? Editorial.pitch : Editorial.inkMute,
              size: 11,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
