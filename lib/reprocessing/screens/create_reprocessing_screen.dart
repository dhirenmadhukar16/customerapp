import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/reprocessing.dart';
import '../services/reprocessing_service.dart';

class CreateReprocessingScreen extends StatefulWidget {
  final String customerId;
  final String? orderId;
  final VoidCallback? onReprocessingCreated;

  const CreateReprocessingScreen({
    super.key,
    required this.customerId,
    this.orderId,
    this.onReprocessingCreated,
  });

  @override
  State<CreateReprocessingScreen> createState() =>
      _CreateReprocessingScreenState();
}

class _CreateReprocessingScreenState extends State<CreateReprocessingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.orderId != null && widget.orderId!.trim().isNotEmpty) {
      _orderIdController.text = widget.orderId!.trim();
    }
  }

  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'POOR_WASHING';
  String _selectedPriority = 'LOW';
  bool _isLoading = false;
  XFile? _photo;

  Future<void> _pickPhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  final List<String> _categories = [
    'POOR_WASHING',
    'DAMAGED_ITEM',
    'MISSING_ITEM',
    'LATE_DELIVERY',
    'INCORRECT_ORDER',
    'QUALITY_ISSUE',
    'OTHER',
  ];

  final List<String> _priorities = ['LOW', 'MEDIUM', 'HIGH'];

  @override
  void dispose() {
    _orderIdController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool _isValidUuid(String value) {
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(value.trim());
  }

  void _submitReprocessing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a garment photo.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final orderId = (widget.orderId ?? _orderIdController.text.trim()).trim();
      if (!_isValidUuid(orderId)) {
        throw Exception(
          'Use the actual backend Order UUID, not the visible order number such as WF-... or #1233344.',
        );
      }

      final request = CreateReprocessingRequest(
        orderId: orderId,
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        priority: _selectedPriority,
      );

      final reprocessing = await ReprocessingService.createReprocessing(
        widget.customerId,
        request,
      );

      if (_photo != null) {
        await ReprocessingService.uploadReprocessingPhoto(
          customerId: widget.customerId,
          reprocessingId: reprocessing.id,
          fileBytes: await _photo!.readAsBytes(),
          fileName: _photo!.name,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reprocessing request created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onReprocessingCreated?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Reprocessing Request'),
        elevation: 0,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFC107)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFF57C00)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Reprocessing requests are accepted only within 7 days of the delivery date.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Order ID field
              Text(
                'Order UUID *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _orderIdController,
                readOnly:
                    widget.orderId != null && widget.orderId!.trim().isNotEmpty,
                decoration: InputDecoration(
                  hintText: 'Enter the real order UUID (not order number)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.shopping_bag),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Order UUID is required';
                  }
                  if (!_isValidUuid(value!)) {
                    return 'Use the actual backend order UUID, not the order number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Category dropdown
              Text(
                'Category *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.replaceAll('_', ' ')),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Priority dropdown
              Text(
                'Priority *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.flag),
                ),
                items: _priorities.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Text(priority),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPriority = value);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Subject field
              Text(
                'Subject *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  hintText: 'Brief subject of reprocessing request',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.subject),
                ),
                maxLength: 100,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Subject is required';
                  }
                  if (value!.length < 5) {
                    return 'Subject must be at least 5 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Description field
              Text(
                'Description *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: 'Provide detailed description of the issue',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 6,
                maxLength: 500,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Description is required';
                  }
                  if (value!.length < 10) {
                    return 'Description must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              Text(
                'Garment photo *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(_photo == null ? 'Upload photo' : _photo!.name),
              ),
              if (_photo != null)
                TextButton.icon(
                  onPressed:
                      _isLoading ? null : () => setState(() => _photo = null),
                  icon: const Icon(Icons.close),
                  label: const Text('Remove photo'),
                ),
              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReprocessing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    disabledBackgroundColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit Reprocessing Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6C63FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
