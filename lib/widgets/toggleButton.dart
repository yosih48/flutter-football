import 'package:flutter/material.dart';

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
    this.initialSelection = 0,
  });

  final void Function(int) onSelectionChanged;
  final List<String> options;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // ToggleButtons with a single selection.

            const SizedBox(height: 5),
            ToggleButtons(
              direction: vertical ? Axis.vertical : Axis.horizontal,
              onPressed: (int index) {
                setState(() {
                  // The button that is tapped is set to true, and the others to false.
                  for (int i = 0; i < _selectedOptions.length; i++) {
                    _selectedOptions[i] = i == index;
                  }
                });
                widget.onSelectionChanged(index);
              },
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              selectedBorderColor: Colors.red[700],
              selectedColor: Colors.white,
              fillColor: Colors.red[200],
              color: Colors.red[400],
              constraints: const BoxConstraints(
                minHeight: 40.0,
                minWidth: 80.0,
              ),
              isSelected: _selectedOptions,
              children: widget.options.map((option) => Text(option)).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
