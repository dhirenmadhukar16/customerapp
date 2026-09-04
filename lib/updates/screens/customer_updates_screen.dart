import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

class CustomerUpdatesScreen extends StatefulWidget {
  const CustomerUpdatesScreen({super.key});

  @override
  State<CustomerUpdatesScreen> createState() => _CustomerUpdatesScreenState();
}

class _CustomerUpdatesScreenState extends State<CustomerUpdatesScreen> {
  bool loading = true;
  String? error;
  List updates = [];

  String customerId = '';

  @override
  void initState() {
    super.initState();
    loadUpdates();
  }

  Future<void> loadUpdates() async {
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
        '/api/customer-updates/customers/$customerId',
      );

      setState(() {
        updates = response.data as List;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Tracking Updates',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(onPressed: loadUpdates, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: updates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final u = updates[index];

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.accent,
                      child: Icon(Icons.timeline, color: AppTheme.primary),
                    ),
                    title: Text(
                      u['title'] ?? 'Update',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${u['description'] ?? ''}\n${u['createdAt'] ?? ''}',
                    ),
                    trailing: Text(
                      u['updateType']?.toString() ?? '',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
