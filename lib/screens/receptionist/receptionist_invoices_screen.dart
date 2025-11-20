import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/invoice_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../widgets/loading_widgets.dart';
import '../../utils/ui_snackbar.dart';
import '../admin/create_invoice_screen.dart';
import '../admin/invoice_details_screen.dart';

class ReceptionistInvoicesScreen extends StatefulWidget {
  const ReceptionistInvoicesScreen({super.key});

  @override
  State<ReceptionistInvoicesScreen> createState() => _ReceptionistInvoicesScreenState();
}

class _ReceptionistInvoicesScreenState extends State<ReceptionistInvoicesScreen> {
  final DataService _dataService = DataService();
  List<InvoiceModel> _invoices = [];
  bool _isLoading = true;
  String _searchQuery = '';
  InvoiceStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await _dataService.getInvoices();
      setState(() {
        _invoices = invoices.cast<InvoiceModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showFriendlyAuthError(context, e);
      }
    }
  }

  List<InvoiceModel> get _filteredInvoices {
    var filtered = _invoices;
    
    if (_filterStatus != null) {
      filtered = filtered.where((i) => i.status == _filterStatus).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((i) {
        return i.patientName.toLowerCase().contains(query) ||
            i.id.toLowerCase().contains(query);
      }).toList();
    }
    
    return filtered..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفواتير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateInvoiceScreen(),
                ),
              ).then((_) => _loadInvoices());
            },
            tooltip: 'إنشاء فاتورة جديدة',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoices,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // فلاتر
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'بحث...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<InvoiceStatus?>(
                  value: _filterStatus,
                  hint: const Text('الحالة'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('الكل')),
                    ...InvoiceStatus.values.map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(_getStatusText(status)),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _filterStatus = value);
                  },
                ),
              ],
            ),
          ),
          // القائمة
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? const Center(
                        child: Text('لا توجد فواتير'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInvoices,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _filteredInvoices[index];
                            return _buildInvoiceCard(invoice);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(InvoiceModel invoice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(invoice.status).withValues(alpha: 0.2),
          child: Icon(
            Icons.receipt,
            color: _getStatusColor(invoice.status),
          ),
        ),
        title: Text(
          invoice.patientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('رقم الفاتورة: ${invoice.id.substring(0, 8)}'),
            Text('المبلغ: ${NumberFormat.currency(symbol: 'ر.س').format(invoice.total)}'),
            Text('الحالة: ${_getStatusText(invoice.status)}'),
            Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(invoice.createdAt)}'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoiceDetailsScreen(invoice: invoice),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return Colors.grey;
      case InvoiceStatus.issued:
        return Colors.blue;
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'مسودة';
      case InvoiceStatus.issued:
        return 'صادرة';
      case InvoiceStatus.paid:
        return 'مدفوعة';
      case InvoiceStatus.cancelled:
        return 'ملغاة';
    }
  }
}

