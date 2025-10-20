// // lib/services/notification_service.dart
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/data/latest.dart' as tz;
// import 'package:timezone/timezone.dart' as tz;

// class NotificationService {
//   static final NotificationService _notificationService = NotificationService._internal();
//   factory NotificationService() {
//     return _notificationService;
//   }
//   NotificationService._internal();

//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   Future<void> init() async {
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');

//     // **QUAN TRỌNG**: Xử lý quyền trên iOS
//     final DarwinInitializationSettings initializationSettingsIOS =
//         DarwinInitializationSettings(
//       requestAlertPermission: false, // Sẽ yêu cầu riêng lẻ sau
//       requestBadgePermission: false,
//       requestSoundPermission: false,
//       onDidReceiveLocalNotification:
//           (int id, String? title, String? body, String? payload) async {
//         // Xử lý khi nhận thông báo lúc app đang mở (iOS < 10)
//       },
//     );

//     final InitializationSettings initializationSettings =
//         InitializationSettings(
//             android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

//     tz.initializeTimeZones(); // Khởi tạo timezone

//     await flutterLocalNotificationsPlugin.initialize(initializationSettings,
//       onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
//         // Xử lý khi người dùng nhấn vào thông báo
//         // Ví dụ: điều hướng đến màn hình cụ thể
//       });
//   }

//   /// Yêu cầu quyền trên iOS (chỉ gọi khi người dùng nhấn nút đặt lịch)
//   Future<void> requestIOSPermissions() async {
//     await flutterLocalNotificationsPlugin
//         .resolvePlatformSpecificImplementation<
//             IOSFlutterLocalNotificationsPlugin>()
//         ?.requestPermissions(
//           alert: true,
//           badge: true,
//           sound: true,
//         );
//   }

//   /// Lên lịch thông báo lặp lại hàng ngày
//   Future<void> scheduleWorkoutNotification({
//     required int id,
//     required String title,
//     required String body,
//     required DateTime scheduledTime,
//   }) async {
//     await flutterLocalNotificationsPlugin.zonedSchedule(
//       id,
//       title,
//       body,
//       _nextInstanceOfTime(scheduledTime), // Tính toán thời gian hợp lệ tiếp theo
//       const NotificationDetails(
//         android: AndroidNotificationDetails(
//           'workout_daily_channel_id', // ID kênh mới
//           'Workout Daily Reminders',
//           channelDescription: 'Channel for daily workout reminders',
//           importance: Importance.max,
//           priority: Priority.high,
//           icon: '@mipmap/ic_launcher',
//         ),
//         iOS: DarwinNotificationDetails(),
//       ),
//       // **SỬA LẠI CHO ĐÚNG**: Đảm bảo androidAllowWhileIdle là đúng
//       androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//       uiLocalNotificationDateInterpretation:
//           UILocalNotificationDateInterpretation.absoluteTime,
//       matchDateTimeComponents: DateTimeComponents.time, // Lặp lại hàng ngày vào GIỜ và PHÚT đó
//     );
//   }

//   /// Tính toán thời điểm tiếp theo cho thời gian đã chọn
//   tz.TZDateTime _nextInstanceOfTime(DateTime time) {
//     final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
//     tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
//     if (scheduledDate.isBefore(now)) {
//       scheduledDate = scheduledDate.add(const Duration(days: 1));
//     }
//     return scheduledDate;
//   }
// }