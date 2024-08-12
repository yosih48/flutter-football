import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/models/users.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/resources/usersMethods.dart';

class TableScreen extends StatefulWidget {
 


  const TableScreen({super.key, });

  @override
  State<TableScreen> createState() => _TableState();
}

class _TableState extends State<TableScreen> {
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
 
  _fetchUsers();
  }
  Future<void> _fetchUsers() async {
       print('dsdsddsdsd');
    try {
      List<Map<String, dynamic>> users = await UsersMethods().fetchAllUsers();
    // Now you can work with the 'users' list directly
    for (var user in users) {
      print(user['points']['4']); // Assuming 'name' is a field in your user data
    }
         setState(() {
        _users  = users;
      });
    } 
 catch (e, stackTrace) {
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
      body: SingleChildScrollView(
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
            rows: _users.map((user) => DataRow(
              cells: [
                    DataCell(Text(user['displayName'] ?? 'N/A')),
               
                DataCell(Text(user['thisDayPoints']['4'].toString())),
                DataCell(Text(user['points']['4'].toString())),
              ],
            )).toList(),
          ),
        ),
      ),
    );

  }
}