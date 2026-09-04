import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../navigation/customer_shell.dart';
import '../../cart/services/cart_service.dart';
import 'payment_confirmation_screen.dart';

class BookPickupScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedItems;

  const BookPickupScreen({super.key, this.selectedItems = const []});

  @override
  State<BookPickupScreen> createState() => _BookPickupScreenState();
}

class _BookPickupScreenState extends State<BookPickupScreen> {
  final pickupAddressController = TextEditingController();
  final flatNoController = TextEditingController();
  final landmarkController = TextEditingController();
  final instructionsController = TextEditingController();

  List<dynamic> savedAddresses = [];
  Map<String, dynamic>? selectedAddressObj;

  bool loading = false;

  late DateTime selectedDate;
  late String selectedSlot;
  late List<String> currentSlots;

  bool isExpressDelivery = false;
  bool useLoyaltyPoints = false;
  int availableLoyaltyPoints = 0;

  @override
  void initState() {
    super.initState();
    _initializeDateAndSlots();
    _loadSavedAddress();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('userId');
      if (customerId != null) {
        final response = await ApiClient.dio
            .get('/api/customer-app/customers/$customerId/profile');
        setState(() {
          availableLoyaltyPoints =
              (response.data['loyaltyPoints'] ?? 0).toInt();
        });
      }
    } catch (e) {}
  }

  void _initializeDateAndSlots() {
    DateTime now = DateTime.now();
    if (now.hour >= 17) {
      selectedDate = now.add(const Duration(days: 1));
    } else {
      selectedDate = now;
    }
    currentSlots = _getSlotsForDate(selectedDate);
    if (currentSlots.isNotEmpty) {
      selectedSlot = currentSlots.first;
    } else {
      selectedDate = now.add(const Duration(days: 1));
      currentSlots = _getSlotsForDate(selectedDate);
      selectedSlot = currentSlots.isNotEmpty ? currentSlots.first : '';
    }
  }

  List<String> _getSlotsForDate(DateTime date) {
    DateTime now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      int currentHour = now.hour;
      List<String> valid = [];
      if (currentHour < 9) valid.add('9:00 AM - 11:00 AM');
      if (currentHour < 11) valid.add('11:00 AM - 1:00 PM');
      if (currentHour < 13) valid.add('1:00 PM - 3:00 PM');
      if (currentHour < 15) valid.add('3:00 PM - 5:00 PM');
      if (currentHour < 17) valid.add('5:00 PM - 7:00 PM');
      return valid;
    }
    return [
      '9:00 AM - 11:00 AM',
      '11:00 AM - 1:00 PM',
      '1:00 PM - 3:00 PM',
      '3:00 PM - 5:00 PM',
      '5:00 PM - 7:00 PM',
    ];
  }

  double get subtotal {
    double total = 0;
    for (final item in widget.selectedItems) {
      final price = (item['price'] ?? 0).toDouble();
      final qty = item['quantity'] ?? 0;
      total += price * qty;
    }
    return total;
  }

  double get gst => subtotal * 0.18;
  // Express delivery carries a 100% surcharge on the service subtotal.
  double get urgentFee => isExpressDelivery ? subtotal * 1.00 : 0.0;
  double get loyaltyDiscount =>
      useLoyaltyPoints ? availableLoyaltyPoints * 0.10 : 0.0;

  double get grandTotal {
    double total = subtotal + gst + urgentFee - loyaltyDiscount;
    return total < 0 ? 0 : total;
  }

  Future<void> bookPickup() async {
    if (selectedAddressObj == null && flatNoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter flat/house no. or select an address')),
      );
      return;
    }

    if (widget.selectedItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }

    try {
      setState(() => loading = true);

      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('userId') ?? '';
      final storeId = prefs.getString('customer_store_id') ?? '';

      if (customerId.isEmpty) {
        throw Exception('User not logged in or customer ID not found.');
      }
      if (storeId.isEmpty) {
        throw Exception(
            'No store selected. Please update your location on the home screen.');
      }

      String finalAddress = '';
      if (selectedAddressObj != null) {
        finalAddress =
            '${selectedAddressObj!['addressLine']}, ${selectedAddressObj!['landmark']}, ${selectedAddressObj!['city']}';
      } else {
        // Save new address
        final newAddrRes = await ApiClient.dio.post(
          '/api/customer-addresses',
          data: {
            'customerId': customerId,
            'label': 'Home',
            'addressLine':
                '${flatNoController.text.trim()}, ${pickupAddressController.text.trim()}',
            'landmark': landmarkController.text.trim(),
            'city': '',
            'state': '',
            'pincode': '',
            'latitude': prefs.getDouble('customer_lat'),
            'longitude': prefs.getDouble('customer_lng'),
            'defaultAddress': savedAddresses.isEmpty,
          },
        );
        finalAddress =
            '${flatNoController.text.trim()}, ${pickupAddressController.text.trim()}';
        if (landmarkController.text.trim().isNotEmpty) {
          finalAddress += ', Landmark: ${landmarkController.text.trim()}';
        }
      }

      final payload = {
        'customerId': customerId,
        'storeId': storeId,
        'pickupAddress': finalAddress,
        'pickupDate': selectedDate.toIso8601String().substring(0, 10),
        'pickupTimeSlot': selectedSlot,
        'specialInstructions': instructionsController.text.trim(),
        'isUrgent': isExpressDelivery,
        'urgentFee': urgentFee,
        'loyaltyPointsToUse': useLoyaltyPoints ? availableLoyaltyPoints : 0,
        'items': widget.selectedItems
            .map((i) => {
                  'catalogId': i['catalogId'],
                  'variantName': i['variantName'],
                  'quantity': i['quantity'],
                })
            .toList(),
      };

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentConfirmationScreen(
              bookingData: payload,
              grandTotal: grandTotal,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadSavedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final addr = prefs.getString('customer_address');
    final customerId = prefs.getString('userId');

    if (addr != null && addr.isNotEmpty) {
      setState(() {
        pickupAddressController.text = addr;
      });
    }

    if (customerId != null && customerId.isNotEmpty) {
      try {
        final res = await ApiClient.dio
            .get('/api/customer-addresses/customer/$customerId');
        final List addrs = res.data;
        if (addrs.isNotEmpty) {
          final def = addrs.firstWhere((a) => a['defaultAddress'] == true,
              orElse: () => addrs.first);
          setState(() {
            savedAddresses = addrs;
            selectedAddressObj = def;
          });
        }
      } catch (e) {
        // ignore
      }
    }
  }

  Future<void> pickDate() async {
    DateTime now = DateTime.now();
    DateTime first = now.hour >= 17 ? now.add(const Duration(days: 1)) : now;

    final date = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: now.add(const Duration(days: 30)),
      initialDate: selectedDate.isBefore(first) ? first : selectedDate,
    );

    if (date != null) {
      setState(() {
        selectedDate = date;
        currentSlots = _getSlotsForDate(date);
        selectedSlot = currentSlots.isNotEmpty ? currentSlots.first : '';
      });
    }
  }

  String getItemImage(String itemName) {
    final lower = itemName.toLowerCase();
    if (lower.contains('t-shirt')) return 'assets/images/item_tshirt.png';
    if (lower.contains('shirt')) return 'assets/images/item_shirt.png';
    if (lower.contains('trouser')) return 'assets/images/item_trousers.png';
    if (lower.contains('blazer')) return 'assets/images/item_blazer.png';
    if (lower.contains('jacket')) return 'assets/images/item_jacket.png';
    return 'assets/images/item_shirt.png';
  }

  @override
  void dispose() {
    pickupAddressController.dispose();
    instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Pickup Details',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Pickup Address'),
                  const SizedBox(height: 12),
                  if (savedAddresses.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Selected Address',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              TextButton(
                                onPressed: () {
                                  // Open a modal to select another address or add new
                                  // For simplicity, we just clear selectedAddressObj to allow manual entry
                                  setState(() {
                                    selectedAddressObj = null;
                                    savedAddresses
                                        .clear(); // Force manual entry for now
                                  });
                                },
                                child: const Text('Change'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (selectedAddressObj != null)
                            Text(
                              '${selectedAddressObj!['addressLine']}, ${selectedAddressObj!['landmark']}, ${selectedAddressObj!['city']}',
                              style: const TextStyle(color: AppTheme.mutedText),
                            ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        TextField(
                          controller: pickupAddressController,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Main Area (Detected)',
                            prefixIcon: const Icon(Icons.location_on,
                                color: AppTheme.primary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.02),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: flatNoController,
                          decoration: InputDecoration(
                            labelText: 'Flat / House No. / Floor / Building',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: landmarkController,
                          decoration: InputDecoration(
                            labelText: 'Nearby Landmark (Optional)',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  _sectionTitle('Pickup Schedule'),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Pickup Date',
                        prefixIcon: const Icon(Icons.calendar_month,
                            color: AppTheme.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Colors.black.withValues(alpha: 0.05)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Colors.black.withValues(alpha: 0.05)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      child: Text(
                        selectedDate.toIso8601String().substring(0, 10),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSlot,
                    decoration: InputDecoration(
                      labelText: 'Pickup Time Slot',
                      prefixIcon: const Icon(Icons.access_time,
                          color: AppTheme.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.05)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.05)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: currentSlots
                        .map((slot) => DropdownMenuItem(
                            value: slot,
                            child: Text(slot,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedSlot = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Special Instructions'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: instructionsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Example: call before pickup',
                      hintStyle: const TextStyle(color: AppTheme.mutedText),
                      prefixIcon: const Icon(Icons.note_alt_outlined,
                          color: AppTheme.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.05)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.05)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _sectionTitle('Items Summary'),
                  const SizedBox(height: 12),
                  ...widget.selectedItems.map((item) {
                    final price = (item['price'] ?? 0).toDouble();
                    final qty = item['quantity'] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: AssetImage(
                                      getItemImage(item['itemName'] ?? '')),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['itemName'] ?? 'Item',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item['serviceType'] ?? ''} x $qty',
                                    style: const TextStyle(
                                        color: AppTheme.mutedText,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${(price * qty).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppTheme.darkText,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 30),
                  _sectionTitle('Delivery & Loyalty'),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Express Delivery',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle:
                        const Text('Priority next-day delivery for a 100% service surcharge'),
                    value: isExpressDelivery,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (val) => setState(() => isExpressDelivery = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Use Loyalty Points',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Available: $availableLoyaltyPoints (₹${(availableLoyaltyPoints * 0.10).toStringAsFixed(2)} discount)'),
                    value: useLoyaltyPoints,
                    activeThumbColor: AppTheme.primary,
                    onChanged: availableLoyaltyPoints > 0
                        ? (val) => setState(() => useLoyaltyPoints = val)
                        : null,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                _billRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}'),
                if (isExpressDelivery)
                  _billRow(
                      'Express Fee (100%)', '₹${urgentFee.toStringAsFixed(2)}'),
                _billRow('GST 18%', '₹${gst.toStringAsFixed(2)}'),
                if (useLoyaltyPoints)
                  _billRow('Loyalty Discount',
                      '- ₹${loyaltyDiscount.toStringAsFixed(2)}',
                      color: Colors.green),
                const Divider(height: 24),
                _billRow(
                  'Grand Total',
                  '₹${grandTotal.toStringAsFixed(2)}',
                  bold: true,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.blue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: const Text(
                          'Note: This is an estimated price. The final price depends on cloth quality and will be confirmed by the pickup agent.',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: loading ? null : bookPickup,
                    child: loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.darkText),
    );
  }

  Widget _billRow(String title, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: bold ? AppTheme.darkText : (color ?? AppTheme.mutedText),
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: bold ? AppTheme.primary : (color ?? AppTheme.darkText),
              fontSize: bold ? 18 : 14,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                  color: AppTheme.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: bold ? AppTheme.primary : AppTheme.darkText,
                fontSize: bold ? 16 : 13,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
