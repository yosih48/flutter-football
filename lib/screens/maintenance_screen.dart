import 'package:flutter/material.dart';
import 'package:football/resources/remote_config_service.dart';


class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // שולפים את ההודעה מ-Firebase
    final msg = RemoteConfigService().maintenanceMessage;

    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900, // צבע דרמטי
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.construction, // אייקון של שיפוצים
                size: 80,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 24),
              // const Text(
              //   'הפסקה מתודית',
              //   style: TextStyle(
              //     fontSize: 28,
              //     fontWeight: FontWeight.bold,
              //     color: Colors.white,
              //   ),
              // ),
              const SizedBox(height: 16),
              Text(
                msg, // ההודעה הדינמית שלך
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
