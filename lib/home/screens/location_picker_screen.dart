import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/location/google_geocoding_service.dart';
import '../../core/theme/app_theme.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _searchController = TextEditingController();
  GoogleMapController? _mapController;
  Timer? _debounce;
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  List<GoogleLocationResult> _results = [];
  bool _searching = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    if (_selectedLocation != null) {
      _reverseGeocode(_selectedLocation!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _useCurrentLocation());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showError('Turn on location services to use your current location.');
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      _showError('Location permission was denied.');
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      _showError('Enable location permission from the app settings.');
      await Geolocator.openAppSettings();
      return false;
    }
    return true;
  }

  Future<void> _useCurrentLocation() async {
    if (_locating || !await _ensurePermission()) return;
    if (mounted) setState(() => _locating = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final location = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _selectedLocation = location);
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 16));
      await _reverseGeocode(location);
    } catch (e) {
      _showError('Unable to get your current location: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => _searchLocation(query.trim()),
    );
  }

  Future<void> _searchLocation(String query) async {
    if (mounted) setState(() => _searching = true);
    try {
      final results = await GoogleGeocodingService.search(query);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final result = await GoogleGeocodingService.reverse(
        location.latitude,
        location.longitude,
      );
      if (mounted) setState(() => _selectedAddress = result.address);
    } catch (e) {
      if (mounted) setState(() => _selectedAddress = 'Selected location');
      _showError(e);
    }
  }

  Future<void> _selectResult(GoogleLocationResult result) async {
    final location = LatLng(result.latitude, result.longitude);
    setState(() {
      _selectedLocation = location;
      _selectedAddress = result.address;
      _results = [];
      _searchController.clear();
    });
    await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 16));
  }

  Future<void> _saveAndReturn() async {
    final location = _selectedLocation;
    if (location == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('customer_lat', location.latitude);
    await prefs.setDouble('customer_lng', location.longitude);
    await prefs.setString(
      'customer_address',
      _selectedAddress.isEmpty ? 'Selected location' : _selectedAddress,
    );
    if (mounted) Navigator.pop(context, true);
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _selectedLocation ?? const LatLng(28.6139, 77.2090);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Select Location', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 14),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _selectedLocation == null
                ? <Marker>{}
                : {
                    Marker(
                      markerId: const MarkerId('selected-location'),
                      position: _selectedLocation!,
                    ),
                  },
            onMapCreated: (controller) => _mapController = controller,
            onTap: (location) {
              setState(() => _selectedLocation = location);
              _reverseGeocode(location);
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search with Google Maps...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                if (_results.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (_, index) {
                        final result = _results[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(result.address),
                          onTap: () => _selectResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 190,
            child: FloatingActionButton.small(
              heroTag: 'current-location',
              onPressed: _locating ? null : _useCurrentLocation,
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primary,
              child: _locating
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Deliver to', style: TextStyle(fontSize: 12, color: AppTheme.mutedText, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      _selectedAddress.isEmpty ? 'Finding your address...' : _selectedAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.navy),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _selectedLocation == null ? null : _saveAndReturn,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Confirm Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
