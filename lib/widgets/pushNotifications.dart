import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:workmanager/workmanager.dart';

class NotificationManager {
  static const taskName = 'sendPushNotification';

  static Future<void> scheduleNotifications(
      Map<String, dynamic> gameData) async {
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      inputData: {
        'gameData': gameData,
      },
      frequency: const Duration(minutes: 5),
      initialDelay: const Duration(minutes: 1),
    );
  }

  static void callbackDispatcher(Map<String, dynamic>? inputData) {
    Workmanager().executeTask((task, inputData) async {
      if (task == taskName && inputData != null) {
        final gameData = inputData['gameData'] as Map<String, dynamic>;
        // Use the gameData to send push notifications
        await _sendPushNotification(
          gameData['homeTeam'] as String,
          gameData['awayTeam'] as String,
          DateTime.parse(gameData['gameTime'] as String),
        );
        return Future.value(true);
      }
      return Future.value(true);
    });
  }

  static Future<void> _sendPushNotification(
    String homeTeam,
    String awayTeam,
    DateTime gameTime,
  ) async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      // Use the FCM token to send a push notification to the user
      // via your Node.js server
      await sendPushNotification(
          fcmToken, 'Upcoming Game', '$homeTeam vs $awayTeam at $gameTime');
    }
  }
}
