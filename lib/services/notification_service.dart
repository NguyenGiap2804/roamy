import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'roamy_reminders',
    'Roamy reminders',
    description: 'Place visit reminders for Roamy',
    importance: Importance.high,
  );

  Future<void> init() async {
    tz.initializeTimeZones();
    final timezoneName = const String.fromEnvironment(
      'ROAMY_TIMEZONE',
      defaultValue: 'Asia/Ho_Chi_Minh',
    );
    tz.setLocalLocation(tz.getLocation(timezoneName));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _plugin.initialize(settings: settings);
    await _createAndroidChannel();
    await requestPermissions();
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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

  NotificationDetails _details() {
    const androidDetails = AndroidNotificationDetails(
      'roamy_reminders',
      'Roamy reminders',
      channelDescription: 'Place visit reminders for Roamy',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
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
