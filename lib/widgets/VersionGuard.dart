import 'package:flutter/material.dart';
import 'package:football/resources/remote_config_service.dart';
import 'package:football/utils/utils.dart';


import '../screens/maintenance_screen.dart';

class VersionGuard extends StatefulWidget {
  final Widget child;
  const VersionGuard({super.key, required this.child});

  @override
  State<VersionGuard> createState() => _VersionGuardState();
}

class _VersionGuardState extends State<VersionGuard> {
  // State to track if we are currently under maintenance
  bool _isMaintenanceActive = false;

  // State to manage loading status (so we don't show the app before checking)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Run the check immediately when the widget mounts
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final remoteConfig = RemoteConfigService();

    // 1. Check Maintenance Mode FIRST
    // We check this directly from the service getter we created
    bool maintenance = remoteConfig.isMaintenanceMode;

    if (maintenance) {
      // If maintenance is active, update state to show the blocking screen
      if (mounted) {
        setState(() {
          _isMaintenanceActive = true;
          _isLoading = false; // Stop loading, show maintenance screen
        });
      }
      return; // Stop here, no need to check version
    }

    // 2. Check Force Update (Only if not in maintenance)
    // We use addPostFrameCallback to ensure context is ready for the dialog
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      bool mustUpdate = await remoteConfig.isUpdateRequired();

      if (mustUpdate && mounted) {
        print('🚨 Showing Force Update Dialog!');
        // Show the blocking dialog over the app
        showForceUpdateDialog(context);
      } else {
        print('✅ Version is OK.');
      }
    });

    // 3. Finish Loading
    // If we reached here, maintenance is off. We can show the app.
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Show a loader while checking Firebase (optional but recommended)
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2. If Maintenance Mode is Active -> BLOCK EVERYTHING
    // Return the MaintenanceScreen instead of the app
    if (_isMaintenanceActive) {
      return const MaintenanceScreen();
    }

    // 3. Normal State -> Show the App
    // (The Force Update dialog will overlay this if needed)
    return widget.child;
  }
}
