// Example Integration File
// This file shows how to integrate the Reprocessing module into your app

import 'package:flutter/material.dart';
import 'screens/reprocessing_list_screen.dart';
import 'models/reprocessing.dart';
import 'services/reprocessing_service.dart';

// ============================================================================
// EXAMPLE 1: Adding Reprocessing to Navigation Shell
// ============================================================================
// In your customer_shell.dart or main navigation file, add:

class NavigationExample extends StatefulWidget {
  final String customerId;

  const NavigationExample({
    super.key,
    required this.customerId,
  });

  @override
  State<NavigationExample> createState() => _NavigationExampleState();
}

class _NavigationExampleState extends State<NavigationExample> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.shopping_bag), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.note), label: 'Reprocessing'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const Center(child: Text('Home Screen'));
      case 1:
        return const Center(child: Text('Orders Screen'));
      case 2:
        // Navigate to reprocessing list
        return ReprocessingListScreen(customerId: widget.customerId);
      case 3:
        return const Center(child: Text('Profile Screen'));
      default:
        return const Center(child: Text('Home Screen'));
    }
  }
}

// ============================================================================
// EXAMPLE 2: Navigate to Reprocessing from Another Screen
// ============================================================================

class OrderDetailsScreenExample extends StatelessWidget {
  final String customerId;
  final String orderId;

  const OrderDetailsScreenExample({
    super.key,
    required this.customerId,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Navigate to reprocessing for this customer
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReprocessingListScreen(
                  customerId: customerId,
                ),
              ),
            );
          },
          child: const Text('View My Reprocessing Requests'),
        ),
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 3: Display Reprocessing Summary Widget
// ============================================================================

class ReprocessingSummaryWidget extends StatefulWidget {
  final String customerId;

  const ReprocessingSummaryWidget({
    super.key,
    required this.customerId,
  });

  @override
  State<ReprocessingSummaryWidget> createState() =>
      _ReprocessingSummaryWidgetState();
}

class _ReprocessingSummaryWidgetState extends State<ReprocessingSummaryWidget> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Reprocessing>>(
      future: ReprocessingService.getCustomerReprocessing(widget.customerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
              child: Text('Error loading reprocessing requests'));
        }

        final reprocessing = snapshot.data ?? [];
        final openReprocessing =
            reprocessing.where((r) => r.status == 'OPEN').length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Reprocessing Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStat('Total', reprocessing.length.toString()),
                    _buildStat('Open', openReprocessing.toString()),
                    _buildStat(
                      'Resolved',
                      reprocessing
                          .where((r) => r.status == 'RESOLVED')
                          .length
                          .toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReprocessingListScreen(
                            customerId: widget.customerId,
                          ),
                        ),
                      );
                    },
                    child: const Text('View All Reprocessing Requests'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6C63FF),
          ),
        ),
        Text(label),
      ],
    );
  }
}

// ============================================================================
// EXAMPLE 4: Reprocessing List in Home Screen
// ============================================================================

class HomeScreenWithReprocessing extends StatelessWidget {
  final String customerId;

  const HomeScreenWithReprocessing({
    super.key,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to WhiteFox',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Recent reprocessing requests
          ReprocessingSummaryWidget(customerId: customerId),
          const SizedBox(height: 24),
          // Other widgets...
        ],
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 5: Quick Action Menu with Reprocessing
// ============================================================================

class QuickActionsMenu extends StatelessWidget {
  final String customerId;

  const QuickActionsMenu({
    super.key,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildActionCard(
          context,
          icon: Icons.shopping_bag,
          label: 'My Orders',
          onTap: () {
            // Navigate to orders
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.note,
          label: 'Reprocessing',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReprocessingListScreen(
                  customerId: customerId,
                ),
              ),
            );
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.wallet,
          label: 'Payments',
          onTap: () {
            // Navigate to payments
          },
        ),
        _buildActionCard(
          context,
          icon: Icons.person,
          label: 'Profile',
          onTap: () {
            // Navigate to profile
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: (MediaQuery.of(context).size.width - 48) / 2,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFF6C63FF),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EXAMPLE 6: Complete Integration in main.dart
// ============================================================================

void integrateReprocessingIntoMain() {
  // In your main.dart, after initializing ApiClient:
  // 1. Import the reprocessing module
  // 2. Add ReprocessingListScreen to your navigation
  // 3. Pass customerId from your auth state

  // Example:
  // void main() async {
  //   WidgetsFlutterBinding.ensureInitialized();
  //   await ApiClient.init();
  //   runApp(const MyApp());
  // }
  //
  // class MyApp extends StatelessWidget {
  //   @override
  //   Widget build(BuildContext context) {
  //     return MaterialApp(
  //       home: Consumer<AuthProvider>(
  //         builder: (context, auth, _) {
  //           if (auth.isAuthenticated) {
  //             return CustomerShell(customerId: auth.customerId);
  //           }
  //           return const LoginScreen();
  //         },
  //       ),
  //     );
  //   }
  // }
}

// ============================================================================
// Notes:
// - Replace 'customerId' with actual value from your authentication state
// - Update Color(0xFF6C63FF) with your app's theme color if different
// - Import statements must match your project structure
// - Test API connectivity before deploying
// ============================================================================
