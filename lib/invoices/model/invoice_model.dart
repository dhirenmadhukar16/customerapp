class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String orderId;
  final String orderNumber;
  final String? customerId;
  final String? customerName;
  final String? storeId;
  final String? storeName;
  final String status;
  final double subtotal;
  final double gst;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String? paymentMethod;
  final String? paymentReference;
  final bool downloadAllowed;
  final bool orderConfirmationEmailed;
  final bool finalInvoiceEmailed;
  final DateTime? generatedAt;
  final DateTime? paidAt;
  final DateTime? orderConfirmationEmailedAt;
  final DateTime? finalInvoiceEmailedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.storeId,
    required this.storeName,
    required this.status,
    required this.subtotal,
    required this.gst,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentMethod,
    required this.paymentReference,
    required this.downloadAllowed,
    required this.orderConfirmationEmailed,
    required this.finalInvoiceEmailed,
    required this.generatedAt,
    required this.paidAt,
    required this.orderConfirmationEmailedAt,
    required this.finalInvoiceEmailedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: _text(json['id']),
      invoiceNumber: _text(json['invoiceNumber']),
      orderId: _text(json['orderId']),
      orderNumber: _text(json['orderNumber']),
      customerId: _nullableText(json['customerId']),
      customerName: _nullableText(json['customerName']),
      storeId: _nullableText(json['storeId']),
      storeName: _nullableText(json['storeName']),
      status: _text(json['status'], fallback: 'GENERATED').toUpperCase(),
      subtotal: _number(json['subtotal']),
      gst: _number(json['gst']),
      totalAmount: _number(json['totalAmount']),
      paidAmount: _number(json['paidAmount']),
      remainingAmount: _number(json['remainingAmount']),
      paymentMethod: _nullableText(json['paymentMethod']),
      paymentReference: _nullableText(json['paymentReference']),
      downloadAllowed: _boolean(json['downloadAllowed']),
      orderConfirmationEmailed: _boolean(json['orderConfirmationEmailed']),
      finalInvoiceEmailed: _boolean(json['finalInvoiceEmailed']),
      generatedAt: _date(json['generatedAt']),
      paidAt: _date(json['paidAt']),
      orderConfirmationEmailedAt: _date(json['orderConfirmationEmailedAt']),
      finalInvoiceEmailedAt: _date(json['finalInvoiceEmailedAt']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }

  bool get isGenerated => status == 'GENERATED';

  bool get isPartiallyPaid => status == 'PARTIALLY_PAID';

  bool get isPaid => status == 'PAID';

  bool get isCancelled => status == 'CANCELLED';

  bool get canDownload => isPaid && downloadAllowed;

  double get paymentProgress {
    if (totalAmount <= 0) return 0;
    return (paidAmount / totalAmount).clamp(0.0, 1.0).toDouble();
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static bool _boolean(Object? value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }

  static DateTime? _date(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : DateTime.tryParse(text);
  }
}
