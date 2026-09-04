import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/screens/customer_login_screen.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'navigation/customer_shell.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await ApiClient.init();

    final prefs = await SharedPreferences.getInstance();
    final hasToken = prefs.getString('token') != null;

    runApp(WhiteFoxCustomerApp(isLoggedIn: hasToken));
  } catch (e) {
    runApp(WhiteFoxCustomerApp(isLoggedIn: false));
  }
}

class WhiteFoxCustomerApp extends StatelessWidget {
  final bool isLoggedIn;
  const WhiteFoxCustomerApp({super.key, required this.isLoggedIn});

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
