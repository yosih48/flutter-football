import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/models/users.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/widgets/toggleButton.dart';

class TableScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const TableScreen({Key? key, required this.groupId, required this.groupName})
      : super(key: key);

  @override
  State<TableScreen> createState() => _TableState();
}

class _TableState extends State<TableScreen> {
  List<Map<String, dynamic>> _users = [];
  int selectedIndex = 0;
  int league = 2;
  void updateSelectedIndex(int index) {
    print(index);
    setState(() {
      league = index == 0
          ? 2
          : index == 1
              ? 4
              : 39;
      selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();

    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    print('dsdsddsdsd');
    try {
      List<Map<String, dynamic>> allUsers =
          await UsersMethods().fetchAllUsers();
      // Now you can work with the 'users' list directly
      for (var user in allUsers) {
        // print(user['points']['4']);
        // print(user['displayName']);
      }
      //   setState(() {
      //   _users = allUsers.where((user) {
      //     Map<String, dynamic>? groupID = user['groupID'];
      //     return groupID != null && groupID.containsKey(widget.groupId);
      //   }).toList();
      // });
      setState(() {
        _users = allUsers.where((user) {
          Map<String, dynamic>? groupID = user['groupID'];
          return groupID != null && groupID.containsValue(widget.groupName);
        }).toList();
      });
    } catch (e, stackTrace) {
      print('Failed to fetch guesses: $e');
      print('Stack trace: $stackTrace');
      // You might want to show an error message to the user here
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Game Details'),
      ),
      body: Column(
        children: [
          ToggleButtonsSample(
            options: [
              'champ',
              'euro',
              'english'
              // AppLocalizations.of(context)!.opens,
              // AppLocalizations.of(context)!.history
            ],
            onSelectionChanged: updateSelectedIndex,
            initialSelection: 0,
          ),
              Expanded(
            child: table(league),
          ),
        ],
      ),
    );
  }

  SingleChildScrollView table(league) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('name')),
            DataColumn(label: Text('day points')),
            DataColumn(label: Text('sum points')),
            // DataColumn(label: Text('Sum Points')),
          ],
          rows: _users
              .map((user) => DataRow(
                    cells: [
                      DataCell(Text(user['displayName'] ?? 'N/A')),
            DataCell(Text(user['thisDayPoints'][league.toString()]
                              ?.toString() ??
                          '0')),
                      DataCell(Text(
                          user['points'][league.toString()]?.toString() ??
                              '0')),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }
}
