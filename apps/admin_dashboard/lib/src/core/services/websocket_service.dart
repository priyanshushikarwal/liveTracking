import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';
import '../network/dio_client.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

class WebSocketService {
  io.Socket connect({String? organizationId}) {
    print('[WebSocket] Initiating connection to ${AppConfig.websocketBaseUrl}');
    print('[WebSocket] Organization ID: $organizationId');
    print(
      '[WebSocket] Auth token available: ${dashboardAccessToken != null && dashboardAccessToken!.isNotEmpty}',
    );

    final token = dashboardAccessToken;
    final socket = io.io(
      AppConfig.websocketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1500)
          .setReconnectionDelayMax(8000)
          .setTimeout(10000)
          .setAuth({
            if (token != null && token.isNotEmpty) 'token': token,
            'actorType': 'admin',
            if (organizationId != null && organizationId.isNotEmpty)
              'organizationId': organizationId,
          })
          .setExtraHeaders({
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          })
          .build(),
    );

    socket.onConnect((_) {
      print('[WebSocket] Connected successfully');
      if (organizationId != null && organizationId.isNotEmpty) {
        print('[WebSocket] Subscribing to organization: $organizationId');
        socket.emit('dashboard:subscribe', organizationId);
      }
    });

    socket.onDisconnect((_) {
      print('[WebSocket] Disconnected');
    });

    socket.onConnectError((error) {
      print('[WebSocket] Connection error: $error');
    });

    socket.onError((error) {
      print('[WebSocket] Socket error: $error');
    });

    return socket;
  }
}
