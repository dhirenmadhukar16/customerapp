import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../auth/screens/customer_login_screen.dart';
import 'edit_profile_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool loading = true;
  String? error;

  Map<String, dynamic> profile = {};
  String customerId = '';
  String selectedAvatar = 'assets/images/avatar_boy_1.png';

  final List<String> avatars = [
    'assets/images/avatar_boy_1.png',
    'assets/images/avatar_boy_2.png',
    'assets/images/avatar_boy_3.png',
    'assets/images/avatar_girl_1.png',
    'assets/images/avatar_girl_2.png',
    'assets/images/avatar_girl_3.png',
  ];

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      customerId = prefs.getString('userId') ?? '';

      if (customerId.isEmpty) {
        throw Exception('User not logged in or customer ID not found.');
      }

      final response = await ApiClient.dio.get(
        '/api/customer-app/customers/$customerId/profile',
      );

      setState(() {
        profile = Map<String, dynamic>.from(response.data);
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showAvatarSelectionDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Your Avatar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: avatars.map((avatar) {
                  final isSelected = selectedAvatar == avatar;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedAvatar = avatar;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: const Color(0xFFF1F5F9),
                        backgroundImage: AssetImage(avatar),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    customerId: customerId,
                    currentProfile: profile,
                  ),
                ),
              );
              if (result == true) {
                loadProfile();
              }
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(onPressed: loadProfile, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child:
                      Text(error!, style: const TextStyle(color: Colors.red)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: const Color(0xFFE2E8F0),
                                backgroundImage: AssetImage(selectedAvatar),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _showAvatarSelectionDialog,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 3),
                                  ),
                                  child: const Icon(Icons.edit,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        profile['name'] ??
                            profile['customerName'] ??
                            'Customer',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile['phone'] ?? '',
                        style: const TextStyle(
                          color: AppTheme.mutedText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _tile(Icons.email_outlined, 'Email',
                                profile['email'] ?? '-'),
                            const Divider(height: 1, indent: 60),
                            _tile(Icons.phone_outlined, 'Phone',
                                profile['phone'] ?? '-'),
                            const Divider(height: 1, indent: 60),
                            _tile(Icons.wechat_outlined, 'WhatsApp',
                                profile['whatsappNumber'] ?? '-'),
                            const Divider(height: 1, indent: 60),
                            _tile(Icons.badge_outlined, 'Customer ID',
                                customerId.substring(0, 8).toUpperCase()),
                            const Divider(height: 1, indent: 60),
                            _tile(Icons.loyalty_outlined, 'Loyalty Points',
                                profile['loyaltyPoints']?.toString() ?? '0'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CustomerLoginScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text('Log Out',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _tile(IconData icon, String title, String value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(
            color: AppTheme.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
            color: AppTheme.darkText,
            fontSize: 15,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}
