import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../model/invoice_model.dart';
import '../services/invoice_service.dart';
import 'customer_invoice_screen.dart';

class CustomerInvoicesScreen extends StatefulWidget {
  const CustomerInvoicesScreen({super.key});

  @override
  State<CustomerInvoicesScreen> createState() => _CustomerInvoicesScreenState();
}

class _CustomerInvoicesScreenState extends State<CustomerInvoicesScreen> {
  final InvoiceService _invoiceService = const InvoiceService();

  List<InvoiceModel> _invoices = const <InvoiceModel>[];
  String _selectedFilter = 'ALL';
  bool _loading = true;
  String? _error;

  static const List<_InvoiceFilter> _filters = <_InvoiceFilter>[
    _InvoiceFilter('ALL', 'All'),
    _InvoiceFilter('GENERATED', 'Pending'),
    _InvoiceFilter('PARTIALLY_PAID', 'Partial'),
    _InvoiceFilter('PAID', 'Paid'),
    _InvoiceFilter('CANCELLED', 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  List<InvoiceModel> get _visibleInvoices {
    if (_selectedFilter == 'ALL') return _invoices;

    return _invoices
        .where((invoice) => invoice.status == _selectedFilter)
        .toList(growable: false);
  }

  Future<void> _loadInvoices() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final invoices = await _invoiceService.getMyInvoices();

      invoices.sort((first, second) {
        final firstDate =
            first.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final secondDate =
            second.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return secondDate.compareTo(firstDate);
      });

      if (!mounted) return;
      setState(() => _invoices = invoices);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openInvoice(InvoiceModel invoice) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerInvoiceScreen(orderId: invoice.orderId),
      ),
    );

    if (mounted) await _loadInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Invoices'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh invoices',
            onPressed: _loading ? null : _loadInvoices,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInvoices,
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
          const SizedBox(height: 90),
          Icon(
            Icons.cloud_off_rounded,
            size: 66,
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
              onPressed: _loadInvoices,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(child: _buildSummary()),
        SliverToBoxAdapter(child: _buildFilters()),
        if (_visibleInvoices.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyInvoices(filter: _selectedFilter),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            sliver: SliverList.separated(
              itemCount: _visibleInvoices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 11),
              itemBuilder: (context, index) {
                final invoice = _visibleInvoices[index];
                return _InvoiceCard(
                  invoice: invoice,
                  onTap: () => _openInvoice(invoice),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSummary() {
    final totalPaid = _invoices
        .where((invoice) => !invoice.isCancelled)
        .fold<double>(0, (total, invoice) => total + invoice.paidAmount);

    final totalDue = _invoices
        .where((invoice) => !invoice.isCancelled)
        .fold<double>(0, (total, invoice) => total + invoice.remainingAmount);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
          const Text(
            'Invoice centre',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Track every bill and payment in one place.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryItem(
                  label: 'Paid',
                  value: _currency(totalPaid),
                  icon: Icons.verified_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryItem(
                  label: 'Balance due',
                  value: _currency(totalDue),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = filter.status == _selectedFilter;
          final count = filter.status == 'ALL'
              ? _invoices.length
              : _invoices
                  .where((invoice) => invoice.status == filter.status)
                  .length;

          return ChoiceChip(
            selected: selected,
            onSelected: (_) {
              setState(() => _selectedFilter = filter.status);
            },
            label: Text('${filter.label}  $count'),
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppTheme.darkText,
              fontWeight: FontWeight.w800,
            ),
            selectedColor: AppTheme.primary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? AppTheme.primary : Colors.grey.shade200,
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 21),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onTap;

  const _InvoiceCard({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(invoice.status);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          invoice.invoiceNumber.isEmpty
                              ? 'Invoice'
                              : invoice.invoiceNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order ${invoice.orderNumber.isEmpty ? invoice.orderId : invoice.orderNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(invoice.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Divider(height: 1),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _CardValue(
                      label: 'Invoice total',
                      value: _currency(invoice.totalAmount),
                    ),
                  ),
                  Expanded(
                    child: _CardValue(
                      label: invoice.remainingAmount > 0 ? 'Balance' : 'Paid',
                      value: invoice.remainingAmount > 0
                          ? _currency(invoice.remainingAmount)
                          : _currency(invoice.paidAmount),
                      valueColor: invoice.remainingAmount > 0
                          ? Colors.orange.shade800
                          : AppTheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _CardValue(
                      label: 'Date',
                      value: _shortDate(invoice.generatedAt),
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(
                    invoice.canDownload
                        ? Icons.download_done_rounded
                        : Icons.lock_outline_rounded,
                    size: 17,
                    color: invoice.canDownload
                        ? AppTheme.primary
                        : AppTheme.mutedText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      invoice.canDownload
                          ? 'Final invoice available'
                          : 'PDF available after full payment',
                      style: TextStyle(
                        color: invoice.canDownload
                            ? AppTheme.primary
                            : AppTheme.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.mutedText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardValue extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool alignEnd;

  const _CardValue({
    required this.label,
    required this.value,
    this.valueColor,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: AppTheme.mutedText, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? AppTheme.darkText,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _EmptyInvoices extends StatelessWidget {
  final String filter;

  const _EmptyInvoices({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.receipt_long_outlined,
              size: 68,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 14),
            Text(
              filter == 'ALL'
                  ? 'No invoices yet'
                  : 'No ${_statusLabel(filter).toLowerCase()} invoices',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Invoices will appear here after an order is confirmed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceFilter {
  final String status;
  final String label;

  const _InvoiceFilter(this.status, this.label);
}

String _currency(double value) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  ).format(value);
}

String _shortDate(DateTime? value) {
  if (value == null) return '-';
  return DateFormat('dd MMM yy').format(value.toLocal());
}

String _statusLabel(String status) {
  switch (status) {
    case 'PARTIALLY_PAID':
      return 'PARTIAL';
    case 'PAID':
      return 'PAID';
    case 'CANCELLED':
      return 'CANCELLED';
    case 'GENERATED':
      return 'PENDING';
    default:
      return status.replaceAll('_', ' ');
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'PAID':
      return const Color(0xFF15803D);
    case 'PARTIALLY_PAID':
      return const Color(0xFFEA580C);
    case 'CANCELLED':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFFCA8A04);
  }
}
