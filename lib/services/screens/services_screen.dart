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
  List<Map<String, dynamic>> packages = [];
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

      final responses = await Future.wait<dynamic>([
        ApiClient.dio
            .get('/api/customer-app/services')
            .then((response) => response.data),
        ApiClient.dio
            .get('/api/customer-app/packages')
            .then((response) => response.data)
            .catchError((_) => <dynamic>[]),
      ]);
      final data = responses[0] as List;
      final packageData = responses[1] is List
          ? (responses[1] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      final Set<String> mainCats = {};
      for (var item in data) {
        if (item['categoryName'] != null) {
          mainCats.add(item['categoryName']);
        }
      }

      CartService.instance.setServices(data);

      setState(() {
        catalogData = data;
        packages = packageData;
        mainCategories = mainCats.toList();
        if (packages.isNotEmpty) {
          selectedMainCategory = 'Packages';
        } else if (mainCategories.isNotEmpty) {
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
                    if (mainCategories.isNotEmpty || packages.isNotEmpty)
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: mainCategories.length + 1,
                          itemBuilder: (context, index) {
                            final cat = index == 0
                                ? 'Packages'
                                : mainCategories[index - 1];
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
                          : selectedMainCategory == 'Packages'
                              ? _buildPackagesSection()
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

  Widget _buildPackagesSection() {
    if (packages.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadServices,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.inventory_2_outlined,
                size: 58, color: AppTheme.mutedText),
            SizedBox(height: 14),
            Center(
              child: Text(
                'No packages are available right now',
                style: TextStyle(
                    color: AppTheme.mutedText, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadServices,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B6E4F), Color(0xFF23A36D)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WhiteFox Value Packages',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 5),
                Text(
                  'Premium garment care bundled at a better value.',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...packages.map(_packageCard),
        ],
      ),
    );
  }

  Widget _packageCard(Map<String, dynamic> package) {
    final items = package['items'] is List ? package['items'] as List : const [];
    final price = _asDouble(package['price']);
    final catalogueValue = _asDouble(package['catalogueValue']);
    final savings = _asDouble(package['savingsAmount']);
    final savingsPercentage = _asDouble(package['savingsPercentage']);
    final imageUrl = package['imageUrl']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              width: double.infinity,
              height: 145,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _packageImageFallback(),
            )
          else
            _packageImageFallback(),
          Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        package['name']?.toString() ?? 'WhiteFox Package',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.navy),
                      ),
                    ),
                    if (package['featured'] == true)
                      _packageBadge('FEATURED', const Color(0xFF7C3AED)),
                  ],
                ),
                if ((package['description']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    package['description'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.mutedText),
                  ),
                ],
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _packageBadge('${items.length} SERVICES', AppTheme.primary),
                    if (savings > 0)
                      _packageBadge(
                        'SAVE ${savingsPercentage.toStringAsFixed(0)}%',
                        const Color(0xFFE8790A),
                      ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Text(
                      '₹${price.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary),
                    ),
                    if (catalogueValue > price) ...[
                      const SizedBox(width: 9),
                      Text(
                        '₹${catalogueValue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.mutedText,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => _showPackageDetails(package),
                      child: const Text('View Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _packageImageFallback() {
    return Container(
      height: 112,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8F7EF), Color(0xFFD8F1E4)],
        ),
      ),
      child: const Icon(Icons.local_laundry_service_rounded,
          size: 54, color: AppTheme.primary),
    );
  }

  Widget _packageBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  void _showPackageDetails(Map<String, dynamic> package) {
    final items = package['items'] is List ? package['items'] as List : const [];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(22),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                package['name']?.toString() ?? 'WhiteFox Package',
                style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.navy),
              ),
              const SizedBox(height: 6),
              Text(package['description']?.toString() ?? '',
                  style: const TextStyle(color: AppTheme.mutedText)),
              const SizedBox(height: 20),
              const Text('Package includes',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.navy)),
              const SizedBox(height: 8),
              ...items.map((raw) {
                final item = raw is Map
                    ? Map<String, dynamic>.from(raw)
                    : <String, dynamic>{};
                final variant = item['variantName']?.toString() ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F7EF),
                    child: Icon(Icons.check, color: AppTheme.primary),
                  ),
                  title: Text(item['itemName']?.toString() ?? 'Service',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text([
                    if (variant.isNotEmpty) variant,
                    if ((item['categoryName']?.toString() ?? '').isNotEmpty)
                      item['categoryName'].toString(),
                  ].join(' • ')),
                  trailing: Text(
                    '${item['quantity'] ?? 1}×',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w900),
                  ),
                );
              }),
              if ((package['validUntil']?.toString() ?? '').isNotEmpty) ...[
                const Divider(height: 28),
                Text(
                  'Available until ${_formatPackageDate(package['validUntil'])}',
                  style: const TextStyle(
                      color: AppTheme.mutedText, fontWeight: FontWeight.w700),
                ),
              ],
              if ((package['termsAndConditions']?.toString() ?? '')
                  .isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Terms & conditions',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(package['termsAndConditions'].toString(),
                    style: const TextStyle(color: AppTheme.mutedText)),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Package checkout will be enabled once package-based booking is activated.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF9A5B00), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatPackageDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return value?.toString() ?? '-';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
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
