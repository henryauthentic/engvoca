import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Notification IDs
  static const int _studyReminderId = 100;
  static const int _reviewReminderId = 101;

  NotificationService._init();

  Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    // Android settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification tapped: ${response.payload}');
      },
    );

    // Request permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  // ==========================================
  // RANDOM MESSAGES
  // ==========================================

  String _getRandomStudyMessage() {
    final messages = [
      'Hãy dành vài phút để học từ vựng mới nhé 📚🐱',
      'Đừng lười nha, học xíu thôi là xong rồi! 🥱☕',
      'Từ vựng mới đang đợi bạn khám phá kìa! 🚀',
      'Hôm nay chưa học từ nào đâu đấy! Học lẹ ní ơi 🏃‍♂️💨',
      'Biết trễ rồi cũng phải học 1 tí nha, không là quên hết đó! 🧠',
      'Dậy tập thể dục cho não bằng 10 từ vựng nào! 🏋️‍♂️',
    ];
    return messages[Random().nextInt(messages.length)];
  }

  String _getRandomReviewMessage(int dueWordsCount) {
    if (dueWordsCount <= 0) {
      final messages = [
        'Tới giờ học rồi! Hãy mở app để ôn tập nhé 🐱',
        'Lâu rồi không ôn tập, chữ thầy trả cô mất thôi! 📖',
        'Vào app làm vài vòng flashcard cho nhớ lâu nào! ⚡',
      ];
      return messages[Random().nextInt(messages.length)];
    }

    final messages = [
      'Tới giờ học rồi! Bạn có $dueWordsCount từ cần ôn hôm nay 🐱',
      'Có $dueWordsCount từ chưa học nè ní học lẹ kẻo quên mất... 😱',
      '$dueWordsCount từ vựng đang khóc chờ bạn ôn kìa! 😭',
      'Ê ní ơi có $dueWordsCount từ đến lịch ôn kìa dọn lẹ! 🧹',
      'Sứ mệnh hôm nay: Diệt gọn $dueWordsCount từ vựng cứng đầu! ⚔️',
      '$dueWordsCount từ vựng đang xếp hàng chờ bạn điểm danh nè! 📋',
    ];
    return messages[Random().nextInt(messages.length)];
  }

  // ==========================================
  // STUDY REMINDER (Loại 2: Nhắc học tập)
  // ==========================================

  /// Lên lịch nhắc nhở học tập hàng ngày
  /// Gửi lúc [hour]:[minute] nếu user chưa đạt daily goal
  Future<void> scheduleStudyReminder(int hour, int minute) async {
    await _notificationsPlugin.zonedSchedule(
      _studyReminderId,
      '⏰ Tới giờ học rồi!',
      _getRandomStudyMessage(),
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_reminder_v2',
          'Nhắc nhở học tập',
          channelDescription: 'Nhắc nhở khi chưa đạt mục tiêu học tập hàng ngày',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: RawResourceAndroidNotificationSound('meow_jehtsyd'),
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          sound: 'meow_jEHtSyd.mp3',
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    print('✅ Scheduled study reminder at $hour:$minute (with meow sound 🐱)');
  }

  /// Hủy nhắc nhở học tập (khi user đã đạt mục tiêu hoặc tắt setting)
  Future<void> cancelStudyReminder() async {
    await _notificationsPlugin.cancel(_studyReminderId);
    print('❌ Cancelled study reminder');
  }

  // ==========================================
  // REVIEW REMINDER (Loại 1: Nhắc ôn tập)
  // ==========================================

  /// Lên lịch nhắc nhở ôn tập: gửi mỗi sáng 8:00 (hoặc giờ tuỳ chỉnh)
  Future<void> scheduleReviewReminder({int hour = 8, int minute = 0, int dueWordCount = 0}) async {
    final body = _getRandomReviewMessage(dueWordCount);

    await _notificationsPlugin.zonedSchedule(
      _reviewReminderId,
      '📖 Nhắc ôn tập từ vựng',
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'review_reminder_v2',
          'Nhắc ôn tập',
          channelDescription: 'Nhắc nhở ôn tập từ vựng theo lịch SM-2',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: RawResourceAndroidNotificationSound('meow_jehtsyd'),
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          sound: 'meow_jEHtSyd.mp3',
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    print('✅ Scheduled review reminder at $hour:$minute (with meow sound 🐱)');
  }

  /// Hủy nhắc nhở ôn tập
  Future<void> cancelReviewReminder() async {
    await _notificationsPlugin.cancel(_reviewReminderId);
    print('❌ Cancelled review reminder');
  }

  // ==========================================
  // GENERIC SCHEDULE (legacy support)
  // ==========================================

  Future<void> scheduleDailyReminder(String time) async {
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    await _notificationsPlugin.zonedSchedule(
      0,
      'Nhắc nhở học từ vựng 📚',
      'Đã đến giờ học! Hãy dành 15 phút để học từ vựng mới nhé 🎯',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Nhắc nhở hàng ngày',
          channelDescription: 'Nhắc nhở học từ vựng hàng ngày',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    print('✅ Scheduled daily reminder at $time');
  }

  Future<void> scheduleWeeklyReminder({
    required int dayOfWeek,
    required String time,
    required int notificationId,
  }) async {
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final scheduledDate = _nextInstanceOfWeekday(dayOfWeek, hour, minute);

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      'Nhắc nhở học từ vựng 📚',
      'Đã đến giờ học! Hãy dành thời gian ôn lại từ vựng nhé 💪',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_reminder',
          'Nhắc nhở theo tuần',
          channelDescription: 'Nhắc nhở học từ vựng theo lịch tuần',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    print('✅ Scheduled weekly reminder for day $dayOfWeek at $time');
  }

  // ==========================================
  // CANCEL
  // ==========================================

  Future<void> cancelDailyReminder() async {
    await _notificationsPlugin.cancel(0);
    print('❌ Cancelled daily reminder');
  }

  Future<void> cancelWeeklyReminder(int notificationId) async {
    await _notificationsPlugin.cancel(notificationId);
    print('❌ Cancelled weekly reminder $notificationId');
  }

  Future<void> cancelAllReminders() async {
    await _notificationsPlugin.cancelAll();
    print('❌ Cancelled all reminders');
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfWeekday(int dayOfWeek, int hour, int minute) {
    var scheduledDate = _nextInstanceOfTime(hour, minute);

    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  // ==========================================
  // TEST
  // ==========================================

  Future<void> showTestNotification({int dueWordsCount = 0}) async {
    // Test Study Reminder
    await _notificationsPlugin.show(
      998,
      '⏰ Tới giờ học rồi! (Test)',
      _getRandomStudyMessage(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_study_meow',
          'Test Học tập',
          channelDescription: 'Test channel học tập',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: RawResourceAndroidNotificationSound('meow_jehtsyd'),
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          sound: 'meow_jEHtSyd.mp3',
          presentSound: true,
        ),
      ),
    );

    // Test Review Reminder
    final body = _getRandomReviewMessage(dueWordsCount);

    await _notificationsPlugin.show(
      999,
      '📖 Nhắc ôn tập từ vựng (Test)',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_review_meow',
          'Test Ôn tập',
          channelDescription: 'Test channel ôn tập',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: RawResourceAndroidNotificationSound('meow_jehtsyd'),
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          sound: 'meow_jEHtSyd.mp3',
          presentSound: true,
        ),
      ),
    );
  }

  // ==========================================
  // PERMISSIONS
  // ==========================================

  Future<bool> checkPermissions() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<bool> requestPermissions() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}