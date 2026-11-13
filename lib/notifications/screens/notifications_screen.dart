import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('userId') ?? prefs.getString('userId');

      if (id == null) {
        throw Exception('User ID not found');
      }

      final res =
          await ApiClient.dio.get('/api/notifications/receiver/CUSTOMER/$id');
      final List data = res.data ?? [];

      data.sort((a, b) {
        final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      setState(() {
        _notifications = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await ApiClient.dio.patch('/api/notifications/$id/read');
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == id);
        if (index != -1) {
          _notifications[index]['isRead'] = true;
        }
      });
    } catch (e) {
      // Ignore
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    return DateFormat('MMM d, h:mm a').format(date);
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'ORDER':
        return Icons.local_laundry_service;
      case 'PAYMENT':
        return Icons.payment;
      case 'SYSTEM':
        return Icons.info_outline;
      case 'RIDER':
        return Icons.delivery_dining;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)))
              : _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 80,
                              color: AppTheme.mutedText.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text('No notifications yet',
                              style: TextStyle(
                                  color: AppTheme.mutedText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notif = _notifications[index];
                          final isRead = notif['isRead'] == true;

                          return GestureDetector(
                            onTap: () {
                              if (!isRead) _markAsRead(notif['id']);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isRead
                                    ? Colors.white
                                    : AppTheme.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: isRead
                                    ? Border.all(
                                        color: Colors.black
                                            .withValues(alpha: 0.05))
                                    : Border.all(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isRead
                                          ? AppTheme.background
                                          : AppTheme.primary
                                              .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                        _getIconForType(
                                            notif['notificationType']),
                                        color: isRead
                                            ? AppTheme.mutedText
                                            : AppTheme.primary,
                                        size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notif['title'] ??
                                                    'Notification',
                                                style: TextStyle(
                                                  fontWeight: isRead
                                                      ? FontWeight.w600
                                                      : FontWeight.bold,
                                                  fontSize: 15,
                                                  color: isRead
                                                      ? AppTheme.darkText
                                                      : AppTheme.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatDate(notif['createdAt']),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isRead
                                                    ? AppTheme.mutedText
                                                    : AppTheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          notif['message'] ?? '',
                                          style: TextStyle(
                                            color: isRead
                                                ? AppTheme.mutedText
                                                : AppTheme.darkText
                                                    .withValues(alpha: 0.8),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
