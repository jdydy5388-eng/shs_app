import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/invoice_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';
import 'create_invoice_screen.dart';
import 'invoice_details_screen.dart';
import 'financial_reports_screen.dart';
import 'payments_management_screen.dart';

class BillingManagementScreen extends StatefulWidget {
  const BillingManagementScreen({super.key});

  @override
  State<BillingManagementScreen> createState() => _BillingManagementScreenState();
}

class _BillingManagementScreenState extends State<BillingManagementScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  List<InvoiceModel> _invoices = [];
  bool _isLoading = true;
  InvoiceStatus? _filterStatus;
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await _dataService.getInvoices(status: _filterStatus);
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

  List<InvoiceModel> get _filteredInvoices {
    var filtered = _invoices;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((invoice) {
        return invoice.patientName.toLowerCase().contains(query) ||
            invoice.id.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
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
        title: const Text('إدارة الفواتير والمدفوعات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الفواتير', icon: Icon(Icons.receipt)),
            Tab(text: 'الإحصائيات', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'status') {
                _showStatusFilter();
              } else if (value == 'clear') {
                setState(() => _filterStatus = null);
                _loadInvoices();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'status',
                child: Text('فلترة حسب الحالة'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('إزالة الفلاتر'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createNewInvoice(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoices,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInvoicesTab(),
          _buildStatisticsTab(),
        ],
      ),
    );
  }

  Widget _buildInvoicesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'بحث في الفواتير',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadInvoices,
                  child: _buildInvoicesList(),
                ),
        ),
      ],
    );
  }

  Widget _buildInvoicesList() {
    final filtered = _filteredInvoices;

    if (filtered.isEmpty) {
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
                _invoices.isEmpty
                    ? 'لا توجد فواتير'
                    : 'لا توجد فواتير تطابق البحث',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final invoice = filtered[index];
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
          invoice.patientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('رقم الفاتورة: ${invoice.id.substring(0, 8)}...'),
            Text('التاريخ: ${dateFormat.format(invoice.createdAt)}'),
            Text('المبلغ: ${currencyFormat.format(invoice.total)}'),
            if (invoice.insuranceProvider != null)
              Text('التأمين: ${invoice.insuranceProvider}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: Text(statusText, style: const TextStyle(fontSize: 12)),
              backgroundColor: statusColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: statusColor),
            ),
            if (invoice.status == InvoiceStatus.issued)
              TextButton(
                onPressed: () => _viewPayments(invoice),
                child: const Text('المدفوعات'),
              ),
          ],
        ),
        onTap: () => _viewInvoiceDetails(invoice),
      ),
    );
  }

  Widget _buildStatisticsTab() {
    final summary = _summary;
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص الفواتير',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي الفواتير',
                  summary['total'].toString(),
                  Icons.receipt,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'مدفوعة',
                  summary['paid'].toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'صادرة',
                  summary['issued'].toString(),
                  Icons.pending,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'إجمالي المبلغ',
                  currencyFormat.format(summary['totalAmount']),
                  Icons.attach_money,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تفاصيل مالية',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildFinancialRow(
                    'المبلغ المدفوع',
                    currencyFormat.format(summary['paidAmount']),
                    Colors.green,
                  ),
                  const Divider(),
                  _buildFinancialRow(
                    'المبلغ المستحق',
                    currencyFormat.format(summary['pendingAmount']),
                    Colors.orange,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _viewFinancialReports(),
              icon: const Icon(Icons.assessment),
              label: const Text('عرض التقارير المالية'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _createNewInvoice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
    ).then((_) => _loadInvoices());
  }

  void _viewInvoiceDetails(InvoiceModel invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceDetailsScreen(invoice: invoice),
      ),
    ).then((_) => _loadInvoices());
  }

  void _viewPayments(InvoiceModel invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentsManagementScreen(invoiceId: invoice.id),
      ),
    );
  }

  void _viewFinancialReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FinancialReportsScreen()),
    );
  }

  void _showStatusFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب الحالة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<InvoiceStatus?>(
              title: const Text('جميع الحالات'),
              value: null,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadInvoices();
              },
            ),
            RadioListTile<InvoiceStatus?>(
              title: const Text('مسودة'),
              value: InvoiceStatus.draft,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadInvoices();
              },
            ),
            RadioListTile<InvoiceStatus?>(
              title: const Text('صادرة'),
              value: InvoiceStatus.issued,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadInvoices();
              },
            ),
            RadioListTile<InvoiceStatus?>(
              title: const Text('مدفوعة'),
              value: InvoiceStatus.paid,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadInvoices();
              },
            ),
            RadioListTile<InvoiceStatus?>(
              title: const Text('ملغاة'),
              value: InvoiceStatus.cancelled,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadInvoices();
              },
            ),
          ],
        ),
      ),
    );
  }
}

