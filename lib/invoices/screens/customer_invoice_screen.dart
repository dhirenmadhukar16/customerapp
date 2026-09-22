import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../model/invoice_model.dart';
import '../services/invoice_service.dart';

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
  final InvoiceService _invoiceService = const InvoiceService();

  InvoiceModel? _invoice;
  bool _loading = true;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final invoice = await _invoiceService.getInvoiceByOrder(widget.orderId);

      if (!mounted) return;
      setState(() => _invoice = invoice);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<File> _downloadToDevice() async {
    final invoice = _invoice;
    if (invoice == null) {
      throw const InvoiceServiceException('Invoice is not available.');
    }

    final bytes = await _invoiceService.downloadPaidInvoice(invoice);
    final directory = await getApplicationDocumentsDirectory();
    final safeNumber = invoice.invoiceNumber.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    final file = File('${directory.path}/$safeNumber.pdf');

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _openPdf() async {
    await _runAction(() async {
      final file = await _downloadToDevice();
      final result = await OpenFilex.open(file.path);

      if (result.type != ResultType.done) {
        throw InvoiceServiceException(
          result.message.isEmpty
              ? 'Could not open the downloaded invoice.'
              : result.message,
        );
      }
    });
  }

  Future<void> _sharePdf() async {
    await _runAction(() async {
      final invoice = _invoice!;
      final file = await _downloadToDevice();

      await Share.shareXFiles(
        <XFile>[XFile(file.path)],
        text: 'WhiteFox invoice ${invoice.invoiceNumber}',
        subject: 'WhiteFox invoice ${invoice.invoiceNumber}',
      );
    });
  }

  Future<void> _emailPdf() async {
    await _runAction(() async {
      await _invoiceService.emailPaidInvoice(_invoice!);
      await _loadInvoice();
      _showMessage('Invoice sent to your registered email.');
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_processing) return;

    setState(() => _processing = true);

    try {
      await action();
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : AppTheme.primary,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Invoice'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh invoice',
            onPressed: _loading ? null : _loadInvoice,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInvoice,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const SizedBox(height: 100),
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.mutedText),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: _loadInvoice,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ),
        ],
      );
    }

    final invoice = _invoice;
    if (invoice == null) {
      return const Center(child: Text('Invoice not found.'));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: <Widget>[
        _InvoiceHeader(invoice: invoice),
        const SizedBox(height: 14),
        _PaymentSummary(invoice: invoice),
        const SizedBox(height: 14),
        _DetailsCard(invoice: invoice),
        const SizedBox(height: 14),
        if (!invoice.canDownload) _LockedInvoiceNotice(invoice: invoice),
        if (!invoice.canDownload) const SizedBox(height: 14),
        _buildActions(invoice),
      ],
    );
  }

  Widget _buildActions(InvoiceModel invoice) {
    final enabled = invoice.canDownload && !_processing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: enabled ? _openPdf : null,
            icon: _processing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              invoice.canDownload
                  ? 'Download / Open Invoice'
                  : 'Available After Full Payment',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: enabled ? _sharePdf : null,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: enabled ? _emailPdf : null,
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Email'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InvoiceHeader extends StatelessWidget {
  final InvoiceModel invoice;

  const _InvoiceHeader({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(invoice.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF064E3B), Color(0xFF0F8C48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _statusLabel(invoice.status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            invoice.invoiceNumber.isEmpty
                ? 'WhiteFox Invoice'
                : invoice.invoiceNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Order ${invoice.orderNumber.isEmpty ? invoice.orderId : invoice.orderNumber}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  final InvoiceModel invoice;

  const _PaymentSummary({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Payment summary',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            _amountRow('Invoice total', invoice.totalAmount),
            const SizedBox(height: 10),
            _amountRow(
              'Amount paid',
              invoice.paidAmount,
              color: AppTheme.primary,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            _amountRow(
              'Balance due',
              invoice.remainingAmount,
              color: invoice.remainingAmount > 0
                  ? Colors.orange.shade800
                  : AppTheme.primary,
              bold: true,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: invoice.paymentProgress,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(invoice.paymentProgress * 100).round()}% paid',
              style: const TextStyle(
                color: AppTheme.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(
    String label,
    double value, {
    Color? color,
    bool bold = false,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(label, style: const TextStyle(color: AppTheme.mutedText)),
        ),
        Text(
          _currency(value),
          style: TextStyle(
            color: color ?? AppTheme.darkText,
            fontSize: bold ? 18 : 15,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final InvoiceModel invoice;

  const _DetailsCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            _detail('Customer', invoice.customerName ?? '-'),
            _detail('Service store', invoice.storeName ?? '-'),
            _detail('Subtotal', _currency(invoice.subtotal)),
            _detail('GST', _currency(invoice.gst)),
            _detail('Payment method', invoice.paymentMethod ?? '-'),
            _detail('Payment reference', invoice.paymentReference ?? '-'),
            _detail('Generated on', _date(invoice.generatedAt)),
            if (invoice.paidAt != null)
              _detail('Fully paid on', _date(invoice.paidAt)),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.mutedText),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedInvoiceNotice extends StatelessWidget {
  final InvoiceModel invoice;

  const _LockedInvoiceNotice({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final cancelled = invoice.isCancelled;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cancelled ? Colors.red.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cancelled ? Colors.red.shade200 : Colors.amber.shade300,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            cancelled ? Icons.cancel_outlined : Icons.lock_outline_rounded,
            color: cancelled ? Colors.red.shade700 : Colors.amber.shade900,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              cancelled
                  ? 'This invoice belongs to a cancelled order.'
                  : 'The invoice is visible now, but PDF download, sharing and email will be enabled only after full payment.',
              style: TextStyle(
                color: cancelled ? Colors.red.shade900 : Colors.amber.shade900,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _currency(double value) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(value);
}

String _date(DateTime? value) {
  if (value == null) return '-';
  return DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());
}

String _statusLabel(String status) {
  switch (status) {
    case 'PARTIALLY_PAID':
      return 'PARTIALLY PAID';
    case 'PAID':
      return 'PAID';
    case 'CANCELLED':
      return 'CANCELLED';
    default:
      return 'PAYMENT PENDING';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'PAID':
      return const Color(0xFF16A34A);
    case 'PARTIALLY_PAID':
      return const Color(0xFFEA580C);
    case 'CANCELLED':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFFCA8A04);
  }
}
