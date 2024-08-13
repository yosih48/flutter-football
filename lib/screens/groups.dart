import 'package:flutter/material.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/table.dart';

class GroupListScreen extends StatefulWidget {
  // final String currentUserId;

  const GroupListScreen({Key? key, 
  // required this.currentUserId
  }) : super(key: key);

  @override
  _GroupListScreenState createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  Map<String, String>? _userGroups;
  String currentUserId = '6584aceb503733cfc6418e98';

  @override
  void initState() {
    super.initState();
    _fetchUserGroups();
  }

  Future<void> _fetchUserGroups() async {
    try {
      
      Map<String, dynamic> userData = await UsersMethods().fetchUserById(currentUserId);
      setState(() {
        _userGroups = Map<String, String>.from(userData['groupID'] ?? {});
      });
    } catch (e) {
      print('Failed to fetch user groups: $e');
      // Show an error message to the user
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Groups'),
      ),
      body: _userGroups == null
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _userGroups!.length,
              itemBuilder: (context, index) {
                String groupId = _userGroups!.keys.elementAt(index);
                String groupName = _userGroups![groupId]!;
                return ListTile(
                  title: Text(groupName),
                  onTap: () {
                    print(groupName);
                    print(groupId);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TableScreen(groupId: groupId,groupName: groupName ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}