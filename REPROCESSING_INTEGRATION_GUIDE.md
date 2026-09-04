# Reprocessing Module Integration Guide

This document explains how to integrate the Reprocessing module into your Flutter customer app.

## Overview

The Reprocessing module allows customers to:

- View all their reprocessing requests with filtering by status
- Create new reprocessing requests for their orders
- View detailed reprocessing request information
- Track reprocessing history and status updates

## File Structure

```
lib/reprocessing/
├── models/
│   └── reprocessing.dart          # Data models
├── services/
│   └── reprocessing_service.dart  # API service
└── screens/
    ├── reprocessing_list_screen.dart      # Reprocessing list view
    ├── reprocessing_detail_screen.dart    # Reprocessing details view
    └── create_reprocessing_screen.dart    # Create reprocessing request form
```

## Components

### 1. Data Models (`lib/reprocessing/models/reprocessing.dart`)

- **Reprocessing**: Represents a single reprocessing request with all details
  - Fields: id, customerId, orderId, orderNumber, storeId, storeName, category, description, priority, status, resolvedAt, createdAt, updatedAt
  - Helper methods: formattedCreatedDate, priorityColor, statusColor

- **ReprocessingHistory**: Represents a reprocessing request status change event
  - Fields: id, reprocessing, oldStatus, newStatus, action, description, performedBy, performedByType, createdAt

- **CreateReprocessingRequest**: Request model for creating reprocessing requests
- **UpdateReprocessingStatusRequest**: Request model for updating reprocessing request status

### 2. API Service (`lib/reprocessing/services/reprocessing_service.dart`)

Provides static methods for all reprocessing-related API operations:

#### Customer Endpoints:

```dart
// Get all reprocessing requests for a customer
ReprocessingService.getCustomerReprocessing(String customerId)

// Get specific reprocessing request details
ReprocessingService.getCustomerReprocessingDetail(String customerId, String reprocessingId)

// Get reprocessing request history
ReprocessingService.getCustomerReprocessingHistory(String customerId, String reprocessingId)

// Create new reprocessing request
ReprocessingService.createReprocessing(String customerId, CreateReprocessingRequest request)
```

#### Store Endpoints:

```dart
// Get store reprocessing requests
ReprocessingService.getStoreReprocessing(String storeId)

// Get store reprocessing request details
ReprocessingService.getStoreReprocessingDetail(String storeId, String reprocessingId)

// Get store reprocessing request history
ReprocessingService.getStoreReprocessingHistory(String storeId, String reprocessingId)

// Update reprocessing request status (store)
ReprocessingService.updateReprocessingStatusStore(String storeId, String reprocessingId, UpdateReprocessingStatusRequest request)
```

#### Admin Endpoints:

```dart
// Get all reprocessing requests
ReprocessingService.getAllReprocessing()

// Get reprocessing request details
ReprocessingService.getReprocessingAdmin(String reprocessingId)

// Get reprocessing request history
ReprocessingService.getReprocessingHistoryAdmin(String reprocessingId)

// Update reprocessing request status (admin)
ReprocessingService.updateReprocessingStatusAdmin(String reprocessingId, UpdateReprocessingStatusRequest request)
```

### 3. UI Screens

#### ReprocessingListScreen

- Shows all reprocessing requests for a customer
- Filterable by status (ALL, OPEN, IN_PROGRESS, RESOLVED, CLOSED)
- Pull-to-refresh functionality
- Navigate to reprocessing request details or create new request
- Displays: order number, description, status, priority, category

#### ReprocessingDetailScreen

- Shows complete reprocessing request information
- Displays reprocessing request metadata (store, order, dates)
- Shows current status and priority
- Lists reprocessing request category
- Shows activity history with status changes
- Automatically loads reprocessing request details if not provided

#### CreateReprocessingScreen

- Form to create new reprocessing requests
- Fields: Order ID, Category, Priority, Subject, Description
- Validation for all fields
- Error handling and success feedback
- Navigates back to list after successful creation

## Integration Steps

### Step 1: Add to Navigation

Add the reprocessing list screen to your navigation shell:

```dart
// In your customer_shell.dart or navigation setup
import 'package:whitefox_customer_app/reprocessing/screens/reprocessing_list_screen.dart';

// Add to your navigation items (e.g., in BottomNavigationBar):
NavigationDestination(
  icon: Icon(Icons.list_alt),
  label: 'Reprocessing',
),

// Navigate to reprocessing:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ReprocessingListScreen(
      customerId: userId, // Get from your auth state
    ),
  ),
);
```

### Step 2: Use in Screens

You can access reprocessing requests from other screens:

```dart
import 'package:whitefox_customer_app/reprocessing/services/reprocessing_service.dart';
import 'package:whitefox_customer_app/reprocessing/models/reprocessing.dart';

// In any screen:
try {
  final reprocessing = await ReprocessingService.getCustomerReprocessing(customerId);
  // Use reprocessing requests
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

### Example 1: Navigate to Reprocessing List

```dart
import 'package:whitefox_customer_app/reprocessing/screens/reprocessing_list_screen.dart';

// In your navigation
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ReprocessingListScreen(
      customerId: currentUserId,
    ),
  ),
);
```

### Example 2: Create a Reprocessing Request Programmatically

```dart
import 'package:whitefox_customer_app/reprocessing/services/reprocessing_service.dart';
import 'package:whitefox_customer_app/reprocessing/models/reprocessing.dart';

final request = CreateReprocessingRequest(
  orderId: 'order-123',
  subject: 'Reprocess order',
  description: 'Please reprocess the washing...',
  category: 'POOR_WASHING',
  priority: 'HIGH',
);

try {
  final reprocessing = await ReprocessingService.createReprocessing(customerId, request);
  print('Reprocessing request created: ${reprocessing.id}');
} catch (e) {
  print('Error: $e');
}
```

### Example 3: Get Reprocessing Request History

```dart
try {
  final history = await ReprocessingService.getCustomerReprocessingHistory(
    customerId,
    reprocessingId,
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

- `GET /api/customers/{customerId}/complaints` - List reprocessing requests
- `POST /api/customers/{customerId}/complaints` - Create reprocessing request
- `GET /api/customers/{customerId}/complaints/{complaintId}` - Get reprocessing request
- `GET /api/customers/{customerId}/complaints/{complaintId}/history` - Get history

### Store Endpoints

- `GET /api/stores/{storeId}/complaints` - List reprocessing requests
- `GET /api/stores/{storeId}/complaints/{complaintId}` - Get reprocessing request
- `GET /api/stores/{storeId}/complaints/{complaintId}/history` - Get history
- `PUT /api/stores/{storeId}/complaints/{complaintId}/status` - Update status

### Admin Endpoints

- `GET /api/admin/complaints` - List all reprocessing requests
- `GET /api/admin/complaints/{complaintId}` - Get reprocessing request
- `GET /api/admin/complaints/{complaintId}/history` - Get history
- `PUT /api/admin/complaints/{complaintId}/status` - Update status

## Status Values

- `OPEN`: New reprocessing request, not yet reviewed
- `IN_PROGRESS`: Being processed or resolved
- `RESOLVED`: Issue has been resolved
- `CLOSED`: Reprocessing request is closed

## Priority Values

- `LOW`: Non-urgent request
- `MEDIUM`: Moderately urgent
- `HIGH`: Urgent request requiring immediate attention

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
  final reprocessing = await ReprocessingService.getCustomerReprocessing(customerId);
} catch (e) {
  // Handle error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

## Testing

### Test Data

You can test the integration with sample reprocessing request data:

```dart
final testReprocessing = Reprocessing(
  id: '123',
  customerId: 'cust-1',
  orderId: 'order-1',
  orderNumber: 'ORD-001',
  storeId: 'store-1',
  storeName: 'Test Store',
  category: 'POOR_WASHING',
  description: 'Test reprocessing request',
  priority: 'HIGH',
  status: 'OPEN',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

## Troubleshooting

### Issue: Reprocessing requests not loading

- Check if the API base URL is correct
- Verify the auth token is being sent (check SharedPreferences)
- Check network connectivity
- Check API server is running

### Issue: Cannot create reprocessing request

- Verify all required fields are filled
- Check Order ID format matches backend expectations
- Ensure customer has valid session/token

### Issue: Status updates not working

- Verify user has permission to update (check auth)
- Ensure status value is valid (OPEN, IN_PROGRESS, RESOLVED, CLOSED)

## Future Enhancements

Consider adding:

- Image/evidence upload for reprocessing requests
- Real-time reprocessing request status notifications
- Reprocessing request search functionality
- Export reprocessing requests to PDF
- Reprocessing request templates for common issues
- Rating system for reprocessing request resolution
- Push notifications for status changes

---

For questions or issues, contact the development team.
