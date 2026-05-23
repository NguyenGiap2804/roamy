import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

class DeviceIdentityService {
  DeviceIdentityService._();

  static final DeviceIdentityService instance = DeviceIdentityService._();

  String? _cachedDeviceId;

  Future<String> getDeviceId() async {
    final cached = _cachedDeviceId;
    if (cached != null) return cached;

    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/roamy_device_id.txt');

    if (await file.exists()) {
      final existing = (await file.readAsString()).trim();
      if (existing.isNotEmpty) {
        _cachedDeviceId = existing;
        return existing;
      }
    }

    final generated = _generateDeviceId();
    await file.writeAsString(generated, flush: true);
    _cachedDeviceId = generated;
    return generated;
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final suffix = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'roamy-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }
}
