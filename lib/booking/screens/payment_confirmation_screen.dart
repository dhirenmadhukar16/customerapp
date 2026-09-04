import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../navigation/customer_shell.dart';
import '../../cart/services/cart_service.dart';
import '../../profile/screens/customer_profile_screen.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final double grandTotal;

  const PaymentConfirmationScreen({
    super.key,
    required this.bookingData,
    required this.grandTotal,
  });

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  String _selectedDeliveryType = 'RIDER_DELIVERY';
  String _selectedPaymentMode = 'FULL_ONLINE';

  bool _loading = false;

  String? _bookingId;
  String? _merchantTransactionId;

  @override
  void dispose() {
    super.dispose();
  }

  // ============================================================
  // MAIN PAYMENT FLOW
  // ============================================================

  Future<void> _processBookingAndPayment() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final paymentProfile = await _loadPaymentProfile(
        fallbackName: widget.bookingData['firstName'] ??
            widget.bookingData['customerName'],
        fallbackEmail: widget.bookingData['email'],
        fallbackPhone: widget.bookingData['phone'] ??
            widget.bookingData['customerPhone'],
      );
      if (!_isPaymentProfileComplete(paymentProfile)) {
        if (mounted) setState(() => _loading = false);
        await _showCompleteProfileDialog();
        return;
      }

      // --------------------------------------------------------
      // 1. CREATE BOOKING
      // --------------------------------------------------------

      if (_bookingId == null) {
        final payload = Map<String, dynamic>.from(widget.bookingData);

        payload['deliveryType'] = _selectedDeliveryType;
        payload['paymentMode'] = _selectedPaymentMode;

        final bookingRes = await ApiClient.dio.post(
          '/api/customer-bookings',
          data: payload,
        );

        final data = bookingRes.data;

        _bookingId = data['id']?.toString();

        if (_bookingId == null || _bookingId!.isEmpty) {
          throw Exception(
            'Booking was created but booking ID was not returned.',
          );
        }
      }

      // --------------------------------------------------------
      // 2. CASH ON DELIVERY
      // --------------------------------------------------------

      if (_selectedPaymentMode == 'CASH_ON_DELIVERY') {
        if (mounted) {
          setState(() => _loading = false);
        }

        _showSuccessDialog();
        return;
      }

      // --------------------------------------------------------
      // 3. CALCULATE PAYMENT AMOUNT
      // --------------------------------------------------------

      final double amountToPay = _selectedPaymentMode == 'HALF_ADVANCE'
          ? widget.grandTotal / 2
          : widget.grandTotal;

      // --------------------------------------------------------
      // 4. CREATE EASEBUZZ PAYMENT
      // --------------------------------------------------------

      final idempotencyKey =
          'WF-${_bookingId}-${DateTime.now().millisecondsSinceEpoch}';

      final paymentResponse = await ApiClient.dio.post(
        '/api/payments/online/initiate',
        data: {
          'bookingId': _bookingId,
          'orderId': null,
          'amount': amountToPay,
          'paymentMode': _selectedPaymentMode,
          'idempotencyKey': idempotencyKey,

          // Customer information
          'firstName': paymentProfile['name'],
          'email': paymentProfile['email'],
          'phone': paymentProfile['phone'],

          'productInfo': 'WhiteFox Laundry Booking',

          // Address information if available
          'address1': widget.bookingData['address1'] ?? '',
          'address2': widget.bookingData['address2'] ?? '',
          'city': widget.bookingData['city'] ?? '',
          'state': widget.bookingData['state'] ?? '',
          'country': widget.bookingData['country'] ?? 'India',
          'zipcode': widget.bookingData['zipcode'] ??
              widget.bookingData['pincode'] ??
              '',

          'mobile': true,
        },
      );

      final data = Map<String, dynamic>.from(paymentResponse.data);

      // --------------------------------------------------------
      // 5. READ WHITEFOX PAYMENT RESPONSE
      // --------------------------------------------------------

      final status = data['status']?.toString().toUpperCase();

      final paymentUrl = data['paymentUrl']?.toString();

      final paymentToken = data['paymentToken']?.toString();

      _merchantTransactionId = data['merchantTransactionId']?.toString();

      debugPrint(
        'Easebuzz payment response: $data',
      );

      // --------------------------------------------------------
      // 6. PAYMENT URL
      // --------------------------------------------------------

      String? checkoutUrl = paymentUrl;

      /*
       * Some Easebuzz responses expose the checkout/access
       * value differently.
       *
       * Your backend should preferably return paymentUrl.
       *
       * We keep paymentToken as a fallback so the Flutter
       * application does not crash if the backend DTO returns
       * that field instead.
       */
      if ((checkoutUrl == null || checkoutUrl.isEmpty) &&
          paymentToken != null &&
          paymentToken.isNotEmpty) {
        checkoutUrl = paymentToken;
      }

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception(
          data['message']?.toString() ??
              'Easebuzz checkout URL was not returned.',
        );
      }

      if (status == 'FAILED') {
        throw Exception(
          data['message']?.toString() ?? 'Easebuzz payment initiation failed.',
        );
      }

      // --------------------------------------------------------
      // 7. OPEN EASEBUZZ HOSTED CHECKOUT
      // --------------------------------------------------------

      if (mounted) {
        setState(() => _loading = false);
      }

      await _openEasebuzzCheckout(checkoutUrl);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }

      if (_isProfileError(e)) {
        await _showCompleteProfileDialog();
      } else {
        _showError('Payment initiation failed. Please try again.');
      }
    }
  }

  // ============================================================
  // OPEN EASEBUZZ
  // ============================================================

  Future<void> _openEasebuzzCheckout(String checkoutUrl) async {
    final uri = Uri.tryParse(checkoutUrl);

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

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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

  Future<Map<String, String>> _loadPaymentProfile({
    dynamic fallbackName,
    dynamic fallbackEmail,
    dynamic fallbackPhone,
  }) async {
    final result = <String, String>{
      'name': fallbackName?.toString().trim() ?? '',
      'email': fallbackEmail?.toString().trim() ?? '',
      'phone': fallbackPhone?.toString().trim() ?? '',
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
        result['name'] = (profile['name'] ?? profile['customerName'] ?? result['name'])
            .toString()
            .trim();
        result['email'] = (profile['email'] ?? result['email']).toString().trim();
        result['phone'] = (profile['phone'] ?? result['phone']).toString().trim();
      }
    } catch (_) {
      // The supplied booking values remain available as a fallback.
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
        icon: const Icon(Icons.person_outline, color: AppTheme.primary, size: 48),
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
                MaterialPageRoute(builder: (_) => const CustomerProfileScreen()),
              );
            },
            child: const Text('Complete Profile'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUCCESS
  // ============================================================

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: const Icon(
          Icons.check_circle,
          color: AppTheme.primary,
          size: 60,
        ),
        title: const Text(
          'Booking Confirmed',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your pickup has been booked successfully.\n',
            ),
            Text(
              'Booking ID: ${_shortBookingId()}',
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                CartService.instance.clear();

                Navigator.pop(context);

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerShell(initialIndex: 3),
                  ),
                  (route) => false,
                );
              },
              child: const Text(
                'View My Orders',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortBookingId() {
    if (_bookingId == null) {
      return '-';
    }

    if (_bookingId!.length <= 8) {
      return _bookingId!.toUpperCase();
    }

    return _bookingId!.substring(0, 8).toUpperCase();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final double payAmount = _selectedPaymentMode == 'HALF_ADVANCE'
        ? widget.grandTotal / 2
        : widget.grandTotal;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Confirm & Pay',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _buildRadioOption(
              'RIDER_DELIVERY',
              'Rider Delivery',
              Icons.motorcycle,
              _selectedDeliveryType,
              (value) {
                if (value == null) return;

                setState(() {
                  _selectedDeliveryType = value;
                });
              },
            ),
            const SizedBox(height: 8),
            _buildRadioOption(
              'SELF_PICKUP',
              'Self Pickup (Store)',
              Icons.store,
              _selectedDeliveryType,
              (value) {
                if (value == null) return;

                setState(() {
                  _selectedDeliveryType = value;
                });
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Mode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _buildRadioOption(
              'FULL_ONLINE',
              'Pay Full Amount Online',
              Icons.credit_card,
              _selectedPaymentMode,
              (value) {
                if (value == null) return;

                setState(() {
                  _selectedPaymentMode = value;
                });
              },
            ),
            const SizedBox(height: 8),
            _buildRadioOption(
              'HALF_ADVANCE',
              'Pay 50% Advance Online',
              Icons.payments_outlined,
              _selectedPaymentMode,
              (value) {
                if (value == null) return;

                setState(() {
                  _selectedPaymentMode = value;
                });
              },
            ),
            const SizedBox(height: 8),
            _buildRadioOption(
              'CASH_ON_DELIVERY',
              'Cash on Delivery',
              Icons.money,
              _selectedPaymentMode,
              (value) {
                if (value == null) return;

                setState(() {
                  _selectedPaymentMode = value;
                });
              },
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Bill',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '₹${widget.grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'To Pay Now',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '₹${_selectedPaymentMode == 'CASH_ON_DELIVERY' ? '0.00' : payAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _loading ? null : _processBookingAndPayment,
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _selectedPaymentMode == 'CASH_ON_DELIVERY'
                            ? 'Confirm Booking'
                            : 'Pay & Confirm',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RADIO
  // ============================================================

  Widget _buildRadioOption(
    String value,
    String title,
    IconData icon,
    String groupValue,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: groupValue == value
              ? AppTheme.primary
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: _loading ? null : onChanged,
        title: Row(
          children: [
            Icon(
              icon,
              color: groupValue == value ? AppTheme.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight:
                    groupValue == value ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        activeColor: AppTheme.primary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
        ),
      ),
    );
  }
}
