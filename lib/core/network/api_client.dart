import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _defaultLocalBaseUrl =
      'https://whitefoxbackendpro.onrender.com';
  static const String _defaultProdBaseUrl =
      'https://whitefoxbackendpro.onrender.com';

  static const String baseUrl = String.fromEnvironment(
    'WHITEFOX_API_BASE_URL',
    defaultValue: _defaultLocalBaseUrl,
  );

  static const String websocketBaseUrl = String.fromEnvironment(
    'WHITEFOX_WS_BASE_URL',
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
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
      ),
    );
  }
}
