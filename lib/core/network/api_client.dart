import 'package:dio/dio.dart';

import '../security/secure_token_storage.dart';

class ApiClient {
  static const String _defaultLocalBaseUrl = 'https://103.209.145.200';
  static const String _defaultProdBaseUrl = 'https://103.209.145.200';

  static const String baseUrl = String.fromEnvironment(
    'https://103.209.145.200',
    defaultValue: _defaultLocalBaseUrl,
  );

  static const String websocketBaseUrl = String.fromEnvironment(
    'https://103.209.145.200',
    defaultValue: baseUrl,
  );

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static Future<void> init() async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureTokenStorage.readToken();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
      ),
    );
  }
}
