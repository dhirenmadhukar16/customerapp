import 'package:flutter/material.dart';

import 'auth/screens/customer_login_screen.dart';
import 'core/network/api_client.dart';
import 'core/security/secure_token_storage.dart';
import 'core/theme/app_theme.dart';
import 'navigation/customer_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isLoggedIn = false;

  try {
    await ApiClient.init();

    // Read from the same secure storage used after OTP verification.
    final token = await SecureTokenStorage.readToken();

    isLoggedIn = token != null && token.trim().isNotEmpty;
  } catch (error) {
    isLoggedIn = false;
  }

  runApp(
    WhiteFoxCustomerApp(
      isLoggedIn: isLoggedIn,
    ),
  );
}

class WhiteFoxCustomerApp extends StatelessWidget {
  final bool isLoggedIn;

  const WhiteFoxCustomerApp({
    super.key,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhiteFox Customer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: isLoggedIn ? const CustomerShell() : const CustomerLoginScreen(),
    );
  }
}
