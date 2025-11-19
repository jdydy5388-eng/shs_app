import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/invoice_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';
import '../admin/invoice_details_screen.dart';

class PatientInvoicesScreen extends StatefulWidget {
  const PatientInvoicesScreen({super.key});

  @override
  State<PatientInvoicesScreen> createState() => _PatientInvoicesScreenState();
}

class _PatientInvoicesScreenState extends State<PatientInvoicesScreen> {
  final DataService _dataService = DataService();
  List<InvoiceModel> _invoices = [];
  bool _isLoading = true;
  InvoiceStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final user = AuthHelper.getCurrentUser(context);
      if (user == null) return;

      final invoices = await _dataService.getInvoices(patientId: user.id, status: _filterStatus);
      setState(() {
        _invoices = invoices.cast<InvoiceModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الفواتير: $e')),
        );
      }
    }
  }

  Map<String, dynamic> get _summary {
    final total = _invoices.length;
    final paid = _invoices.where((i) => i.status == InvoiceStatus.paid).length;
    final issued = _invoices.where((i) => i.status == InvoiceStatus.issued).length;
    final totalAmount = _invoices.fold(0.0, (sum, i) => sum + i.total);
    final paidAmount = _invoices
        .where((i) => i.status == InvoiceStatus.paid)
        .fold(0.0, (sum, i) => sum + i.total);
    final pendingAmount = _invoices
        .where((i) => i.status == InvoiceStatus.issued)
        .fold(0.0, (sum, i) => sum + i.total);

    return {
      'total': total,
      'paid': paid,
      'issued': issued,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'pendingAmount': pendingAmount,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فواتيري'),
        actions: [
          PopupMenuButton<InvoiceStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterStatus = value);
              _loadInvoices();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('جميع الفواتير'),
              ),
              const PopupMenuItem(
                value: InvoiceStatus.issued,
                child: Text('صادرة'),
              ),
              const PopupMenuItem(
                value: InvoiceStatus.paid,
                child: Text('مدفوعة'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInvoices,
              child: Column(
                children: [
                  _buildSummary(),
                  Expanded(child: _buildInvoicesList()),
                ],
              ),
            ),
    );
  }

  Widget _buildSummary() {
    final summary = _summary;
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س', decimalDigits: 2);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'المستحق',
                  currencyFormat.format(summary['pendingAmount']),
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'المدفوع',
                  currencyFormat.format(summary['paidAmount']),
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesList() {
    if (_invoices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد فواتير',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final invoice = _invoices[index];
        return _buildInvoiceCard(invoice);
      },
    );
  }

  Widget _buildInvoiceCard(InvoiceModel invoice) {
    final statusColor = {
      InvoiceStatus.draft: Colors.grey,
      InvoiceStatus.issued: Colors.orange,
      InvoiceStatus.paid: Colors.green,
      InvoiceStatus.cancelled: Colors.red,
    }[invoice.status]!;

    final statusText = {
      InvoiceStatus.draft: 'مسودة',
      InvoiceStatus.issued: 'صادرة',
      InvoiceStatus.paid: 'مدفوعة',
      InvoiceStatus.cancelled: 'ملغاة',
    }[invoice.status]!;

    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س', decimalDigits: 2);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.receipt, color: statusColor),
        ),
        title: Text(
          'فاتورة #${invoice.id.substring(0, 8).toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التاريخ: ${dateFormat.format(invoice.createdAt)}'),
            Text('المبلغ: ${currencyFormat.format(invoice.total)}'),
            if (invoice.insuranceProvider != null)
              Text('التأمين: ${invoice.insuranceProvider}'),
          ],
        ),
        trailing: Chip(
          label: Text(statusText, style: const TextStyle(fontSize: 12)),
          backgroundColor: statusColor.withValues(alpha: 0.2),
          labelStyle: TextStyle(color: statusColor),
        ),
        onTap: () => _viewInvoiceDetails(invoice),
      ),
    );
  }

  void _viewInvoiceDetails(InvoiceModel invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceDetailsScreen(invoice: invoice),
      ),
    ).then((_) => _loadInvoices());
  }
}

