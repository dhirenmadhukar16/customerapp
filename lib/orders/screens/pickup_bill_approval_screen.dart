import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

class PickupBillApprovalScreen extends StatefulWidget {
  final String pickupBillId;

  const PickupBillApprovalScreen({super.key, required this.pickupBillId});

  @override
  State<PickupBillApprovalScreen> createState() =>
      _PickupBillApprovalScreenState();
}

class _PickupBillApprovalScreenState extends State<PickupBillApprovalScreen> {
  bool loading = true;
  Map<String, dynamic>? bill;

  @override
  void initState() {
    super.initState();
    _fetchBill();
  }

  Future<void> _fetchBill() async {
    try {
      final res =
          await ApiClient.dio.get('/api/pickup-bills/${widget.pickupBillId}');
      setState(() {
        bill = res.data;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load bill: $e')),
        );
        setState(() => loading = false);
      }
    }
  }

  Future<void> _approve() async {
    try {
      setState(() => loading = true);
      await ApiClient.dio
          .patch('/api/pickup-bills/${widget.pickupBillId}/customer-approve');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Pickup Bill Approved! Rider will collect the clothes.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving: $e')),
        );
        setState(() => loading = false);
      }
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reject Pricing'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
              hintText: 'Reason for rejection (e.g., price too high)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, reasonController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      try {
        setState(() => loading = true);
        await ApiClient.dio.patch(
          '/api/pickup-bills/${widget.pickupBillId}/customer-reject',
          data: {'reason': reason},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Pickup Bill Rejected. Rider will return your clothes.')),
          );
          Navigator.pop(context, false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error rejecting: $e')),
          );
          setState(() => loading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Pickup Bill',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : bill == null
              ? const Center(child: Text('Failed to load.'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final items = List.from(bill!['items'] ?? []);
    final total = bill!['totalAmount'] ?? 0.0;
    final subtotal = bill!['subtotal'] ?? 0.0;
    final gst = bill!['gst'] ?? 0.0;

    return Column(
      children: [
        Container(
          color: Colors.blue.withValues(alpha: 0.1),
          padding: const EdgeInsets.all(16),
          child: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'The rider has inspected your clothes and finalized the pricing. Please review and approve to proceed.',
                  style: TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isAdjusted = item['priceAdjusted'] == true;
              final originalPrice = item['originalUnitPrice'] ?? 0.0;
              final newPrice = item['unitPrice'] ?? 0.0;
              final qty = item['quantity'] ?? 0;

              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item['itemName']} (${item['serviceType']})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Text(
                            'Qty: $qty',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Original Est.:',
                              style: TextStyle(color: Colors.grey)),
                          Text('₹$originalPrice',
                              style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Final Price:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('₹$newPrice',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isAdjusted
                                      ? Colors.orange
                                      : AppTheme.primary,
                                  fontSize: 16)),
                        ],
                      ),
                      if (isAdjusted &&
                          item['priceAdjustmentReason'] != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.edit_note,
                                  size: 16, color: Colors.orange),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Reason: ${item['priceAdjustmentReason']}',
                                  style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5))
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:', style: TextStyle(color: Colors.grey)),
                  Text('₹${subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('GST (18%):',
                      style: TextStyle(color: Colors.grey)),
                  Text('₹${gst.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand Total:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Reject',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _approve,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('Accept & Proceed',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
