import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import '../../core/location/google_geocoding_service.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'location_picker_screen.dart';
import 'company_blog_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../navigation/customer_shell.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> dashboard = {};

  String customerId = '';

  String _currentAddress = '';
  String? _nearestStoreId;
  Map<String, dynamic>? _nearestStore;
  bool _storeAvailable = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLat = prefs.getDouble('customer_lat');
    final savedLng = prefs.getDouble('customer_lng');
    final savedAddr = prefs.getString('customer_address');

    if (savedAddr != null && savedAddr.isNotEmpty && mounted) {
      setState(() {
        _currentAddress = savedAddr;
      });
    }

    await _fetchGpsLocation(
      fallbackLat: savedLat,
      fallbackLng: savedLng,
      fallbackAddress: savedAddr,
    );
  }

  Future<void> _fetchGpsLocation({
    double? fallbackLat,
    double? fallbackLng,
    String? fallbackAddress,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _useFallbackOrPicker(fallbackLat, fallbackLng, fallbackAddress);
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await _useFallbackOrPicker(fallbackLat, fallbackLng, fallbackAddress);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _useFallbackOrPicker(fallbackLat, fallbackLng, fallbackAddress);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      String address = fallbackAddress ?? 'Current location';
      try {
        final result = await GoogleGeocodingService.reverse(
          position.latitude,
          position.longitude,
        );
        address = result.address;
      } catch (_) {
        // Coordinates are still valid if reverse geocoding is temporarily unavailable.
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('customer_lat', position.latitude);
      await prefs.setDouble('customer_lng', position.longitude);
      await prefs.setString('customer_address', address);
      if (mounted) setState(() => _currentAddress = address);

      await _findNearestStore(position.latitude, position.longitude);
      await loadDashboard();
    } catch (_) {
      await _useFallbackOrPicker(fallbackLat, fallbackLng, fallbackAddress);
    }
  }

  Future<void> _useFallbackOrPicker(
    double? latitude,
    double? longitude,
    String? address,
  ) async {
    if (latitude != null && longitude != null) {
      if (mounted && address != null) setState(() => _currentAddress = address);
      await _findNearestStore(latitude, longitude);
      await loadDashboard();
      return;
    }
    await _openLocationPicker();
  }

  Future<void> _loadSelectedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final latitude = prefs.getDouble('customer_lat');
    final longitude = prefs.getDouble('customer_lng');
    final address = prefs.getString('customer_address');
    if (latitude == null || longitude == null) return;
    if (mounted)
      setState(() => _currentAddress = address ?? 'Selected location');
    await _findNearestStore(latitude, longitude);
    await loadDashboard();
  }

  Future<void> _findNearestStore(double lat, double lng) async {
    try {
      final res = await ApiClient.dio
          .get('/api/customer-app/stores/nearest?latitude=$lat&longitude=$lng');
      if (res.data != null && res.data is Map && res.data['id'] != null) {
        setState(() {
          _nearestStoreId = res.data['id'];
          _nearestStore = Map<String, dynamic>.from(res.data);
          _storeAvailable = true;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('customer_store_id', _nearestStoreId!);
      } else {
        setState(() => _storeAvailable = false);
      }
    } catch (e) {
      setState(() => _storeAvailable = false);
    }
  }

  Future<void> _openLocationPicker() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLat = prefs.getDouble('customer_lat');
    final savedLng = prefs.getDouble('customer_lng');

    LatLng? initialLoc;
    if (savedLat != null && savedLng != null) {
      initialLoc = LatLng(savedLat, savedLng);
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => LocationPickerScreen(initialLocation: initialLoc)),
    );

    if (result == true) {
      await _loadSelectedLocation();
    }
  }

  Future<void> loadDashboard() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      customerId = prefs.getString('userId') ?? '';

      if (customerId.isEmpty) {
        throw Exception('User not logged in or customer ID not found.');
      }

      final response = await ApiClient.dio.get(
        '/api/customer-app/customers/$customerId/dashboard',
      );

      setState(() {
        dashboard = Map<String, dynamic>.from(response.data);
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List get activeBookings => dashboard['activeBookings'] ?? [];
  List get activeOrders => dashboard['activeOrders'] ?? [];
  List get latestUpdates => dashboard['latestUpdates'] ?? [];

  void _openServicesPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerShell(initialIndex: 1),
      ),
    );
  }

  Future<void> _openStoreGoogleProfile() async {
    final store = _nearestStore;
    if (store == null) return;

    final directUrl = store['googleMapsUrl'] ??
        store['googleBusinessUrl'] ??
        store['googlePlaceUrl'];
    final placeId = store['googlePlaceId'] ?? store['placeId'];
    final storeName =
        (store['name'] ?? store['storeName'] ?? 'WhiteFox Laundry').toString();
    final address =
        (store['address'] ?? store['storeAddress'] ?? '').toString();

    Uri uri;
    if (directUrl != null && directUrl.toString().trim().isNotEmpty) {
      uri = Uri.parse(directUrl.toString().trim());
    } else if (placeId != null && placeId.toString().trim().isNotEmpty) {
      uri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '$storeName $address'.trim(),
        'query_place_id': placeId.toString().trim(),
      });
    } else {
      uri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '$storeName $address'.trim(),
      });
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to open the store on Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 40,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Icon(Icons.location_on, color: AppTheme.primary, size: 28),
        ),
        title: GestureDetector(
          onTap: _openLocationPicker,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Delivery to',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppTheme.darkText),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppTheme.darkText),
                ],
              ),
              Text(
                _currentAddress.isEmpty
                    ? 'Fetching location...'
                    : _currentAddress,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppTheme.mutedText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            icon: const Icon(Icons.notifications_none_outlined,
                color: AppTheme.darkText, size: 26),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(
                      child: Text(error!,
                          style: const TextStyle(color: Colors.red)))
                  : RefreshIndicator(
                      onRefresh: loadDashboard,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _heroCard(),
                            const SizedBox(height: 18),
                            if (_nearestStore != null) ...[
                              _careManagerCard(),
                              const SizedBox(height: 18),
                            ],
                            Row(
                              children: [
                                _summaryCard(
                                    'Active Bookings',
                                    activeBookings.length.toString(),
                                    Icons.calendar_month,
                                    () => _openActiveItems(
                                          title: 'Active Bookings',
                                          items: activeBookings,
                                          booking: true,
                                        )),
                                const SizedBox(width: 12),
                                _summaryCard(
                                    'Active Orders',
                                    activeOrders.length.toString(),
                                    Icons.local_laundry_service,
                                    () => _openActiveItems(
                                          title: 'Active Orders',
                                          items: activeOrders,
                                          booking: false,
                                        )),
                              ],
                            ),
                            const SizedBox(height: 22),
                            _sectionHeader('Latest Updates'),
                            const SizedBox(height: 10),
                            _latestUpdateBanners(),
                            const SizedBox(height: 30),
                          ],
                        ).animate().fadeIn(duration: 600.ms).slideY(
                            begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                      ),
                    ),
          if (!_storeAvailable && !loading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'We are not here yet!',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navy),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'There is no WhiteFox store within 10 km of your selected location.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.mutedText),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _openLocationPicker,
                          child: const Text('Change Location'),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _careManagerCard() {
    final store = _nearestStore!;
    final manager =
        store['storeAdminName'] ?? store['managerName'] ?? 'WhiteFox Care Team';
    final storeName =
        store['name'] ?? store['storeName'] ?? 'Assigned WhiteFox Store';
    final address = store['address'] ?? store['storeAddress'] ?? '';
    final distance = store['distanceKm'];
    return GestureDetector(
      onTap: _openStoreGoogleProfile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF172554), Color(0xFF312E81)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOUR WHITEFOX CARE MANAGER',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            const CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white,
                child: Icon(Icons.support_agent, color: AppTheme.primary)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(manager.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                  Text(storeName.toString(),
                      style: const TextStyle(color: Colors.white70)),
                ])),
          ]),
          if (address.toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(address.toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
          if (distance != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                  '${(distance as num).toStringAsFixed(1)} km from your location',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 10),
          const Text(
              'Personally coordinating your pickup, garment care and delivery.',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.map_outlined, color: Colors.white, size: 17),
              SizedBox(width: 7),
              Text(
                'View store on Google Maps',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Spacer(),
              Icon(Icons.open_in_new, color: Colors.white70, size: 16),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF6B9E7A),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/images/home_banner_1.png',
            fit: BoxFit.cover,
          ),
          // Gradient overlay so text is readable
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.62),
                  Colors.black.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Text content
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fresh Clothes,\nHappy You!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    shadows: [
                      Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 2))
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Premium laundry at your doorstep.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _openServicesPage,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Book Now',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
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

  void _openActiveItems({
    required String title,
    required List items,
    required bool booking,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          body: items.isEmpty
              ? Center(
                  child: Text(
                    booking ? 'No active bookings.' : 'No active orders.',
                    style: const TextStyle(
                      color: AppTheme.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = Map<String, dynamic>.from(items[index] as Map);
                    return booking ? _bookingCard(item) : _orderCard(item);
                  },
                ),
        ),
      ),
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: AppTheme.primary, size: 28),
                const SizedBox(height: 10),
                Text(value,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.darkText)),
                const SizedBox(height: 4),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.mutedText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkText)),
        TextButton(
          onPressed: () {},
          child: const Text('View All',
              style: TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _latestUpdateBanners() {
    final banners = [
      _UpdateBannerData(
        gradient: const [Color(0xFF0F6B3A), Color(0xFF1A8C4E)],
        icon: Icons.local_laundry_service,
        title: 'We care for your clothes\nlike you do.',
        subtitle: 'Premium laundry at your doorstep',
        tag: 'Book Now →',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const CustomerShell(initialIndex: 1)),
          );
        },
      ),
      _UpdateBannerData(
        gradient: const [Color(0xFF1565C0), Color(0xFF1E88E5)],
        icon: Icons.water_drop_outlined,
        title: 'Eco-friendly cleaning\nfor every garment.',
        subtitle: 'Save water, save the planet 🌿',
        tag: 'Learn More →',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CompanyBlogScreen()),
          );
        },
      ),
      _UpdateBannerData(
        gradient: const [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
        icon: Icons.star_outline,
        title: 'Free pickup & delivery\nfor orders above ₹200.',
        subtitle: 'Limited time offer — grab it now!',
        tag: 'Order Now →',
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const CustomerShell(initialIndex: 1)),
          );
        },
      ),
      _UpdateBannerData(
        gradient: const [Color(0xFFBF360C), Color(0xFFE64A19)],
        icon: Icons.timer_outlined,
        title: '24-hour express\nturnaround available.',
        subtitle: 'Get your clothes within 6-24 hours for urgent needs.',
        tag: 'Schedule →',
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('This service is coming soon in your area.')),
          );
        },
      ),
    ];

    return Column(
      children: banners.map((b) => _updateBannerCard(b)).toList(),
    );
  }

  Widget _updateBannerCard(_UpdateBannerData data) {
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 100,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: data.gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: data.gradient.last.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative bubble top-right
            Positioned(
              top: -24,
              right: -24,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -16,
              right: 60,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  // Icon circle
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(data.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          data.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data.subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tag pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      data.tag,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(Map item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt_long, color: AppTheme.primary),
        ),
        title: Text(
          item['orderNumber']?.toString() ?? 'ORD-1001',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['status']?.toString() ?? 'CREATED',
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
            if (item['storeName'] != null)
              Text(item['storeName'].toString(),
                  style:
                      const TextStyle(color: AppTheme.mutedText, fontSize: 12)),
          ],
        ),
        trailing: item['totalAmount'] != null
            ? Text(
                '₹${item['totalAmount']}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppTheme.darkText),
              )
            : null,
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> item) {
    final bookingNumber =
        item['bookingNumber'] ?? item['bookingCode'] ?? item['id'] ?? 'Booking';
    final status = item['status'] ?? item['bookingStatus'] ?? 'REQUESTED';
    final storeName = item['storeName'] ?? item['assignedStoreName'];
    final pickup =
        item['pickupDate'] ?? item['scheduledPickupAt'] ?? item['pickupSlot'];
    final amount =
        item['totalAmount'] ?? item['estimatedAmount'] ?? item['amount'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.calendar_month, color: AppTheme.primary),
        ),
        title: Text(
          bookingNumber.toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status.toString(),
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (storeName != null)
              Text(
                storeName.toString(),
                style: const TextStyle(
                  color: AppTheme.mutedText,
                  fontSize: 12,
                ),
              ),
            if (pickup != null)
              Text(
                'Pickup: $pickup',
                style: const TextStyle(
                  color: AppTheme.mutedText,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: amount == null
            ? null
            : Text(
                '₹$amount',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppTheme.darkText,
                ),
              ),
      ),
    );
  }

  Widget _listCard(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppTheme.primary),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 12)),
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Text(message,
          style: const TextStyle(
              color: AppTheme.mutedText, fontWeight: FontWeight.w600)),
    );
  }
}

// Inline WhiteFox SVG-like logo using CustomPainter
class _WhiteFoxLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _FoxPainter(),
      ),
    );
  }
}

class _FoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Fox head body (circle)
    canvas.drawCircle(Offset(cx, cy + 2), size.width * 0.28, paint);

    // Left ear (triangle)
    final leftEar = Path()
      ..moveTo(cx - size.width * 0.22, cy - size.height * 0.10)
      ..lineTo(cx - size.width * 0.38, cy - size.height * 0.40)
      ..lineTo(cx - size.width * 0.06, cy - size.height * 0.22)
      ..close();
    canvas.drawPath(leftEar, paint);

    // Right ear (triangle)
    final rightEar = Path()
      ..moveTo(cx + size.width * 0.22, cy - size.height * 0.10)
      ..lineTo(cx + size.width * 0.38, cy - size.height * 0.40)
      ..lineTo(cx + size.width * 0.06, cy - size.height * 0.22)
      ..close();
    canvas.drawPath(rightEar, paint);

    // Eyes
    final eyePaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(cx - size.width * 0.10, cy), size.width * 0.06, eyePaint);
    canvas.drawCircle(
        Offset(cx + size.width * 0.10, cy), size.width * 0.06, eyePaint);

    // Nose
    final nosePaint = Paint()
      ..color = const Color(0xFF0a6e38)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(cx, cy + size.height * 0.10), size.width * 0.04, nosePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UpdateBannerData {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  final VoidCallback onTap;

  const _UpdateBannerData({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.onTap,
  });
}
