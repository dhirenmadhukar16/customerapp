import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/realtime/realtime_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'dart:convert';

class CustomerOrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isBooking;

  const CustomerOrderTrackingScreen({
    super.key,
    required this.data,
    required this.isBooking,
  });

  @override
  State<CustomerOrderTrackingScreen> createState() =>
      _CustomerOrderTrackingScreenState();
}

class _CustomerOrderTrackingScreenState
    extends State<CustomerOrderTrackingScreen> {
  late Map<String, dynamic> currentData;
  final RealtimeService _realtimeService = RealtimeService();
  bool _isLoading = false;

  StompClient? stompClient;
  LatLng? riderLocation;
  GoogleMapController? _trackingMapController;

  @override
  void initState() {
    super.initState();
    currentData = widget.data;
    _initRealtime();
    _initStomp();
  }

  void _initStomp() {
    final socketUrl = '${ApiClient.websocketBaseUrl}/ws-whitefox/websocket';

    stompClient = StompClient(
      config: StompConfig(
        url: socketUrl,
        onConnect: (StompFrame frame) {
          stompClient?.subscribe(
            destination: '/topic/location',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                final data = json.decode(frame.body!);
                // Only update if it's the rider assigned to this order
                if (currentData['riderId'] != null &&
                    data['entityId'].toString() ==
                        currentData['riderId'].toString()) {
                  if (mounted) {
                    final nextLocation = LatLng(
                        (data['latitude'] as num).toDouble(),
                        (data['longitude'] as num).toDouble());
                    setState(() {
                      riderLocation = nextLocation;
                    });
                    _trackingMapController?.animateCamera(
                      CameraUpdate.newLatLng(nextLocation),
                    );
                  }
                }
              }
            },
          );
        },
        onWebSocketError: (dynamic error) => print(error.toString()),
      ),
    );
    stompClient?.activate();
  }

  Future<void> _initRealtime() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('userId');
    if (customerId != null) {
      _realtimeService.connectForCustomer(
        customerId: customerId,
        onEvent: _handleEvent,
      );
    }
  }

  void _handleEvent(Map<String, dynamic> event) {
    if (event['referenceId'] == currentData['id']) {
      _fetchLatestOrder();
    }
  }

  Future<void> _fetchLatestOrder() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.dio.get('/api/orders/${currentData['id']}');
      if (mounted) {
        setState(() {
          currentData = res.data;
        });
      }
    } catch (e) {
      print('Error refreshing order: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showChangeDeliveryTypeDialog() async {
    String selectedType = currentData['deliveryType'] == 'SELF_PICKUP'
        ? 'RIDER_DELIVERY'
        : 'SELF_PICKUP';

    final bool? confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Change Delivery Type'),
              content: Text(
                  'Are you sure you want to change the delivery type to ${selectedType == 'SELF_PICKUP' ? 'Self Pickup' : 'Rider Delivery'}?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm')),
              ],
            ));

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final res = await ApiClient.dio.patch(
            '/api/orders/${currentData['id']}/delivery-type?deliveryType=$selectedType');
        setState(() {
          currentData = res.data;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Delivery type updated successfully.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed to update: $e'),
              backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelOrder() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final customerId =
            currentData['customerId'] ?? currentData['customer']?['id'];
        await ApiClient.dio.patch(
            '/api/customer-app/customers/$customerId/orders/${currentData['id']}/cancel');
        await _fetchLatestOrder();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order cancelled successfully.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed to cancel: $e'),
              backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showRateReviewDialog() async {
    int storeRating = 5;
    int riderRating = 5;
    int overallRating = 5;
    final feedbackController = TextEditingController();

    final bool? confirm = await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget starRow(
                String title, int currentRating, Function(int) onChanged) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < currentRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () => onChanged(index + 1),
                      );
                    }),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Rate Your Experience'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    starRow('Overall Rating', overallRating,
                        (r) => setDialogState(() => overallRating = r)),
                    if (currentData['storeId'] != null ||
                        currentData['store'] != null)
                      starRow('Store Rating', storeRating,
                          (r) => setDialogState(() => storeRating = r)),
                    if (currentData['riderId'] != null ||
                        currentData['rider'] != null)
                      starRow('Rider Rating', riderRating,
                          (r) => setDialogState(() => riderRating = r)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: feedbackController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Feedback (Optional)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final payload = {
          'customerId':
              currentData['customerId'] ?? currentData['customer']?['id'],
          'orderId': currentData['id'],
          'storeId': currentData['storeId'] ?? currentData['store']?['id'],
          'riderId': currentData['riderId'] ?? currentData['rider']?['id'],
          'storeRating': storeRating,
          'riderRating': riderRating,
          'overallRating': overallRating,
          'feedback': feedbackController.text,
        };
        await ApiClient.dio.post('/api/customer-reviews', data: payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Review submitted successfully.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed to submit review: $e'),
              backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _realtimeService.disconnect();
    stompClient?.deactivate();
    _trackingMapController?.dispose();
    super.dispose();
  }

  List<String> get steps {
    if (widget.isBooking) {
      return [
        'REQUESTED',
        'STORE_ASSIGNED',
        'RIDER_ASSIGNED',
        'RIDER_ON_THE_WAY',
        'RIDER_REACHED',
        'PICKUP_BILL_CREATED',
      ];
    } else {
      final isPickup =
          currentData['deliveryType']?.toString() == 'CUSTOMER_PICKUP';

      List<String> processingSteps = [];
      if (currentData['items'] != null &&
          (currentData['items'] as List).isNotEmpty) {
        bool hasWash = false;
        bool hasIron = false;
        bool hasDryClean = false;
        for (var item in currentData['items']) {
          final service = item['serviceType']?.toString().toUpperCase() ?? '';
          if (service.contains('WASH')) hasWash = true;
          if (service.contains('IRON')) hasIron = true;
          if (service.contains('DRY CLEAN')) hasDryClean = true;
        }
        if (hasWash) processingSteps.add('WASHING');
        if (hasDryClean) processingSteps.add('DRY_CLEANING');
        if (hasIron) processingSteps.add('IRONING');
      }
      if (processingSteps.isEmpty) {
        processingSteps = ['PROCESSING'];
      }

      return [
        'CREATED',
        'RECEIVED_AT_STORE',
        'SENT_TO_HQ',
        'RECEIVED_AT_HQ',
        ...processingSteps,
        'READY_FOR_DISPATCH_TO_STORE',
        'RECEIVED_AT_STORE_AFTER_PROCESSING',
        if (isPickup) 'READY_FOR_CUSTOMER_PICKUP' else 'READY_FOR_DELIVERY',
        if (!isPickup) 'ASSIGNED_FOR_DELIVERY',
        if (!isPickup) 'OUT_FOR_DELIVERY',
        'DELIVERED',
        if (currentData['status'] == 'CANCELLED') 'CANCELLED',
      ];
    }
  }

  int currentIndex(String status) {
    if (status == 'PROCESSING') {
      // Find the first processing step
      final processingSteps = steps
          .where((s) => s == 'WASHING' || s == 'DRY_CLEANING' || s == 'IRONING')
          .toList();
      if (processingSteps.isNotEmpty) {
        status = processingSteps.first;
      }
    }
    if (status == 'PACKING') status = 'READY_FOR_DISPATCH_TO_STORE';

    final index = steps.indexOf(status);
    // If not found, try to find the closest match or default to a reasonable state
    if (index < 0) {
      if (status == 'PICKUP_ASSIGNED' || status == 'PICKED_UP') return 0;
      return 0;
    }
    return index;
  }

  String title(String status) {
    return status.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final status = currentData['status']?.toString() ?? steps.first;
    final activeIndex = currentIndex(status);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              widget.isBooking ? 'Track Pickup' : 'Track Order',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            if (_isLoading) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ]
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isBooking
                      ? 'Pickup Booking'
                      : currentData['orderNumber']?.toString() ?? 'Order',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Status: ${title(status)}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isBooking
                      ? 'Pickup: ${currentData['pickupDate'] ?? '-'} • ${currentData['pickupTimeSlot'] ?? '-'}'
                      : 'Amount: ₹${currentData['totalAmount'] ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (status == 'CREATED' || status == 'REQUESTED') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _cancelOrder,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Cancel Order',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
          if (status == 'DELIVERED') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showRateReviewDialog,
                child: const Text('Rate & Review Experience'),
              ),
            ),
          ],
          if (!widget.isBooking) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Delivery Type',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                          currentData['deliveryType'] == 'SELF_PICKUP'
                              ? 'Self Pickup'
                              : 'Rider Delivery',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary)),
                    ],
                  ),
                  // Only allow change if status is before READY_FOR_...
                  if (activeIndex <= 7) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _showChangeDeliveryTypeDialog,
                        child: const Text('Change Delivery Type'),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],
          if ((status == 'OUT_FOR_DELIVERY' ||
                  status == 'ASSIGNED_FOR_DELIVERY' ||
                  status == 'READY_FOR_CUSTOMER_PICKUP' ||
                  status == 'RECEIVED_AT_STORE_AFTER_PROCESSING') &&
              currentData['deliveryOtp'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.deepOrange.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('Pickup/Delivery OTP',
                      style: TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    currentData['deliveryOtp'].toString(),
                    style: const TextStyle(
                        fontSize: 32,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w900,
                        color: Colors.deepOrange),
                  ),
                  const SizedBox(height: 4),
                  const Text('Share this with the rider',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
          if (currentData['riderId'] != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: riderLocation ?? const LatLng(28.6139, 77.2090),
                    zoom: 14,
                  ),
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  onMapCreated: (controller) =>
                      _trackingMapController = controller,
                  markers: riderLocation == null
                      ? <Marker>{}
                      : {
                          Marker(
                            markerId: const MarkerId('rider-location'),
                            position: riderLocation!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            ),
                            infoWindow: const InfoWindow(title: 'Your rider'),
                          ),
                        },
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Text(
            'Live Progress',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;

            final completed = index <= activeIndex;
            final current = index == activeIndex;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          completed ? AppTheme.primary : Colors.grey.shade300,
                      child: Icon(
                        completed ? Icons.check : Icons.circle,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    if (index != steps.length - 1)
                      Container(
                        width: 3,
                        height: 50,
                        color:
                            completed ? AppTheme.primary : Colors.grey.shade300,
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: current
                            ? AppTheme.primary.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                    ),
                    child: Text(
                      title(step),
                      style: TextStyle(
                        fontWeight: current ? FontWeight.w900 : FontWeight.w700,
                        color: current ? AppTheme.primary : AppTheme.darkText,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
