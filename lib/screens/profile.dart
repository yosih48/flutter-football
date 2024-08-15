import 'package:flutter/material.dart';
import 'package:football/resources/usersMethods.dart';

class GroupsScreen extends StatefulWidget {
  @override
  _GroupsScreenState createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {

    Map<String, String> _userGroups = {};
    String currentUserId ='6584aceb503733cfc6418e98';

  @override
  void initState() {
    super.initState();
    _fetchUserGroups();
  }
    Future<void> _fetchUserGroups() async {
    try {
   Map<String, dynamic> userData =
          await UsersMethods().fetchUserById(currentUserId);
       setState(() {
        _userGroups = Map<String, String>.from(userData['groupID'] ?? {});
 
      });
    } catch (e) {
      print('Failed to fetch user groups: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('הקבוצות שלי', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3A5F), Color(0xFF16243B)],
          ),
        ),
        child: _userGroups.isEmpty
            ? Center(child: CircularProgressIndicator())
            :  ListView.builder(
          itemCount: _userGroups.length,
          itemBuilder: (context, index) {
                        String groupId = _userGroups.keys.elementAt(index);
                  String groupName = _userGroups.values.elementAt(index);
            return ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: 
             CircleAvatar(
               backgroundColor: Colors.grey, // Placeholder color
                      child: Text(groupName[0], style: TextStyle(color: Colors.white)),
                radius: 25,
              ),
              title: Text(
                   groupName,
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.right,
              ),
              trailing: 
                    IconButton(
                icon: Icon(Icons.exit_to_app, color: Colors.white),
                onPressed: () {
                       print('Exiting group: $groupName');
                },
              ),
       
            );
          },
        ),
      ),
    );
  }
}