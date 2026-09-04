import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../network/api_client.dart';

class RealtimeService {
  StompClient? _client;

  void connectForCustomer({
    required String customerId,
    required void Function(Map<String, dynamic> event) onEvent,
  }) {
    _client = StompClient(
      config: StompConfig.sockJS(
        url: '${ApiClient.websocketBaseUrl}/ws-whitefox',
        onConnect: (_) {
          _client?.subscribe(
            destination: '/topic/customer/$customerId',
            callback: (frame) {
              if (frame.body == null) return;

              final data = jsonDecode(frame.body!);
              onEvent(Map<String, dynamic>.from(data));
            },
          );
        },
        onWebSocketError: (error) {
          print('Customer WebSocket error: $error');
        },
        onStompError: (frame) {
          print('Customer STOMP error: ${frame.body}');
        },
      ),
    );

    _client?.activate();
  }

  void disconnect() {
    _client?.deactivate();
  }
}
