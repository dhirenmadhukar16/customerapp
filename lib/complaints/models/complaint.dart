import 'package:intl/intl.dart';

class Complaint {
  final String id;
  final String customerId;
  final String orderId;
  final String orderNumber;
  final String storeId;
  final String storeName;
  final String category;
  final String description;
  final String priority;
  final String status;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Complaint({
    required this.id,
    required this.customerId,
    required this.orderId,
    required this.orderNumber,
    required this.storeId,
    required this.storeName,
    required this.category,
    required this.description,
    required this.priority,
    required this.status,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] ?? '',
      customerId: json['customerId'] ?? '',
      orderId: json['orderId'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      storeId: json['storeId'] ?? '',
      storeName: json['storeName'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      priority: json['priority'] ?? '',
      status: json['status'] ?? '',
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'])
          : null,
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'storeId': storeId,
      'storeName': storeName,
      'category': category,
      'description': description,
      'priority': priority,
      'status': status,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get formattedCreatedDate {
    return DateFormat('MMM dd, yyyy').format(createdAt);
  }

  String get priorityColor {
    switch (priority.toUpperCase()) {
      case 'LOW':
        return 'Green';
      case 'MEDIUM':
        return 'Orange';
      case 'HIGH':
        return 'Red';
      default:
        return 'Gray';
    }
  }

  String get statusColor {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return 'Blue';
      case 'IN_PROGRESS':
        return 'Orange';
      case 'RESOLVED':
        return 'Green';
      case 'CLOSED':
        return 'Gray';
      default:
        return 'Gray';
    }
  }
}

class ComplaintHistory {
  final String id;
  final Complaint complaint;
  final String oldStatus;
  final String newStatus;
  final String action;
  final String description;
  final String performedBy;
  final String performedByType;
  final DateTime createdAt;

  ComplaintHistory({
    required this.id,
    required this.complaint,
    required this.oldStatus,
    required this.newStatus,
    required this.action,
    required this.description,
    required this.performedBy,
    required this.performedByType,
    required this.createdAt,
  });

  factory ComplaintHistory.fromJson(Map<String, dynamic> json) {
    return ComplaintHistory(
      id: json['id'] ?? '',
      complaint: Complaint.fromJson(json['complaint'] ?? {}),
      oldStatus: json['oldStatus'] ?? '',
      newStatus: json['newStatus'] ?? '',
      action: json['action'] ?? '',
      description: json['description'] ?? '',
      performedBy: json['performedBy'] ?? '',
      performedByType: json['performedByType'] ?? '',
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'complaint': complaint.toJson(),
      'oldStatus': oldStatus,
      'newStatus': newStatus,
      'action': action,
      'description': description,
      'performedBy': performedBy,
      'performedByType': performedByType,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class CreateComplaintRequest {
  final String orderId;
  final String subject;
  final String description;
  final String category;
  final String priority;

  CreateComplaintRequest({
    required this.orderId,
    required this.subject,
    required this.description,
    required this.category,
    required this.priority,
  });

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'subject': subject,
      'description': description,
      'category': category,
      'priority': priority,
    };
  }
}

class UpdateComplaintStatusRequest {
  final String status;
  final String? remarks;

  UpdateComplaintStatusRequest({
    required this.status,
    this.remarks,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if (remarks != null) 'remarks': remarks,
    };
  }
}
