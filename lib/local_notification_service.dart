import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidInit);

    await _plugin.initialize(settings);

    // Request notification permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showBillNotification({
    required String customerName,
    required double totalAmount,
    required double remaining,
    required double totalDue,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'bill_channel',           // channel id
      'Bill Notifications',     // channel name
      channelDescription: 'Notifications about new bills',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique id
      '🧾 New Bill from $customerName',
      'Total: ₹${totalAmount.toStringAsFixed(2)} | Paid: ₹${(totalAmount - remaining).toStringAsFixed(2)} | Due: ₹${remaining.toStringAsFixed(2)}  |  Total Outstanding: ₹${totalDue.toStringAsFixed(2)}',
      details,
    );
    debugPrint("[LOCAL PUSH] Notification sent for bill: $customerName");
  }

  static Future<void> showWelcomeNotification({
    required String shopName,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'welcome_channel',
      'Welcome Notifications',
      channelDescription: 'New customer welcome alerts',
      importance: Importance.high,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      0,
      '👋 Welcome to $shopName!',
      'You are now registered as a customer. Track your bills here.',
      details,
    );
  }
}
