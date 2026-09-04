# Complaints Module Integration Guide

This document explains how to integrate the Complaints module into your Flutter customer app.

## Overview

The Complaints module allows customers to:

- View all their complaints with filtering by status
- Create new complaints for their orders
- View detailed complaint information
- Track complaint history and status updates

## File Structure

```
lib/complaints/
├── models/
│   └── complaint.dart          # Data models
├── services/
│   └── complaint_service.dart  # API service
└── screens/
    ├── complaints_list_screen.dart      # Complaints list view
    ├── complaint_detail_screen.dart     # Complaint details view
    └── create_complaint_screen.dart     # Create complaint form
```

## Components

### 1. Data Models (`lib/complaints/models/complaint.dart`)

- **Complaint**: Represents a single complaint with all details
  - Fields: id, customerId, orderId, orderNumber, storeId, storeName, category, description, priority, status, resolvedAt, createdAt, updatedAt
  - Helper methods: formattedCreatedDate, priorityColor, statusColor

- **ComplaintHistory**: Represents a complaint status change event
  - Fields: id, complaint, oldStatus, newStatus, action, description, performedBy, performedByType, createdAt

- **CreateComplaintRequest**: Request model for creating complaints
- **UpdateComplaintStatusRequest**: Request model for updating complaint status

### 2. API Service (`lib/complaints/services/complaint_service.dart`)

Provides static methods for all complaint-related API operations:

#### Customer Endpoints:

```dart
// Get all complaints for a customer
ComplaintService.getCustomerComplaints(String customerId)

// Get specific complaint details
ComplaintService.getCustomerComplaint(String customerId, String complaintId)

// Get complaint history
ComplaintService.getCustomerComplaintHistory(String customerId, String complaintId)

// Create new complaint
ComplaintService.createComplaint(String customerId, CreateComplaintRequest request)
```

#### Store Endpoints:

```dart
// Get store complaints
ComplaintService.getStoreComplaints(String storeId)

// Get store complaint details
ComplaintService.getStoreComplaint(String storeId, String complaintId)

// Get store complaint history
ComplaintService.getStoreComplaintHistory(String storeId, String complaintId)

// Update complaint status (store)
ComplaintService.updateComplaintStatusStore(String storeId, String complaintId, UpdateComplaintStatusRequest request)
```

#### Admin Endpoints:

```dart
// Get all complaints
ComplaintService.getAllComplaints()

// Get complaint details
ComplaintService.getComplaintAdmin(String complaintId)

// Get complaint history
ComplaintService.getComplaintHistoryAdmin(String complaintId)

// Update complaint status (admin)
ComplaintService.updateComplaintStatusAdmin(String complaintId, UpdateComplaintStatusRequest request)
```

### 3. UI Screens

#### ComplaintsListScreen

- Shows all complaints for a customer
- Filterable by status (ALL, OPEN, IN_PROGRESS, RESOLVED, CLOSED)
- Pull-to-refresh functionality
- Navigate to complaint details or create new complaint
- Displays: order number, description, status, priority, category

#### ComplaintDetailScreen

- Shows complete complaint information
- Displays complaint metadata (store, order, dates)
- Shows current status and priority
- Lists complaint category
- Shows activity history with status changes
- Automatically loads complaint details if not provided

#### CreateComplaintScreen

- Form to create new complaints
- Fields: Order ID, Category, Priority, Subject, Description
- Validation for all fields
- Error handling and success feedback
- Navigates back to list after successful creation

## Integration Steps

### Step 1: Add to Navigation

Add the complaints list screen to your navigation shell:

```dart
// In your customer_shell.dart or navigation setup
import 'package:whitefox_customer_app/complaints/screens/complaints_list_screen.dart';

// Add to your navigation items (e.g., in BottomNavigationBar):
NavigationDestination(
  icon: Icon(Icons.list_alt),
  label: 'Complaints',
),

// Navigate to complaints:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ComplaintsListScreen(
      customerId: userId, // Get from your auth state
    ),
  ),
);
```

### Step 2: Use in Screens

You can access complaints from other screens:

```dart
import 'package:whitefox_customer_app/complaints/services/complaint_service.dart';
import 'package:whitefox_customer_app/complaints/models/complaint.dart';

// In any screen:
try {
  final complaints = await ComplaintService.getCustomerComplaints(customerId);
  // Use complaints
} catch (e) {
  print('Error: $e');
}
```

### Step 3: Update API Base URL

Make sure the API base URL in `lib/core/network/api_client.dart` matches your backend:

```dart
static const String baseUrl = 'http://localhost:8080'; // Update as needed
```

## Usage Examples

### Example 1: Navigate to Complaints List

```dart
import 'package:whitefox_customer_app/complaints/screens/complaints_list_screen.dart';

// In your navigation
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ComplaintsListScreen(
      customerId: currentUserId,
    ),
  ),
);
```

### Example 2: Create a Complaint Programmatically

```dart
import 'package:whitefox_customer_app/complaints/services/complaint_service.dart';
import 'package:whitefox_customer_app/complaints/models/complaint.dart';

final request = CreateComplaintRequest(
  orderId: 'order-123',
  subject: 'Poor washing quality',
  description: 'The clothes were not washed properly...',
  category: 'POOR_WASHING',
  priority: 'HIGH',
);

try {
  final complaint = await ComplaintService.createComplaint(customerId, request);
  print('Complaint created: ${complaint.id}');
} catch (e) {
  print('Error: $e');
}
```

### Example 3: Get Complaint History

```dart
try {
  final history = await ComplaintService.getCustomerComplaintHistory(
    customerId,
    complaintId,
  );

  for (var event in history) {
    print('${event.action}: ${event.oldStatus} → ${event.newStatus}');
  }
} catch (e) {
  print('Error: $e');
}
```

## API Endpoints Summary

### Customer Endpoints

- `GET /api/customers/{customerId}/complaints` - List complaints
- `POST /api/customers/{customerId}/complaints` - Create complaint
- `GET /api/customers/{customerId}/complaints/{complaintId}` - Get complaint
- `GET /api/customers/{customerId}/complaints/{complaintId}/history` - Get history

### Store Endpoints

- `GET /api/stores/{storeId}/complaints` - List complaints
- `GET /api/stores/{storeId}/complaints/{complaintId}` - Get complaint
- `GET /api/stores/{storeId}/complaints/{complaintId}/history` - Get history
- `PUT /api/stores/{storeId}/complaints/{complaintId}/status` - Update status

### Admin Endpoints

- `GET /api/admin/complaints` - List all complaints
- `GET /api/admin/complaints/{complaintId}` - Get complaint
- `GET /api/admin/complaints/{complaintId}/history` - Get history
- `PUT /api/admin/complaints/{complaintId}/status` - Update status

## Status Values

- `OPEN`: New complaint, not yet reviewed
- `IN_PROGRESS`: Being investigated or resolved
- `RESOLVED`: Issue has been resolved
- `CLOSED`: Complaint is closed

## Priority Values

- `LOW`: Non-urgent issue
- `MEDIUM`: Moderately urgent
- `HIGH`: Urgent issue requiring immediate attention

## Category Values

- `POOR_WASHING`: Quality of washing service
- `DAMAGED_ITEM`: Items damaged during service
- `MISSING_ITEM`: Items missing from service
- `LATE_DELIVERY`: Delivery delayed
- `INCORRECT_ORDER`: Wrong items delivered
- `QUALITY_ISSUE`: General quality issues
- `OTHER`: Other issues

## Styling and Customization

The components use the app's theme colors:

- Primary color: `Color(0xFF6C63FF)` (Purple)
- Status colors:
  - OPEN/In Progress: Blue
  - RESOLVED: Green
  - CLOSED: Gray
- Priority colors:
  - LOW: Green
  - MEDIUM: Orange
  - HIGH: Red

### Customize Colors

Modify the color constants in the screen files:

```dart
// In any screen
backgroundColor: const Color(0xFF6C63FF), // Change primary color
```

## Error Handling

All API methods throw exceptions with descriptive messages:

```dart
try {
  final complaints = await ComplaintService.getCustomerComplaints(customerId);
} catch (e) {
  // Handle error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

## Testing

### Test Data

You can test the integration with sample complaint data:

```dart
final testComplaint = Complaint(
  id: '123',
  customerId: 'cust-1',
  orderId: 'order-1',
  orderNumber: 'ORD-001',
  storeId: 'store-1',
  storeName: 'Test Store',
  category: 'POOR_WASHING',
  description: 'Test complaint',
  priority: 'HIGH',
  status: 'OPEN',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

## Troubleshooting

### Issue: Complaints not loading

- Check if the API base URL is correct
- Verify the auth token is being sent (check SharedPreferences)
- Check network connectivity
- Check API server is running

### Issue: Cannot create complaint

- Verify all required fields are filled
- Check Order ID format matches backend expectations
- Ensure customer has valid session/token

### Issue: Status updates not working

- Verify user has permission to update (check auth)
- Ensure status value is valid (OPEN, IN_PROGRESS, RESOLVED, CLOSED)

## Future Enhancements

Consider adding:

- Image/evidence upload for complaints
- Real-time complaint status notifications
- Complaint search functionality
- Export complaints to PDF
- Complaint templates for common issues
- Rating system for complaint resolution
- Push notifications for status changes

---

For questions or issues, contact the development team.
