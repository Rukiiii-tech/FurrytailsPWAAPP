// notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:customer1/booking_details_screen.dart';
// CRITICAL: Import the navigatorKey from main.dart
import 'package:customer1/main.dart'; // <--- ADD THIS IMPORT

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
// REMOVED: final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(); // <--- REMOVE THIS LINE

// Function to initialize the notification settings
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    // Pass the function defined below
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );
}

// Function to handle notification taps and navigate
void onDidReceiveNotificationResponse(
  NotificationResponse notificationResponse,
) async {
  if (notificationResponse.payload != null) {
    final bookingId = notificationResponse.payload;
    if (bookingId != null) {
      // Safely access the global navigatorKey defined in main.dart
      final context = navigatorKey.currentState?.overlay?.context;

      // Check if the context is available before pushing
      if (context != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingDetailsScreen(bookingId: bookingId),
          ),
        );
      } else {
        // Debug: If context is null, the app is likely terminated or not yet built
        print('Error: Navigator context is not available for navigation.');
      }
    }
  }
}

// Function to show a local notification with the booking status
Future<void> showLocalNotification(RemoteMessage message) async {
  if (message.notification != null) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'booking_status_channel', // Channel ID
          'Booking Status Notifications', // Channel name
          channelDescription: 'Notifications for booking status updates.',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      message.hashCode, // Unique ID for the notification
      message.notification!.title,
      message.notification!.body,
      platformChannelSpecifics,
      payload: message.data['bookingId'], // Pass bookingId to the payload
    );
  }
}
