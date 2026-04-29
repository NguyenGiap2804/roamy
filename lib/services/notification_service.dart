import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _canScheduleExactNotifications = false;

  static const _androidChannel = AndroidNotificationChannel(
    'roamy_reminders',
    'Roamy reminders',
    description: 'Place visit reminders for Roamy',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final timezoneName = const String.fromEnvironment(
        'ROAMY_TIMEZONE',
        defaultValue: 'Asia/Ho_Chi_Minh',
      );
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (e) {
      debugPrint('Timezone initialization failed: $e. Falling back to UTC.');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('Notification tapped: ${details.payload}');
      },
    );
    await _createAndroidChannel();
    await requestPermissions();
    _refreshExactAlarmPermission(); 
    
    // Test notification on startup to verify permissions
    await showInstantNotification('RoaMy Place', 'Hệ thống nhắc nhở đã sẵn sàng!');
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return;
    }

    if (Platform.isIOS || Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> showInstantNotification(String title, String body) async {
    await _plugin.show(
      id: _notificationIdFromDate(DateTime.now()),
      title: title,
      body: body,
      notificationDetails: _details(),
    );
  }

  Future<int> scheduleNotification(
    DateTime dateTime,
    String title,
    String body, {
    int? id,
  }) async {
    final notificationId = id ?? _notificationIdFromDate(dateTime);
    final scheduledDate = tz.TZDateTime.from(dateTime, tz.local);

    if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      await showInstantNotification(title, body);
      return notificationId;
    }

    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: _details(),
      androidScheduleMode: _androidScheduleMode,
    );

    return notificationId;
  }

  Future<void> cancelNotification(int id) {
    return _plugin.cancel(id: id);
  }

  Future<void> cancelAll() {
    return _plugin.cancelAll();
  }

  Future<void> _createAndroidChannel() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> _refreshExactAlarmPermission() async {
    if (!Platform.isAndroid) {
      _canScheduleExactNotifications = true;
      return;
    }

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final canScheduleExact =
        await androidPlugin?.canScheduleExactNotifications() ?? false;
    if (canScheduleExact) {
      _canScheduleExactNotifications = true;
      return;
    }

    _canScheduleExactNotifications =
        await androidPlugin?.requestExactAlarmsPermission() ?? false;
  }

  AndroidScheduleMode get _androidScheduleMode {
    return _canScheduleExactNotifications
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  NotificationDetails _details() {
    const androidDetails = AndroidNotificationDetails(
      'roamy_reminders',
      'Roamy reminders',
      channelDescription: 'Place visit reminders for Roamy',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/launcher_icon',
      channelShowBadge: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );
  }

  int _notificationIdFromDate(DateTime dateTime) {
    return dateTime.millisecondsSinceEpoch.remainder(2147483647);
  }
}
