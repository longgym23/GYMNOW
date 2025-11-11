import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // Initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+
    if (await _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false) {
      _isInitialized = true;
    } else {
      _isInitialized =
          true; // Still mark as initialized even if permission denied
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap if needed
    print('Notification tapped: ${response.payload}');
  }

  Future<void> showGoalExceededNotification({
    required String title,
    required String body,
    Map<String, double>? excessDetails,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Build notification body with details
    String notificationBody = body;
    if (excessDetails != null && excessDetails.isNotEmpty) {
      final details = excessDetails.entries
          .map((e) => '${e.key}: +${e.value.toStringAsFixed(0)}')
          .join(', ');
      notificationBody = '$body\n$details';
    }

    // Android notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'goal_exceeded_channel',
          'Cảnh báo vượt quá mục tiêu',
          channelDescription: 'Thông báo khi vượt quá mục tiêu dinh dưỡng',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFFF0000), // Màu đỏ
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(''),
          enableVibration: true,
          playSound: true,
        );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Notification details
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show notification
    await _notifications.show(
      1, // Notification ID
      title,
      notificationBody,
      details,
      payload: 'goal_exceeded',
    );
  }

  Future<void> showGoalCompletedNotification({
    required String title,
    required String body,
    Map<String, dynamic>? goalDetails,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Build notification body with details
    String notificationBody = body;
    if (goalDetails != null && goalDetails.isNotEmpty) {
      final details = goalDetails.entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\n');
      notificationBody = '$body\n$details';
    }

    // Android notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'goal_completed_channel',
          'Hoàn thành mục tiêu',
          channelDescription: 'Thông báo khi hoàn thành mục tiêu tập luyện',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF4CAF50), // Màu xanh lá (thành công)
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(''),
          enableVibration: true,
          playSound: true,
          ticker: '🎉 Bạn đã hoàn thành mục tiêu!',
        );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    // Notification details
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show notification
    await _notifications.show(
      2, // Notification ID (khác với goal_exceeded)
      title,
      notificationBody,
      details,
      payload: 'goal_completed',
    );
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
