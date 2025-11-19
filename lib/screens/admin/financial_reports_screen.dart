import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/invoice_model.dart';
import '../../services/data_service.dart';

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  final DataService _dataService = DataService();
  List<InvoiceModel> _invoices = [];
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    }
  }

  List<InvoiceModel> get _filteredInvoices {
    return _invoices.where((invoice) {
      return invoice.createdAt.isAfter(_startDate.subtract(const Duration(days: 1))) &&
          invoice.createdAt.isBefore(_endDate.add(const Duration(days: 1)));
    }).toList();
  }

  Map<String, dynamic> get _statistics {
    final filtered = _filteredInvoices;
    final total = filtered.length;
    final paid = filtered.where((i) => i.status == InvoiceStatus.paid).length;
    final issued = filtered.where((i) => i.status == InvoiceStatus.issued).length;
    final totalRevenue = filtered.fold(0.0, (sum, i) => sum + i.total);
    final paidRevenue = filtered
        .where((i) => i.status == InvoiceStatus.paid)
        .fold(0.0, (sum, i) => sum + i.total);
    final pendingRevenue = filtered
        .where((i) => i.status == InvoiceStatus.issued)
        .fold(0.0, (sum, i) => sum + i.total);
    final totalDiscount = filtered.fold(0.0, (sum, i) => sum + i.discount);
    final totalTax = filtered.fold(0.0, (sum, i) => sum + i.tax);

    return {
      'total': total,
      'paid': paid,
      'issued': issued,
      'totalRevenue': totalRevenue,
      'paidRevenue': paidRevenue,
      'pendingRevenue': pendingRevenue,
      'totalDiscount': totalDiscount,
      'totalTax': totalTax,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير المالية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateRangeSelector(),
                  const SizedBox(height: 24),
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  _buildRevenueChart(),
                  const SizedBox(height: 24),
                  _buildDetailedStats(),
                ],
              ),
            ),
    );
  }

  Widget _buildDateRangeSelector() {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر الفترة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('من تاريخ'),
                    subtitle: Text(dateFormat.format(_startDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('إلى تاريخ'),
                    subtitle: Text(dateFormat.format(_endDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final stats = _statistics;
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س', decimalDigits: 2);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'إجمالي الإيرادات',
                currencyFormat.format(stats['totalRevenue']),
                Icons.attach_money,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'المدفوع',
                currencyFormat.format(stats['paidRevenue']),
                Icons.check_circle,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'المستحق',
                currencyFormat.format(stats['pendingRevenue']),
                Icons.pending,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'عدد الفواتير',
                stats['total'].toString(),
                Icons.receipt,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
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
                fontSize: 18,
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

  Widget _buildRevenueChart() {
    final stats = _statistics;
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س', decimalDigits: 2);
    final paidRevenue = stats['paidRevenue'] as double;
    final pendingRevenue = stats['pendingRevenue'] as double;
    final total = paidRevenue + pendingRevenue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'توزيع الإيرادات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (total > 0) ...[
              _buildChartBar('المدفوع', paidRevenue, total, Colors.green),
              const SizedBox(height: 8),
              _buildChartBar('المستحق', pendingRevenue, total, Colors.orange),
            ] else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('لا توجد بيانات'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBar(String label, double value, double total, Color color) {
    final percentage = total > 0 ? (value / total * 100) : 0.0;
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س', decimalDigits: 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '${currencyFormat.format(value)} (${percentage.toStringAsFixed(1)}%)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? value / total : 0,
            minHeight: 20,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedStats() {
    final stats = _statistics;
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س', decimalDigits: 2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إحصائيات تفصيلية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatRow('إجمالي الفواتير', stats['total'].toString()),
            _buildStatRow('فواتير مدفوعة', stats['paid'].toString()),
            _buildStatRow('فواتير صادرة', stats['issued'].toString()),
            const Divider(),
            _buildStatRow('إجمالي الإيرادات', currencyFormat.format(stats['totalRevenue'])),
            _buildStatRow('إجمالي المدفوع', currencyFormat.format(stats['paidRevenue']), Colors.green),
            _buildStatRow('إجمالي المستحق', currencyFormat.format(stats['pendingRevenue']), Colors.orange),
            const Divider(),
            _buildStatRow('إجمالي الخصومات', currencyFormat.format(stats['totalDiscount'])),
            _buildStatRow('إجمالي الضرائب', currencyFormat.format(stats['totalTax'])),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

