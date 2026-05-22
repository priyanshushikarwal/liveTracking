import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

final trackingSocketServiceProvider = Provider<TrackingSocketService>((ref) {
  return TrackingSocketService();
});

class TrackingSocketService {
  io.Socket connect({
    required String token,
    required String actorType,
    String? organizationId,
  }) {
    final options = io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableReconnection()
        .setReconnectionAttempts(999999)
        .setReconnectionDelay(1500)
        .setReconnectionDelayMax(8000)
        .setTimeout(10000)
        .setAckTimeout(6000)
        .setAuth({
          'token': token,
          'actorType': actorType,
          if (organizationId != null && organizationId.isNotEmpty)
            'organizationId': organizationId,
        })
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .build();

    return io.io(AppConfig.websocketBaseUrl, options);
  }
}
