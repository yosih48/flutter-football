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
  // final List<bool> _selectedOptions = <bool>[
  //   true,
  //   false,
  // ];
  late List<bool> _selectedOptions;

  bool vertical = false;
  @override
  void initState() {
    super.initState();
    _selectedOptions = List<bool>.generate(
      widget.options.length,
      (index) => index == widget.initialSelection,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
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
        borderRadius: BorderRadius.circular(0),
           selectedBorderColor: Colors.transparent,
          borderColor: Colors.transparent,
          selectedColor: Colors.blue,
          fillColor: Colors.transparent,
          color: Colors.grey,
          constraints: const BoxConstraints(
            minHeight: 70.0,
            minWidth: 80.0,
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
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                        Image.network(
                      widget.imageUrls[index],
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.error, size: 24);
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(widget.options[index], style: TextStyle(fontSize: 12)),
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
