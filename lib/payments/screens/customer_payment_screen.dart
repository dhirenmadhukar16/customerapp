import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../profile/screens/customer_profile_screen.dart';

class CustomerPaymentScreen extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final double totalAmount;
  final String? customerPhone;
  final String? customerEmail;

  const CustomerPaymentScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.totalAmount,
    this.customerPhone,
    this.customerEmail,
  });

  @override
  State<CustomerPaymentScreen> createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen> {
  bool loading = false;

  String selectedMode = 'CASH_ON_DELIVERY';

  String? merchantTransactionId;

  double get payableAmount {
    if (selectedMode == 'HALF_ADVANCE') {
      return widget.totalAmount / 2;
    }

    return widget.totalAmount;
  }

  // ============================================================
  // CREATE PAYMENT
  // ============================================================

  Future<void> createPayment() async {
    if (loading) return;

    if (selectedMode == 'CASH_ON_DELIVERY') {
      await saveCodPaymentOption();
    } else {
      await startEasebuzzPayment();
    }
  }

  // ============================================================
  // COD
  // ============================================================

  Future<void> saveCodPaymentOption() async {
    try {
      setState(() => loading = true);

      await ApiClient.dio.patch(
        '/api/payments/orders/${widget.orderId}/cod',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('COD selected successfully'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  // ============================================================
  // EASEBUZZ
  // ============================================================

  Future<void> startEasebuzzPayment() async {
    try {
      setState(() => loading = true);

      final paymentProfile = await _loadPaymentProfile();
      if (!_isPaymentProfileComplete(paymentProfile)) {
        if (mounted) setState(() => loading = false);
        await _showCompleteProfileDialog();
        return;
      }

      final idempotencyKey =
          'WF-ORDER-${widget.orderId}-${DateTime.now().millisecondsSinceEpoch}';

      final response = await ApiClient.dio.post(
        '/api/payments/online/initiate',
        data: {
          'orderId': widget.orderId,
          'bookingId': null,
          'amount': payableAmount,
          'paymentMode': selectedMode,
          'idempotencyKey': idempotencyKey,
          'firstName': paymentProfile['name'],
          'email': paymentProfile['email'],
          'phone': paymentProfile['phone'],
          // 'email': 'dhiran.madhukar@gmail.com',
// 'phone': '9587581686',
          'productInfo': 'WhiteFox Order ${widget.orderNumber}',
          'country': 'India',
          'mobile': true,
        },
      );

      final data = Map<String, dynamic>.from(
        response.data,
      );

      debugPrint(
        'Easebuzz order payment response: $data',
      );

      // --------------------------------------------------------
      // PAYMENT STATUS
      // --------------------------------------------------------

      final status = data['status']?.toString().toUpperCase();

      // --------------------------------------------------------
      // TRANSACTION ID
      // --------------------------------------------------------

      merchantTransactionId = data['merchantTransactionId']?.toString();

      // --------------------------------------------------------
      // CHECKOUT URL
      // --------------------------------------------------------

      String? paymentUrl = data['paymentUrl']?.toString();

      /*
       * Fallback in case your backend returns the
       * payment token/access value.
       */
      if ((paymentUrl == null || paymentUrl.isEmpty) &&
          data['paymentToken'] != null) {
        paymentUrl = data['paymentToken'].toString();
      }

      if (status == 'FAILED') {
        throw Exception(
          data['message']?.toString() ?? 'Easebuzz payment initiation failed.',
        );
      }

      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw Exception(
          data['message']?.toString() ??
              'Easebuzz checkout URL was not returned.',
        );
      }

      // --------------------------------------------------------
      // STOP LOADING BEFORE LEAVING APP
      // --------------------------------------------------------

      if (mounted) {
        setState(() => loading = false);
      }

      // --------------------------------------------------------
      // OPEN EASEBUZZ
      // --------------------------------------------------------

      await openEasebuzzCheckout(
        paymentUrl,
      );
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
      }

      if (_isProfileError(e)) {
        await _showCompleteProfileDialog();
      } else {
        showError('Payment initiation failed. Please try again.');
      }
    }
  }

  // ============================================================
  // OPEN EASEBUZZ CHECKOUT
  // ============================================================

  Future<void> openEasebuzzCheckout(String paymentUrl) async {
    final uri = Uri.tryParse(paymentUrl);

    if (uri == null) {
      throw Exception(
        'Invalid Easebuzz checkout URL.',
      );
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      throw Exception(
        'Unable to open Easebuzz payment page.',
      );
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void showError(Object e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toString(),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  bool _isProfileError(Object error) {
    final message = _errorText(error).toLowerCase();
    return message.contains('email') ||
        message.contains('phone') ||
        message.contains('customer information') ||
        message.contains('complete your profile') ||
        message.contains('parameter is required');
  }

  Future<Map<String, String>> _loadPaymentProfile() async {
    final result = <String, String>{
      'name': 'WhiteFox Customer',
      'email': widget.customerEmail?.trim() ?? '',
      'phone': widget.customerPhone?.trim() ?? '',
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('userId');
      if (customerId == null || customerId.isEmpty) return result;
      final response = await ApiClient.dio.get(
        '/api/customer-app/customers/$customerId/profile',
      );
      if (response.data is Map) {
        final profile = response.data as Map;
        result['name'] =
            (profile['name'] ?? profile['customerName'] ?? result['name'])
                .toString()
                .trim();
        result['email'] =
            (profile['email'] ?? result['email']).toString().trim();
        result['phone'] =
            (profile['phone'] ?? result['phone']).toString().trim();
      }
    } catch (_) {
      // Widget values remain available as a fallback.
    }
    return result;
  }

  bool _isPaymentProfileComplete(Map<String, String> profile) {
    final email = profile['email'] ?? '';
    final phone = (profile['phone'] ?? '').replaceAll(RegExp(r'\D'), '');
    return (profile['name'] ?? '').isNotEmpty &&
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) &&
        phone.length >= 10;
  }

  String _errorText(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        return '${data['message'] ?? ''} ${data['error'] ?? ''} ${data['detail'] ?? ''}';
      }
      if (data != null) return data.toString();
    }
    return error.toString();
  }

  Future<void> _showCompleteProfileDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon:
            const Icon(Icons.person_outline, color: AppTheme.primary, size: 48),
        title: const Text('Complete your profile'),
        content: const Text(
          'Please complete your name, email address and phone number for seamless services and secure payments from WhiteFox.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CustomerProfileScreen()),
              );
            },
            child: const Text('Complete Profile'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT OPTION
  // ============================================================

  Widget paymentOption(
    String value,
    String title,
    String subtitle,
  ) {
    return Card(
      child: RadioListTile<String>(
        value: value,
        groupValue: selectedMode,
        onChanged: loading
            ? null
            : (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  selectedMode = value;
                });
              },
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final payableNow = selectedMode == 'CASH_ON_DELIVERY' ? 0.0 : payableAmount;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: ListTile(
              title: Text(
                widget.orderNumber,
              ),
              subtitle: const Text(
                'Choose payment option',
              ),
              trailing: Text(
                '₹${widget.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          paymentOption(
            'FULL_ONLINE',
            'Pay Full Online',
            'Pay full amount using UPI / card / net banking.',
          ),
          paymentOption(
            'HALF_ADVANCE',
            'Pay 50% Advance',
            'Pay half now and remaining at delivery.',
          ),
          paymentOption(
            'CASH_ON_DELIVERY',
            'Cash On Delivery',
            'Rider will collect payment at delivery.',
          ),
          const SizedBox(
            height: 20,
          ),
          Card(
            child: ListTile(
              title: const Text(
                'Payable Now',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              trailing: Text(
                '₹${payableNow.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: loading ? null : createPayment,
              child: loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      selectedMode == 'CASH_ON_DELIVERY'
                          ? 'Confirm COD'
                          : 'Pay Now',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
