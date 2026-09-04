import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reprocessing.dart';
import '../services/reprocessing_service.dart';

class ReprocessingDetailScreen extends StatefulWidget {
  final String customerId;
  final String reprocessingId;
  final Reprocessing? reprocessing;

  const ReprocessingDetailScreen({
    super.key,
    required this.customerId,
    required this.reprocessingId,
    this.reprocessing,
  });

  @override
  State<ReprocessingDetailScreen> createState() =>
      _ReprocessingDetailScreenState();
}

class _ReprocessingDetailScreenState extends State<ReprocessingDetailScreen> {
  late Future<Reprocessing> _reprocessingFuture;
  late Future<List<ReprocessingHistory>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _reprocessingFuture = widget.reprocessing != null
        ? Future.value(widget.reprocessing!)
        : ReprocessingService.getCustomerReprocessingDetail(
            widget.customerId, widget.reprocessingId);
    _historyFuture = ReprocessingService.getCustomerReprocessingHistory(
      widget.customerId,
      widget.reprocessingId,
    );
  }

  String _getStatusColor(String status) {
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

  String _getPriorityColor(String priority) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reprocessing Details'),
        elevation: 0,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Reprocessing>(
        future: _reprocessingFuture,
        builder: (context, reprocessingSnapshot) {
          if (reprocessingSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6C63FF),
              ),
            );
          }

          if (reprocessingSnapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${reprocessingSnapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                    ),
                    child: const Text(
                      'Go Back',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }

          final reprocessing = reprocessingSnapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reprocessing header card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reprocessing #${reprocessing.orderNumber}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child:
                                _buildInfoItem('Store', reprocessing.storeName),
                          ),
                          Expanded(
                            child: _buildInfoItem(
                                'Order', reprocessing.orderNumber),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              'Created',
                              DateFormat('MMM dd, yyyy')
                                  .format(reprocessing.createdAt),
                            ),
                          ),
                          Expanded(
                            child: _buildInfoItem(
                              'Updated',
                              DateFormat('MMM dd, yyyy')
                                  .format(reprocessing.updatedAt),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Status and Priority section
                Text(
                  'Status & Priority',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusCard(
                        'Status',
                        reprocessing.status,
                        reprocessing.statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatusCard(
                        'Priority',
                        reprocessing.priority,
                        reprocessing.priorityColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Category section
                Text(
                  'Category',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reprocessing.category.replaceAll('_', ' '),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Description section
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reprocessing.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // History section
                Text(
                  'Activity History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<ReprocessingHistory>>(
                  future: _historyFuture,
                  builder: (context, historySnapshot) {
                    if (historySnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6C63FF),
                        ),
                      );
                    }

                    if (historySnapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Failed to load history',
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      );
                    }

                    if (!historySnapshot.hasData ||
                        historySnapshot.data!.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'No activity history',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: historySnapshot.data!.length,
                      itemBuilder: (context, index) {
                        final history = historySnapshot.data![index];
                        return _buildHistoryItem(history);
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String label, String value, String color) {
    final colorMap = {
      'Green': const Color(0xFF4CAF50),
      'Orange': const Color(0xFFFFA500),
      'Red': const Color(0xFFF44336),
      'Blue': const Color(0xFF2196F3),
      'Gray': const Color(0xFF9E9E9E),
    };

    final statusColor = colorMap[color] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.replaceAll('_', ' '),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(ReprocessingHistory history) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                history.action,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                DateFormat('MMM dd, HH:mm').format(history.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${history.oldStatus} → ${history.newStatus}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          if (history.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              history.description,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'By: ${history.performedBy}',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
