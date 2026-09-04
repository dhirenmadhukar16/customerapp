import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';

class EditProfileScreen extends StatefulWidget {
  final String customerId;
  final Map<String, dynamic> currentProfile;

  const EditProfileScreen({super.key, required this.customerId, required this.currentProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController whatsappController;
  late TextEditingController addressController;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.currentProfile['name'] ?? widget.currentProfile['customerName'] ?? '');
    emailController = TextEditingController(text: widget.currentProfile['email'] ?? '');
    phoneController = TextEditingController(text: widget.currentProfile['phone'] ?? '');
    whatsappController = TextEditingController(text: widget.currentProfile['whatsappNumber'] ?? '');
    addressController = TextEditingController(text: widget.currentProfile['address'] ?? '');
  }

  void saveProfile() async {
    setState(() => loading = true);
    try {
      await ApiClient.dio.put(
        '/api/customers/${widget.customerId}',
        data: {
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
          'whatsappNumber': whatsappController.text.trim(),
          'address': addressController.text.trim(),
        },
      );
      if (mounted) {
        Navigator.pop(context, true); // true indicates success
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to update profile';
        if (e is DioException && e.response != null) {
          final errData = e.response?.data;
          if (errData is Map && errData['message'] != null) {
            msg = errData['message'];
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _field('Full Name', nameController),
            const SizedBox(height: 16),
            _field('Email', emailController, TextInputType.emailAddress),
            const SizedBox(height: 16),
            _field('Phone Number', phoneController, TextInputType.phone),
            const SizedBox(height: 16),
            _field('WhatsApp Number', whatsappController, TextInputType.phone),
            const SizedBox(height: 16),
            _field('Address', addressController),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: loading ? null : saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SAVE PROFILE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, [TextInputType keyboardType = TextInputType.text]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkText)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
