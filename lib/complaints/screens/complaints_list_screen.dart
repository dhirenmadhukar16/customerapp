import 'package:flutter/material.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import 'complaint_detail_screen.dart';
import 'create_complaint_screen.dart';

class ComplaintsListScreen extends StatefulWidget {
  final String customerId;

  const ComplaintsListScreen({
    super.key,
    required this.customerId,
  });

  @override
  State<ComplaintsListScreen> createState() => _ComplaintsListScreenState();
}

class _ComplaintsListScreenState extends State<ComplaintsListScreen> {
  late Future<List<Complaint>> _complaintsFuture;
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _complaintsFuture =
        ComplaintService.getCustomerComplaints(widget.customerId);
  }

  void _refreshComplaints() {
    setState(() {
      _complaintsFuture =
          ComplaintService.getCustomerComplaints(widget.customerId);
    });
  }

  List<Complaint> _filterComplaints(List<Complaint> complaints) {
    if (_selectedFilter == 'ALL') {
      return complaints;
    }
    return complaints.where((c) => c.status == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Complaints'),
        elevation: 0,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CreateComplaintScreen(
                customerId: widget.customerId,
                onComplaintCreated: _refreshComplaints,
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF6C63FF),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('OPEN', 'Open'),
                  const SizedBox(width: 8),
                  _buildFilterChip('IN_PROGRESS', 'In Progress'),
                  const SizedBox(width: 8),
                  _buildFilterChip('RESOLVED', 'Resolved'),
                  const SizedBox(width: 8),
                  _buildFilterChip('CLOSED', 'Closed'),
                ],
              ),
            ),
          ),
          // Complaints list
          Expanded(
            child: FutureBuilder<List<Complaint>>(
              future: _complaintsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6C63FF),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshComplaints,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.sentiment_satisfied_alt,
                          size: 64,
                          color: Color(0xFF6C63FF),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No complaints yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create a complaint if you have any issues',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final filteredComplaints = _filterComplaints(snapshot.data!);

                if (filteredComplaints.isEmpty) {
                  return Center(
                    child: Text(
                      'No $_selectedFilter complaints',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFF6C63FF),
                  onRefresh: () async {
                    _refreshComplaints();
                    await _complaintsFuture;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredComplaints.length,
                    itemBuilder: (context, index) {
                      final complaint = filteredComplaints[index];
                      return _buildComplaintCard(context, complaint);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[200]!,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildComplaintCard(BuildContext context, Complaint complaint) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ComplaintDetailScreen(
              customerId: widget.customerId,
              complaintId: complaint.id,
              complaint: complaint,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with order number and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Order #${complaint.orderNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    complaint.formattedCreatedDate,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                complaint.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Status and Priority badges
              Row(
                children: [
                  _buildBadge(complaint.status, complaint.statusColor),
                  const SizedBox(width: 8),
                  _buildBadge(complaint.priority, complaint.priorityColor),
                  const SizedBox(width: 8),
                  if (complaint.category.isNotEmpty)
                    _buildBadge(complaint.category, 'Blue'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, String color) {
    final colorMap = {
      'Green': const Color(0xFF4CAF50),
      'Orange': const Color(0xFFFFA500),
      'Red': const Color(0xFFF44336),
      'Blue': const Color(0xFF2196F3),
      'Gray': const Color(0xFF9E9E9E),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (colorMap[color] ?? Colors.grey).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 11,
          color: colorMap[color] ?? Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
