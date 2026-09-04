import 'package:dio/dio.dart';
import '../models/reprocessing.dart';
import '../../core/network/api_client.dart';

class ReprocessingService {
  static const String _baseUrl = '/api/customers';
  static const String _storeBaseUrl = '/api/stores';
  static const String _adminBaseUrl = '/api/admin';

  /// Get all reprocessing requests for a specific customer
  static Future<List<Reprocessing>> getCustomerReprocessing(
      String customerId) async {
    try {
      final response = await ApiClient.dio.get(
        '$_baseUrl/$customerId/complaints',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => Reprocessing.fromJson(json)).toList();
      }
      throw Exception('Failed to load reprocessing requests');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get a specific reprocessing request for a customer
  static Future<Reprocessing> getCustomerReprocessingDetail(
      String customerId, String reprocessingId) async {
    try {
      final response = await ApiClient.dio.get(
        '$_baseUrl/$customerId/complaints/$reprocessingId',
      );

      if (response.statusCode == 200) {
        return Reprocessing.fromJson(response.data);
      }
      throw Exception('Failed to load reprocessing request');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get reprocessing history for a customer
  static Future<List<ReprocessingHistory>> getCustomerReprocessingHistory(
    String customerId,
    String reprocessingId,
  ) async {
    try {
      final response = await ApiClient.dio.get(
        '$_baseUrl/$customerId/complaints/$reprocessingId/history',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => ReprocessingHistory.fromJson(json)).toList();
      }
      throw Exception('Failed to load reprocessing history');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Create a new reprocessing request
  static Future<Reprocessing> createReprocessing(
    String customerId,
    CreateReprocessingRequest request,
  ) async {
    try {
      final response = await ApiClient.dio.post(
        '$_baseUrl/$customerId/complaints',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        return Reprocessing.fromJson(response.data);
      }
      throw Exception('Failed to create reprocessing request');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get all reprocessing requests for a specific store
  static Future<List<Reprocessing>> getStoreReprocessing(String storeId) async {
    try {
      final response = await ApiClient.dio.get(
        '$_storeBaseUrl/$storeId/complaints',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => Reprocessing.fromJson(json)).toList();
      }
      throw Exception('Failed to load reprocessing requests');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get a specific reprocessing request for a store
  static Future<Reprocessing> getStoreReprocessingDetail(
      String storeId, String reprocessingId) async {
    try {
      final response = await ApiClient.dio.get(
        '$_storeBaseUrl/$storeId/complaints/$reprocessingId',
      );

      if (response.statusCode == 200) {
        return Reprocessing.fromJson(response.data);
      }
      throw Exception('Failed to load reprocessing request');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get reprocessing history for a store
  static Future<List<ReprocessingHistory>> getStoreReprocessingHistory(
    String storeId,
    String reprocessingId,
  ) async {
    try {
      final response = await ApiClient.dio.get(
        '$_storeBaseUrl/$storeId/complaints/$reprocessingId/history',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => ReprocessingHistory.fromJson(json)).toList();
      }
      throw Exception('Failed to load reprocessing history');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Update reprocessing status (store endpoint)
  static Future<Reprocessing> updateReprocessingStatusStore(
    String storeId,
    String reprocessingId,
    UpdateReprocessingStatusRequest request,
  ) async {
    try {
      final response = await ApiClient.dio.put(
        '$_storeBaseUrl/$storeId/complaints/$reprocessingId/status',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        return Reprocessing.fromJson(response.data);
      }
      throw Exception('Failed to update reprocessing status');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Update reprocessing status (admin endpoint)
  static Future<Reprocessing> updateReprocessingStatusAdmin(
    String reprocessingId,
    UpdateReprocessingStatusRequest request,
  ) async {
    try {
      final response = await ApiClient.dio.put(
        '$_adminBaseUrl/complaints/$reprocessingId/status',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        return Reprocessing.fromJson(response.data);
      }
      throw Exception('Failed to update reprocessing status');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get all reprocessing requests (admin endpoint)
  static Future<List<Reprocessing>> getAllReprocessing() async {
    try {
      final response = await ApiClient.dio.get(
        '$_adminBaseUrl/complaints',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => Reprocessing.fromJson(json)).toList();
      }
      throw Exception('Failed to load reprocessing requests');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get a specific reprocessing request (admin endpoint)
  static Future<Reprocessing> getReprocessingAdmin(
      String reprocessingId) async {
    try {
      final response = await ApiClient.dio.get(
        '$_adminBaseUrl/complaints/$reprocessingId',
      );

      if (response.statusCode == 200) {
        return Reprocessing.fromJson(response.data);
      }
      throw Exception('Failed to load reprocessing request');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get reprocessing history (admin endpoint)
  static Future<List<ReprocessingHistory>> getReprocessingHistoryAdmin(
      String reprocessingId) async {
    try {
      final response = await ApiClient.dio.get(
        '$_adminBaseUrl/complaints/$reprocessingId/history',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => ReprocessingHistory.fromJson(json)).toList();
      }
      throw Exception('Failed to load reprocessing history');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }
}
