import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import 'device_identity_service.dart';

class TelemetryService {
  TelemetryService(
    this._apiClient, {
    DeviceIdentityService? identityService,
  }) : _identityService = identityService ?? DeviceIdentityService.instance;

  final ApiClient _apiClient;
  final DeviceIdentityService _identityService;

  void track({
    required String type,
    String? action,
    String? resourceType,
    String? resourceId,
    String? screen,
    String? message,
    String severity = 'INFO',
    Map<String, Object?>? metadata,
  }) {
    unawaited(
      _send(
        type: type,
        action: action,
        resourceType: resourceType,
        resourceId: resourceId,
        screen: screen,
        message: message,
        severity: severity,
        metadata: metadata,
      ),
    );
  }

  Future<void> _send({
    required String type,
    String? action,
    String? resourceType,
    String? resourceId,
    String? screen,
    String? message,
    required String severity,
    Map<String, Object?>? metadata,
  }) async {
    try {
      final deviceId = await _identityService.getDeviceId();
      await _apiClient.post(ApiEndpoints.events, {
        'type': type,
        'action': action,
        'resourceType': resourceType,
        'resourceId': resourceId,
        'screen': screen,
        'message': message,
        'severity': severity,
        'deviceId': deviceId,
        'metadata': metadata,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (error) {
      debugPrint('Telemetry event dropped: $error');
    }
  }
}
