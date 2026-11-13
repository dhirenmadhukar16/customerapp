import 'dart:convert';

import 'package:http/http.dart' as http;

class GoogleGeocodingService {
  static const apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static void ensureConfigured() {
    if (apiKey.isEmpty) {
      throw StateError('GOOGLE_MAPS_API_KEY is not configured');
    }
  }

  static Future<GoogleLocationResult> reverse(
    double latitude,
    double longitude,
  ) async {
    ensureConfigured();
    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'latlng': '$latitude,$longitude',
      'key': apiKey,
    });
    final response = await http.get(uri);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['status'] != 'OK') {
      throw StateError(body['error_message']?.toString() ?? 'Address lookup failed');
    }
    final results = body['results'] as List? ?? const [];
    final address = results.isEmpty
        ? 'Current location'
        : (results.first as Map)['formatted_address']?.toString() ??
            'Current location';
    return GoogleLocationResult(
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
  }

  static Future<List<GoogleLocationResult>> search(String query) async {
    ensureConfigured();
    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'address': query,
      'components': 'country:IN',
      'key': apiKey,
    });
    final response = await http.get(uri);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['status'] != 'OK') return const [];
    return (body['results'] as List? ?? const []).map((raw) {
      final item = raw as Map<String, dynamic>;
      final location = item['geometry']['location'] as Map<String, dynamic>;
      return GoogleLocationResult(
        address: item['formatted_address']?.toString() ?? query,
        latitude: (location['lat'] as num).toDouble(),
        longitude: (location['lng'] as num).toDouble(),
      );
    }).toList();
  }
}

class GoogleLocationResult {
  final String address;
  final double latitude;
  final double longitude;

  const GoogleLocationResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}
