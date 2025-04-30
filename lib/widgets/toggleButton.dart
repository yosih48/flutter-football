import 'package:flutter/material.dart';
import 'package:football/theme/colors.dart';

/// Flutter code sample for [ToggleButtons].

// const List<Widget> options = <Widget>[
//   Text('חדשות'),
//   Text('פתוחות'),
//   // Text('Orange')
// ];

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
      final itemWidth = 80.0; // Approximate width of each item
      final offset = widget.initialSelection * itemWidth;
      _scrollController.animateTo(
        offset,
        duration: Duration(milliseconds: 300),
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
      height: 85,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: ToggleButtons(
          direction: Axis.horizontal,
          onPressed: (int index) {
            setState(() {
              for (int i = 0; i < _selectedOptions.length; i++) {
                _selectedOptions[i] = i == index;
              }
            });
            widget.onSelectionChanged(index);
          },
          borderRadius: BorderRadius.circular(8),
          selectedBorderColor: Colors.transparent,
          borderColor: Colors.transparent,
          selectedColor: Colors.blue,
          fillColor: Colors.transparent,
          color: Colors.grey,
          constraints: const BoxConstraints(
            minHeight: 70.0,
            minWidth: 85.0,
          ),
          isSelected: _selectedOptions,
          children: List.generate(widget.options.length, (index) {
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _selectedOptions[index]
                        ? Colors.blue
                        : Colors.transparent,
                    width: 2.0,
                  ),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _selectedOptions[index]
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Image.network(
                          widget.imageUrls[index],
                          width: 24,
                          height: 24,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.error, size: 24);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.options[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _selectedOptions[index]
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
