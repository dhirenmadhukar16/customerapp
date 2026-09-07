import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'customer_order_tracking_screen.dart';
import '../../core/realtime/realtime_service.dart';
import '../../payments/screens/customer_payment_screen.dart';

class CustomerOrdersScreen extends StatefulWidget {
  final int initialView;

  const CustomerOrdersScreen({
    super.key,
    this.initialView = 0,
  });

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  bool loading = true;
  String? error;
  Timer? refreshTimer;
  List bookings = [];
  List activeOrders = [];
  List recentOrders = [];
  final realtimeService = RealtimeService();
  String customerId = '';
  late int selectedView;

  @override
  void initState() {
    super.initState();
    selectedView = widget.initialView == 1 ? 1 : 0;
    initData();
  }

  Future<void> initData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      customerId = prefs.getString('userId') ?? '';

      if (customerId.isEmpty) {
        throw Exception('User not logged in or customer ID not found.');
      }

      realtimeService.connectForCustomer(
        customerId: customerId,
        onEvent: (event) {
          if (!mounted) return;
          loadAll();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(event['title'] ?? 'Order updated')),
          );
        },
      );
      await loadAll();
    } catch (e) {
      setState(() => error = e.toString());
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadAll() async {
    try {
      if (!mounted) return;
      setState(() {
        loading = true;
        error = null;
      });

      final dashRes = await ApiClient.dio.get(
        '/api/customer-app/customers/$customerId/dashboard',
      );

      final data = Map<String, dynamic>.from(dashRes.data);

      if (!mounted) return;
      setState(() {
        bookings = data['activeBookings'] ?? [];
        activeOrders = data['activeOrders'] ?? [];
        recentOrders = data['recentOrders'] ?? [];
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void openTracking(dynamic item, bool isBooking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerOrderTrackingScreen(
          data: Map<String, dynamic>.from(item),
          isBooking: isBooking,
        ),
      ),
    );
  }

  Color statusColor(String? status) {
    if (status == 'DELIVERED') return Colors.green;
    if (status == 'RIDER_ASSIGNED') return Colors.blue;
    if (status == 'RIDER_ON_THE_WAY') return Colors.orange;
    if (status == 'RIDER_REACHED') return Colors.deepOrange;
    if (status == 'PICKUP_BILL_CREATED') return Colors.purple;
    if (status == 'OUT_FOR_DELIVERY') return Colors.orange;
    if (status == 'CANCELLED') return Colors.red;
    if (status == 'REQUESTED') return AppTheme.primary;
    return AppTheme.primary;
  }

  bool isPastOrder(dynamic order) {
    final status = order['status']?.toString();
    return status == 'DELIVERED' || status == 'CANCELLED';
  }

  @override
  Widget build(BuildContext context) {
    final pastOrders = recentOrders.where(isPastOrder).toList();
    final activeItemsCount = bookings.length + activeOrders.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: loadAll,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadAll,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    children: [
                      _ordersOverview(activeItemsCount, pastOrders.length),
                      const SizedBox(height: 18),
                      _viewSelector(),
                      const SizedBox(height: 20),
                      _sectionTitle(
                        selectedView == 0 ? 'Active Orders' : 'Past Orders',
                      ),
                      const SizedBox(height: 12),
                      if (selectedView == 0)
                        activeItemsCount == 0
                            ? _emptyCard('No active orders',
                                'assets/images/empty_basket.png')
                            : Column(
                                children: [
                                  ...bookings.map((b) => _bookingCard(b)),
                                  ...activeOrders.map(
                                    (o) => _orderCard(o, active: true),
                                  ),
                                ],
                              )
                      else
                        pastOrders.isEmpty
                            ? _emptyCard('No past orders yet.',
                                'assets/images/empty_towels.png')
                            : Column(
                                children: pastOrders
                                    .map((o) => _orderCard(o, active: false))
                                    .toList(),
                              ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _ordersOverview(int activeCount, int pastCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F6B3A), Color(0xFF1A8C4E)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your garment journey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Track every pickup, care stage and delivery.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _overviewCount(activeCount, 'Active'),
          const SizedBox(width: 10),
          _overviewCount(pastCount, 'Past'),
        ],
      ),
    );
  }

  Widget _overviewCount(int count, String label) {
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _viewSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          _viewButton(0, 'Active', Icons.local_laundry_service_outlined),
          _viewButton(1, 'Past', Icons.history),
        ],
      ),
    );
  }

  Widget _viewButton(int index, String label, IconData icon) {
    final selected = selectedView == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedView = index),
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : AppTheme.mutedText),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.darkText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppTheme.darkText,
      ),
    );
  }

  Widget _emptyCard(String text, String imagePath) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
      ),
      child: Column(
        children: [
          Image.asset(imagePath, height: 100),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.mutedText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(dynamic b) {
    final status = b['status']?.toString() ?? 'REQUESTED';
    final bookingDate = b['createdAt'] ?? b['bookingDate'] ?? b['requestedAt'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.calendar_month,
                      color: statusColor(status), size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Pickup Booking',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 16),
            _row('Booked on', _formatDate(bookingDate)),
            _row('Pickup',
                '${b['pickupDate'] ?? '-'} • ${b['pickupTimeSlot'] ?? '-'}'),
            _row('Store', '${b['storeName'] ?? 'Not assigned'}'),
            const Divider(height: 24),
            Row(
              children: [
                const Text(
                  'Estimated',
                  style: TextStyle(
                      color: AppTheme.mutedText, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  _formatAmount(b['estimatedAmount'] ?? b['amount']),
                  style: const TextStyle(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => openTracking(b, true),
                icon: const Icon(Icons.track_changes, size: 20),
                label: const Text('Track Pickup'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(dynamic o, {required bool active}) {
    final status = o['status']?.toString() ?? '';
    final orderDate = o['orderDate'] ?? o['createdAt'] ?? o['placedAt'];
    final deliveryDate = o['deliveryDate'] ??
        o['expectedDeliveryDate'] ??
        o['dueDate'] ??
        o['deliveredAt'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: status == 'DELIVERED' ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'DELIVERED'
              ? Colors.green.shade400
              : Colors.black.withValues(alpha: 0.05),
          width: status == 'DELIVERED' ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    active ? Icons.local_laundry_service : Icons.receipt_long,
                    color: statusColor(status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    (o['orderNumber'] ?? 'Order').toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: status == 'DELIVERED'
                          ? Colors.green.shade900
                          : AppTheme.darkText,
                    ),
                  ),
                ),
                if (status == 'DELIVERED')
                  const Icon(Icons.check_circle, color: Colors.green, size: 20)
                else
                  _statusChip(status),
              ],
            ),
            const SizedBox(height: 16),
            _row('Order date', _formatDate(orderDate)),
            if (deliveryDate != null)
              _row(
                status == 'DELIVERED' ? 'Delivered' : 'Due date',
                _formatDate(deliveryDate),
              ),
            _row('Store', '${o['storeName'] ?? '-'}'),
            if (o['paymentStatus'] != null)
              _row(
                'Payment',
                o['paymentStatus'].toString().replaceAll('_', ' '),
              ),
            const Divider(height: 24),
            Row(
              children: [
                const Text(
                  'Amount',
                  style: TextStyle(
                      color: AppTheme.mutedText, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  _formatAmount(o['totalAmount'] ?? o['amount']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.darkText,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (active) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => openTracking(o, false),
                  icon: const Icon(Icons.track_changes, size: 20),
                  label: const Text('Track Order'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              if (o['paymentStatus'] == 'UNPAID' ||
                  o['paymentStatus'] == 'PARTIAL') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => openPayment(o),
                    icon: const Icon(Icons.payment, size: 20),
                    label: const Text('Pay Now'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ],
            ],
            if (!active && status == 'DELIVERED' && o['isRated'] != true) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _showRatingDialog(o),
                  icon: const Icon(Icons.star, size: 20),
                  label: const Text('Rate Your Experience'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(dynamic order) {
    int riderRating = 5;
    int storeRating = 5;
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Rate Your Experience',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Store Rating',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          onPressed: () =>
                              setDialogState(() => storeRating = index + 1),
                          icon: Icon(
                            index < storeRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.orange,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    const Text('Rider Rating',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          onPressed: () =>
                              setDialogState(() => riderRating = index + 1),
                          icon: Icon(
                            index < riderRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.orange,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: feedbackController,
                      decoration: const InputDecoration(
                        labelText: 'Feedback (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _submitRating(order, storeRating, riderRating,
                        feedbackController.text);
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitRating(
      dynamic order, int storeR, int riderR, String feedback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('userId');

      await ApiClient.dio.post('/api/customer-reviews', data: {
        'customerId': customerId,
        'orderId': order['id'] ?? order['orderId'],
        'storeId': order['storeId'],
        'riderId': order['deliveryRiderId'],
        'storeRating': storeR,
        'riderRating': riderR,
        'overallRating': (storeR + riderR) ~/ 2,
        'feedback': feedback,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rating submitted successfully!')));
        loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit rating: $e')));
      }
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                  color: AppTheme.mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '-';

    final raw = value.toString().trim();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = parsed.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  Widget _statusChip(String status) {
    final text =
        status == 'REQUESTED' ? 'Created' : status.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor(status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: statusColor(status),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> openPayment(dynamic o) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerPaymentScreen(
          orderId: o['id']?.toString() ?? o['orderId']?.toString() ?? '',
          orderNumber: o['orderNumber']?.toString() ?? 'Order',
          totalAmount: (o['totalAmount'] ?? 0).toDouble(),
        ),
      ),
    );
    if (result == true) {
      loadAll();
    }
  }
}
