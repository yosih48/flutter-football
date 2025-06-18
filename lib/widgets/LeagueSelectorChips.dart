import 'package:flutter/material.dart';

class LeagueSelectorChips extends StatefulWidget {
  const LeagueSelectorChips({
    super.key,
    required this.onSelectionChanged,
    required this.options,
    this.initialSelection = 0,
  });

  final void Function(int) onSelectionChanged;
  final List<String> options;
  final int initialSelection;

  @override
  State<LeagueSelectorChips> createState() => _LeagueSelectorChipsState();
}

class _LeagueSelectorChipsState extends State<LeagueSelectorChips> {
  late List<bool> _selectedOptions;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _selectedOptions = List<bool>.generate(
      widget.options.length,
      (index) => index == widget.initialSelection,
    );
    _scrollController = ScrollController();

    // Scroll to selected item after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSelection > 0) {
        _scrollToSelectedItem();
      }
    });
  }

  void _scrollToSelectedItem() {
    if (_scrollController.hasClients) {
      final itemWidth = 120.0; // Approximate width of each chip
      final offset = widget.initialSelection * itemWidth;
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
 return Container(
      height: 40,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(widget.options.length, (index) {
            final isSelected = _selectedOptions[index];

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  widget.options[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                onSelected: (bool selected) {
                  setState(() {
                    for (int i = 0; i < _selectedOptions.length; i++) {
                      _selectedOptions[i] = i == index;
                    }
                  });
                  widget.onSelectionChanged(index);
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
