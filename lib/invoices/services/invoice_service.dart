import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../model/invoice_model.dart';

class InvoiceService {
  const InvoiceService();

  static const String _customerBase = '/api/invoices/customer/my';

  Future<List<InvoiceModel>> getMyInvoices({String? status}) async {
    try {
      final normalizedStatus = status?.trim().toUpperCase();

      final response = await ApiClient.dio.get(
        _customerBase,
        queryParameters: normalizedStatus == null || normalizedStatus.isEmpty
            ? null
            : <String, dynamic>{'status': normalizedStatus},
      );

      final data = response.data;
      if (data is! List) {
        throw const InvoiceServiceException(
          'The server returned an invalid invoice list.',
        );
      }

      return data
          .whereType<Map>()
          .map(
            (item) => InvoiceModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw InvoiceServiceException(_messageFrom(error));
    }
  }

  Future<InvoiceModel> getInvoice(String invoiceId) async {
    _requireId(invoiceId, 'Invoice');

    try {
      final response = await ApiClient.dio.get(
        '$_customerBase/${invoiceId.trim()}',
      );

      return _parseInvoice(response.data);
    } on DioException catch (error) {
      throw InvoiceServiceException(_messageFrom(error));
    }
  }

  Future<InvoiceModel> getInvoiceByOrder(String orderId) async {
    _requireId(orderId, 'Order');

    try {
      final response = await ApiClient.dio.get(
        '$_customerBase/orders/${orderId.trim()}',
      );

      return _parseInvoice(response.data);
    } on DioException catch (error) {
      throw InvoiceServiceException(_messageFrom(error));
    }
  }

  Future<Uint8List> downloadPaidInvoice(InvoiceModel invoice) async {
    if (!invoice.canDownload) {
      throw const InvoiceServiceException(
        'The final invoice can be downloaded only after complete payment.',
      );
    }

    try {
      final response = await ApiClient.dio.get<List<int>>(
        '$_customerBase/${invoice.id}/pdf',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const InvoiceServiceException(
          'The downloaded invoice is empty.',
        );
      }

      return Uint8List.fromList(bytes);
    } on DioException catch (error) {
      throw InvoiceServiceException(_messageFrom(error));
    }
  }

  Future<void> emailPaidInvoice(InvoiceModel invoice) async {
    if (!invoice.canDownload) {
      throw const InvoiceServiceException(
        'The final invoice can be emailed only after complete payment.',
      );
    }

    try {
      await ApiClient.dio.post(
        '$_customerBase/${invoice.id}/email',
      );
    } on DioException catch (error) {
      throw InvoiceServiceException(_messageFrom(error));
    }
  }

  static InvoiceModel _parseInvoice(Object? data) {
    if (data is! Map) {
      throw const InvoiceServiceException(
        'The server returned invalid invoice details.',
      );
    }

    return InvoiceModel.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  static void _requireId(String value, String label) {
    if (value.trim().isEmpty) {
      throw InvoiceServiceException('$label ID is required.');
    }
  }

  static String _messageFrom(DioException error) {
    final data = error.response?.data;

    if (data is Map) {
      final message = data['message'] ?? data['error'] ?? data['detail'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    switch (error.response?.statusCode) {
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return 'You do not have permission to access this invoice.';
      case 404:
        return 'Invoice not found.';
      case 409:
        return 'Complete the remaining payment to download the final invoice.';
      default:
        return 'Unable to load the invoice. Please try again.';
    }
  }
}

class InvoiceServiceException implements Exception {
  final String message;

  const InvoiceServiceException(this.message);

  @override
  String toString() => message;
}
