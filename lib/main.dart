import 'package:flutter/material.dart';

import 'app.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request permissions early – both dialogs appear on first launch.
  await NotificationService.instance.init();
  await LocationService.instance.getCurrentLocation();

  runApp(const RoamyApp());
}
