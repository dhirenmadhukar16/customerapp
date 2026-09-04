import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../cart/screens/cart_screen.dart';
import '../../cart/services/cart_service.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  bool loading = true;
  String? error;
  bool storeAvailable = false;

  // Data
  List<dynamic> catalogData = [];
  List<String> mainCategories = [];

  // State
  String? selectedMainCategory;

  @override
  void initState() {
    super.initState();
    loadServices();
    _checkStore();
    CartService.instance.addListener(_onCartChanged);
  }

  Future<void> _checkStore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final storeId = prefs.getString('customer_store_id');
      storeAvailable = storeId != null && storeId.isNotEmpty;
    });
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CartService.instance.removeListener(_onCartChanged);
    super.dispose();
  }

  Future<void> loadServices() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });

      final response = await ApiClient.dio.get('/api/customer-app/services');
      final data = response.data as List;

      final Set<String> mainCats = {};
      for (var item in data) {
        if (item['categoryName'] != null) {
          mainCats.add(item['categoryName']);
        }
      }

      CartService.instance.setServices(data);

      setState(() {
        catalogData = data;
        mainCategories = mainCats.toList();
        if (mainCategories.isNotEmpty) {
          selectedMainCategory = mainCategories.first;
        }
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void continueToBooking() {
    if (!storeAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No store available near your location. Please change location.')),
      );
      return;
    }

    if (CartService.instance.selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              CartScreen(items: CartService.instance.selectedItems)),
    );
  }

  String getItemImage(String itemName, String? thumbnailUrl) {
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) return thumbnailUrl;

    final lower = itemName.toLowerCase();
    if (lower.contains('t-shirt')) return 'assets/images/item_tshirt.png';
    if (lower.contains('shirt')) return 'assets/images/item_shirt.png';
    if (lower.contains('trouser')) return 'assets/images/item_trousers.png';
    if (lower.contains('blazer')) return 'assets/images/item_blazer.png';
    if (lower.contains('jacket')) return 'assets/images/item_jacket.png';
    return 'assets/images/item_shirt.png';
  }

  void _showVariantSelection(Map<String, dynamic> service) {
    final variants = service['variants'] as List<dynamic>? ?? [];
    if (variants.isEmpty) {
      CartService.instance.addVariant(service['id'].toString(), service,
          {'variantName': 'Standard', 'price': service['price']});
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Variant for ',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy)),
            const SizedBox(height: 16),
            ...variants.map((v) {
              return ListTile(
                onTap: () {
                  CartService.instance
                      .addVariant(service['id'].toString(), service, v);
                  Navigator.pop(context);
                },
                title: Text(v['variantName']),
                trailing: Text('₹',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.primary)),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  int getServiceQuantity(String catalogId) {
    int total = 0;
    CartService.instance.quantities.forEach((key, value) {
      if (key.startsWith(catalogId)) {
        total += value;
      }
    });
    return total;
  }

  void removeServiceAnyVariant(String catalogId) {
    // Finds the first variant of this catalogId in cart and removes one
    String? idToRemove;
    CartService.instance.quantities.forEach((key, value) {
      if (key.startsWith(catalogId)) {
        idToRemove = key;
      }
    });
    if (idToRemove != null) {
      CartService.instance.decrease(idToRemove!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;
    double total = cart.total;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Services & Prices'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.navy,
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : error != null
              ? Center(
                  child:
                      Text(error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // Main Categories TabBar
                    if (mainCategories.isNotEmpty)
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: mainCategories.length,
                          itemBuilder: (context, index) {
                            final cat = mainCategories[index];
                            final isSelected = cat == selectedMainCategory;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                selectedColor: AppTheme.primary,
                                labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.navy,
                                    fontWeight: FontWeight.bold),
                                onSelected: (val) =>
                                    setState(() => selectedMainCategory = cat),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Services List based on selected category
                    Expanded(
                      child: selectedMainCategory == null
                          ? const Center(child: Text('No services found'))
                          : _buildServicesList(selectedMainCategory!),
                    ),

                    // Cart Summary Bottom Sheet
                    if (cart.totalItems > 0)
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(30)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, -4))
                          ],
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
                            _row('Total', '₹${cart.total.toStringAsFixed(2)}',
                                bold: true),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: continueToBooking,
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Continue to Pickup Booking'),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward, size: 20)
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

  Widget _buildServicesList(String mainCategory) {
    // Filter services for the selected main category
    final servicesForCat =
        catalogData.where((s) => s['categoryName'] == mainCategory).toList();

    // Group by sub-category
    final Map<String, List<dynamic>> grouped = {};
    for (var s in servicesForCat) {
      final subCat = s['subCategoryName'] ?? 'General';
      if (!grouped.containsKey(subCat)) grouped[subCat] = [];
      grouped[subCat]!.add(s);
    }

    if (grouped.isEmpty) {
      return const Center(child: Text('No items in this category'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final subCatName = grouped.keys.elementAt(index);
        final items = grouped[subCatName]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(subCatName,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navy)),
            ),
            ...items.map((s) {
              final qty = getServiceQuantity(s['id'].toString());
              final img = getItemImage(s['itemName'] ?? '', s['thumbnailUrl']);
              final variants = s['variants'] as List<dynamic>? ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.softShadow),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                        image: DecorationImage(
                          image: img.startsWith('http')
                              ? NetworkImage(img) as ImageProvider
                              : AssetImage(img),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['itemName'] ?? 'Service',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                              variants.isNotEmpty
                                  ? 'From ₹${variants.first['price'] ?? 0.0}'
                                  : '₹${s['price'] ?? 0.0}',
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: qty == 0
                              ? null
                              : () =>
                                  removeServiceAnyVariant(s['id'].toString()),
                          icon: Icon(Icons.remove_circle_outline,
                              color: qty > 0
                                  ? AppTheme.darkText
                                  : Colors.grey.shade400),
                        ),
                        SizedBox(
                            width: 20,
                            child: Text(qty == 0 ? '' : '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900))),
                        IconButton(
                          onPressed: () => _showVariantSelection(s),
                          icon: const Icon(Icons.add_circle,
                              color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _row(String title, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  color: bold ? AppTheme.darkText : AppTheme.mutedText,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                  fontSize: bold ? 18 : 14,
                  color: bold ? AppTheme.primary : AppTheme.darkText)),
        ],
      ),
    );
  }
}
