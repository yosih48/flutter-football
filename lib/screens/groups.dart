// import 'package:flutter/material.dart';
// import 'package:football/providers/flutter%20pub%20add%20provider.dart';
// import 'package:football/resources/auth.dart';
// import 'package:football/resources/usersMethods.dart';
// import 'package:football/screens/login_screen.dart';
// import 'package:football/screens/table.dart';
// import 'package:provider/provider.dart';

// class GroupList extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Consumer2<AuthProvider, UserProvider>(
//       builder: (context, authProvider, userProvider, child) {
//         // Check if user is authenticated
//         if (authProvider.user == null) {
//           return LoginScreen(); // Or some other widget for unauthenticated users
//         }
//         return _GroupListContent(
//           authProvider: authProvider,
//           userProvider: userProvider,
//         );
//       },
//     );
//   }
// }

// class _GroupListContent extends StatefulWidget {
//   final AuthProvider authProvider;
//   final UserProvider userProvider;

//   _GroupListContent({
//     required this.authProvider,
//     required this.userProvider,
//   });

//   @override
//   _GroupListContentState createState() => _GroupListContentState();
// }

// class _GroupListContentState extends State<_GroupListContent> {
//   Map<String, String>? _userGroups;
//  late String currentUserId;

//   @override
//   void initState() {
//     super.initState();
//      currentUserId = widget.authProvider.user?.id ?? 'Not logged in';
//     _fetchUserGroups();
//   }

//   Future<void> _fetchUserGroups() async {
//     try {
      
//       Map<String, dynamic> userData = await UsersMethods().fetchUserById(currentUserId);
//       setState(() {
//         _userGroups = Map<String, String>.from(userData['groupID'] ?? {});
//       });
//     } catch (e) {
//       print('Failed to fetch user groups: $e');
//       // Show an error message to the user
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('My Groups'),
//       ),
// body: _userGroups == null
//           ? Center(child: CircularProgressIndicator())
//           : ListView.builder(
//               itemCount: _userGroups!.length,
//               itemBuilder: (context, index) {
//                 String groupId = _userGroups!.keys.elementAt(index);
//                 String groupName = _userGroups![groupId]!;
//                 return Padding(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//                   child: Card(
//                     elevation: 2,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(15),
//                     ),
//                     child: ListTile(
//                       contentPadding:
//                           EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                       title: Text(
//                         groupName,
//                         style: TextStyle(
//                             fontSize: 18, fontWeight: FontWeight.bold),
//                       ),
//                       tileColor: Colors.blue[50],
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(15),
//                       ),
//                       onTap: () {
//                         print(groupName);
//                         print(groupId);
//                         // Navigator.push(
//                         //   context,
//                         //   MaterialPageRoute(
//                         //     builder: (context) => TableScreen(
//                         //         groupId: groupId, groupName: groupName),
//                         //   ),
//                         // );
//                       },
//                     ),
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }