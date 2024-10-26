import 'package:flutter/material.dart';
import 'package:football/theme/colors.dart';

/// Flutter code sample for [ToggleButtons].

// const List<Widget> options = <Widget>[
//   Text('חדשות'),
//   Text('פתוחות'),
//   // Text('Orange')
// ];

class ToggleButtonsGames extends StatefulWidget {
  const ToggleButtonsGames({
    super.key,
    required this.onSelectionChanged,
    required this.options,
    this.initialSelection = 0,
  });

  final void Function(int) onSelectionChanged;
  final List<String> options;
  final int initialSelection;

  @override
  State<ToggleButtonsGames> createState() => _ToggleButtonsGamesState();
}

class _ToggleButtonsGamesState extends State<ToggleButtonsGames> {
  late List<bool> _selectedOptions;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: List.generate(
            widget.options.length,
            (index) => Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    for (int i = 0; i < _selectedOptions.length; i++) {
                      _selectedOptions[i] = i == index;
                    }
                    widget.onSelectionChanged(index);
                  });
                },
                child: Container(
                  height: 70,
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
                  child: Center(
                    child: Text(
                      widget.options[index],
                      style: TextStyle(
                        color: _selectedOptions[index] 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.6),
                        fontSize: 16,
                        fontWeight: _selectedOptions[index] 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}