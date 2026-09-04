import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

class CustomerInvoiceScreen extends StatefulWidget {
  final String orderId;

  const CustomerInvoiceScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<CustomerInvoiceScreen> createState() => _CustomerInvoiceScreenState();
}

class _CustomerInvoiceScreenState extends State<CustomerInvoiceScreen> {
  bool loading = true;
  bool downloading = false;
  String? error;
  Map<String, dynamic>? invoice;

  @override
  void initState() {
    super.initState();
    loadInvoice();
  }

  Future<void> loadInvoice() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });

      final response = await ApiClient.dio.get(
        '/api/invoices/orders/${widget.orderId}',
      );

      setState(() {
        invoice = Map<String, dynamic>.from(response.data);
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<File> downloadPdfFile() async {
    final invoiceId = invoice!['id'];
    final invoiceNumber = invoice!['invoiceNumber'] ?? 'invoice';

    final response = await ApiClient.dio.get(
      '/api/invoices/$invoiceId/pdf',
      options: Options(responseType: ResponseType.bytes),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$invoiceNumber.pdf');

    await file.writeAsBytes(response.data);
    return file;
  }

  Future<void> openPdf() async {
    if (invoice == null) return;

    try {
      setState(() => downloading = true);

      final file = await downloadPdfFile();
      await OpenFilex.open(file.path);
    } catch (e) {
      showError('PDF download failed: $e');
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  Future<void> sharePdf() async {
    if (invoice == null) return;

    try {
      setState(() => downloading = true);

      final file = await downloadPdfFile();
      final invoiceNumber = invoice!['invoiceNumber'] ?? 'invoice';

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'WhiteFox Laundry Invoice $invoiceNumber',
      );
    } catch (e) {
      showError('Share failed: $e');
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  void showError(Object e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget info(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(title, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String amount(dynamic value) {
    final number = value is num ? value.toDouble() : 0.0;
    return '₹${number.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final inv = invoice;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Invoice',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(onPressed: loadInvoice, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : inv == null
                  ? const Center(child: Text('Invoice not found'))
                  : ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.receipt_long,
                                  size: 46,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  inv['invoiceNumber'] ?? 'Invoice',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                info('Order No', inv['orderNumber'] ?? '-'),
                                info('Customer', inv['customerName'] ?? '-'),
                                info('Subtotal', amount(inv['subtotal'])),
                                info('GST', amount(inv['gst'])),
                                const Divider(),
                                info('Total', amount(inv['totalAmount'])),
                                info('Generated', inv['generatedAt'] ?? '-'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: downloading ? null : openPdf,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: downloading
                                ? const Text('Processing...')
                                : const Text('Download / Open Invoice'),
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: downloading ? null : sharePdf,
                            icon: const Icon(Icons.share),
                            label: const Text('Share Invoice'),
                          ),
                        ),
                      ],
                    ),
    );
  }
}