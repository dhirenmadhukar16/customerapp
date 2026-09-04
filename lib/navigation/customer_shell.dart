import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../home/screens/home_dashboard_screen.dart';
import '../services/screens/services_screen.dart';
import '../cart/screens/cart_screen.dart';
import '../orders/screens/customer_orders_screen.dart';
import '../profile/screens/customer_profile_screen.dart';
import '../reprocessing/screens/reprocessing_list_screen.dart';
import '../core/realtime/realtime_service.dart';
import '../orders/screens/pickup_bill_approval_screen.dart';

class CustomerShell extends StatefulWidget {
  final int initialIndex;

  const CustomerShell({super.key, this.initialIndex = 0});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  late int selectedIndex;
  late String customerId;
  final RealtimeService _realtimeService = RealtimeService();

  late final List<Widget> pages;

  final items = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.local_laundry_service_outlined),
      activeIcon: Icon(Icons.local_laundry_service),
      label: 'Services',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.shopping_cart_outlined),
      activeIcon: Icon(Icons.shopping_cart),
      label: 'Cart',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.receipt_long_outlined),
      activeIcon: Icon(Icons.receipt_long),
      label: 'Orders',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.note_outlined),
      activeIcon: Icon(Icons.note),
      label: 'Reprocessing',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    _loadCustomerId();
  }

  Future<void> _loadCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    customerId = prefs.getString('userId') ?? '';

    // Initialize pages with customerId
    pages = [
      const HomeDashboardScreen(),
      const ServicesScreen(),
      const CartScreen(),
      const CustomerOrdersScreen(),
      ReprocessingListScreen(customerId: customerId),
      const CustomerProfileScreen(),
    ];

    if (mounted) {
      setState(() {});
      _setupRealtime();
    }
  }

  Future<void> _setupRealtime() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('userId');
    if (customerId != null) {
      _realtimeService.connectForCustomer(
        customerId: customerId,
        onEvent: (event) {
          if (event['type'] == 'PICKUP_BILL_AWAITING_APPROVAL') {
            final billId = event['referenceId'];
            if (billId != null && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PickupBillApprovalScreen(pickupBillId: billId),
                ),
              );
            }
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _realtimeService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages.isNotEmpty
          ? pages[selectedIndex]
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) async {
          if (index == 2 || index == 3) {
            final prefs = await SharedPreferences.getInstance();
            final storeId = prefs.getString('customer_store_id');
            if (storeId == null || storeId.isEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'No store available near your location. Please change location.')),
                );
              }
              return;
            }
          }
          setState(() => selectedIndex = index);
        },
        items: items,
      ),
    );
  }
}
