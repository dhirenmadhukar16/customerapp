import 'package:dio/dio.dart';
import '../models/complaint.dart';
import '../../core/network/api_client.dart';

class ComplaintService {
  static const String _baseUrl = '/api/customers';
  static const String _storeBaseUrl = '/api/stores';
  static const String _adminBaseUrl = '/api/admin';

  /// Get all complaints for a specific customer
  static Future<List<Complaint>> getCustomerComplaints(
      String customerId) async {
    try {
      final response = await ApiClient.dio.get(
        '$_baseUrl/$customerId/complaints',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => Complaint.fromJson(json)).toList();
      }
      throw Exception('Failed to load complaints');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get a specific complaint for a customer
  static Future<Complaint> getCustomerComplaint(
      String customerId, String complaintId) async {
    try {
      final response = await ApiClient.dio.get(
        '$_baseUrl/$customerId/complaints/$complaintId',
      );

      if (response.statusCode == 200) {
        return Complaint.fromJson(response.data);
      }
      throw Exception('Failed to load complaint');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get complaint history for a customer
  static Future<List<ComplaintHistory>> getCustomerComplaintHistory(
    String customerId,
    String complaintId,
  ) async {
    try {
      final response = await ApiClient.dio.get(
        '$_baseUrl/$customerId/complaints/$complaintId/history',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => ComplaintHistory.fromJson(json)).toList();
      }
      throw Exception('Failed to load complaint history');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Create a new complaint
  static Future<Complaint> createComplaint(
    String customerId,
    CreateComplaintRequest request,
  ) async {
    try {
      final response = await ApiClient.dio.post(
        '$_baseUrl/$customerId/complaints',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        return Complaint.fromJson(response.data);
      }
      throw Exception('Failed to create complaint');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get all complaints for a specific store
  static Future<List<Complaint>> getStoreComplaints(String storeId) async {
    try {
      final response = await ApiClient.dio.get(
        '$_storeBaseUrl/$storeId/complaints',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => Complaint.fromJson(json)).toList();
      }
      throw Exception('Failed to load complaints');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get a specific complaint for a store
  static Future<Complaint> getStoreComplaint(
      String storeId, String complaintId) async {
    try {
      final response = await ApiClient.dio.get(
        '$_storeBaseUrl/$storeId/complaints/$complaintId',
      );

      if (response.statusCode == 200) {
        return Complaint.fromJson(response.data);
      }
      throw Exception('Failed to load complaint');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get complaint history for a store
  static Future<List<ComplaintHistory>> getStoreComplaintHistory(
    String storeId,
    String complaintId,
  ) async {
    try {
      final response = await ApiClient.dio.get(
        '$_storeBaseUrl/$storeId/complaints/$complaintId/history',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => ComplaintHistory.fromJson(json)).toList();
      }
      throw Exception('Failed to load complaint history');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Update complaint status (store endpoint)
  static Future<Complaint> updateComplaintStatusStore(
    String storeId,
    String complaintId,
    UpdateComplaintStatusRequest request,
  ) async {
    try {
      final response = await ApiClient.dio.put(
        '$_storeBaseUrl/$storeId/complaints/$complaintId/status',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        return Complaint.fromJson(response.data);
      }
      throw Exception('Failed to update complaint status');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Update complaint status (admin endpoint)
  static Future<Complaint> updateComplaintStatusAdmin(
    String complaintId,
    UpdateComplaintStatusRequest request,
  ) async {
    try {
      final response = await ApiClient.dio.put(
        '$_adminBaseUrl/complaints/$complaintId/status',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        return Complaint.fromJson(response.data);
      }
      throw Exception('Failed to update complaint status');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get all complaints (admin endpoint)
  static Future<List<Complaint>> getAllComplaints() async {
    try {
      final response = await ApiClient.dio.get(
        '$_adminBaseUrl/complaints',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => Complaint.fromJson(json)).toList();
      }
      throw Exception('Failed to load complaints');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get a specific complaint (admin endpoint)
  static Future<Complaint> getComplaintAdmin(String complaintId) async {
    try {
      final response = await ApiClient.dio.get(
        '$_adminBaseUrl/complaints/$complaintId',
      );

      if (response.statusCode == 200) {
        return Complaint.fromJson(response.data);
      }
      throw Exception('Failed to load complaint');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }

  /// Get complaint history (admin endpoint)
  static Future<List<ComplaintHistory>> getComplaintHistoryAdmin(
      String complaintId) async {
    try {
      final response = await ApiClient.dio.get(
        '$_adminBaseUrl/complaints/$complaintId/history',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        return data.map((json) => ComplaintHistory.fromJson(json)).toList();
      }
      throw Exception('Failed to load complaint history');
    } on DioException catch (e) {
      throw Exception('Error: ${e.message}');
    }
  }
}
