import 'package:flutter/material.dart';

class LeagueSelectorChips extends StatelessWidget {
  const LeagueSelectorChips({
    super.key,
    required this.onSelectionChanged,
    required this.options,
    this.selectedIndex =
        -1, // Changed from initialSelection to selectedIndex, default -1 for no selection
  });

  final void Function(int) onSelectionChanged;
  final List<String> options;
  final int selectedIndex; // This will be controlled by parent

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(options.length, (index) {
            final isSelected =
                selectedIndex == index; // Use selectedIndex from parent

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  options[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                onSelected: (bool selected) {
                  // Always call onSelectionChanged with the index
                  // The parent will handle the toggle logic
                  onSelectionChanged(index);
                },
                backgroundColor: Colors.grey[800],
                selectedColor: Colors.blue[600],
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: isSelected ? Colors.blue[600]! : Colors.grey[700]!,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
