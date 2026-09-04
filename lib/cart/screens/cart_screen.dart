import 'package:flutter/material.dart';

import '../../booking/screens/book_pickup_screen.dart';
import '../../core/theme/app_theme.dart';

import '../services/cart_service.dart';

class CartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const CartScreen({super.key, this.items = const []});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    CartService.instance.addListener(_onCartChanged);
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CartService.instance.removeListener(_onCartChanged);
    super.dispose();
  }

  void proceedToPickup() {
    if (CartService.instance.selectedItems.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BookPickupScreen(selectedItems: CartService.instance.selectedItems),
      ),
    );
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
  Widget build(BuildContext context) {
    final cart = CartService.instance;
    final cartItems = cart.selectedItems;
    final waterSaved = cartItems.fold<double>(0, (sum, item) =>
        sum + ((item['waterSavedLitresPerItem'] as num?)?.toDouble() ?? 2.0) * ((item['quantity'] as num?)?.toDouble() ?? 0));
    final waterRecycled = cartItems.fold<double>(0, (sum, item) =>
        sum + ((item['waterRecycledLitresPerItem'] as num?)?.toDouble() ?? 1.4) * ((item['quantity'] as num?)?.toDouble() ?? 0));
    final carbonAvoided = cartItems.fold<double>(0, (sum, item) =>
        sum + ((item['carbonAvoidedKgPerItem'] as num?)?.toDouble() ?? 0.05) * ((item['quantity'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'My Cart',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: () {
              cart.clear();
            },
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/empty_basket.png', height: 200),
                  const SizedBox(height: 20),
                  const Text('Your cart is empty',
                      style:
                          TextStyle(color: AppTheme.mutedText, fontSize: 16)),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      ...List.generate(cartItems.length, (index) {
                        final item = cartItems[index];
                        final qty = item['quantity'] ?? 0;
                        final price = (item['price'] ?? 0).toDouble();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['itemName'] ?? 'Item',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${item['serviceType'] ?? ''} • ${item['variantName'] ?? 'Standard'}",
                                        style: const TextStyle(
                                          color: AppTheme.mutedText,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹$price x $qty',
                                        style: const TextStyle(
                                          color: AppTheme.darkText,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          cart.decrease(item['cartId']),
                                      icon: const Icon(
                                          Icons.remove_circle_outline),
                                    ),
                                    SizedBox(
                                      width: 20,
                                      child: Text(
                                        '$qty',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          cart.increase(item['cartId']),
                                      icon: const Icon(
                                        Icons.add_circle,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF8EF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF86C99A)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Row(children: [
                            Icon(Icons.eco, color: Color(0xFF19713A)),
                            SizedBox(width: 8),
                            Text('Your WhiteFox Impact', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF14532D))),
                          ]),
                          const SizedBox(height: 10),
                          Text('By choosing professional, resource-efficient garment care, this order is estimated to save ${waterSaved.toStringAsFixed(1)} L of water, recycle ${waterRecycled.toStringAsFixed(1)} L and avoid ${carbonAvoided.toStringAsFixed(2)} kg of carbon emissions.'),
                          const SizedBox(height: 8),
                          const Text('Your garments will be returned in responsible, lower-impact packaging.', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF19713A))),
                          const SizedBox(height: 6),
                          const Text('Estimated using WhiteFox Impact Methodology V1.', style: TextStyle(fontSize: 10, color: Colors.black54)),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          children: [
                            _row('Items', '${cart.totalItems}'),
                            _row('Subtotal',
                                '₹${cart.subtotal.toStringAsFixed(2)}'),
                            _row('GST 18%', '₹${cart.gst.toStringAsFixed(2)}'),
                            const SizedBox(height: 10),
                            const Divider(),
                            const SizedBox(height: 10),
                            _row(
                              'Payable Amount',
                              '₹${cart.total.toStringAsFixed(2)}',
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Image.asset(
                        'assets/images/cart_bottom_clothes.png',
                        height: 150,
                      ),
                    ],
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
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user,
                              color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Your items will be handled with care and hygiene.',
                              style: TextStyle(
                                color: AppTheme.mutedText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: proceedToPickup,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Proceed to Pickup Details'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _row(String title, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: bold ? AppTheme.darkText : AppTheme.mutedText,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              fontSize: bold ? 18 : 14,
              color: bold ? AppTheme.primary : AppTheme.darkText,
            ),
          ),
        ],
      ),
    );
  }
}
