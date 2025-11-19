import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../models/invoice_model.dart';
import '../../models/payment_model.dart';
import '../../services/data_service.dart';
import '../../utils/pdf_service.dart';
import 'payments_management_screen.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoiceDetailsScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  final DataService _dataService = DataService();
  late InvoiceModel _invoice;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  Future<void> _updateStatus(InvoiceStatus newStatus) async {
    setState(() => _isLoading = true);
    try {
      await _dataService.updateInvoiceStatus(_invoice.id, newStatus);
      setState(() {
        _invoice = InvoiceModel(
          id: _invoice.id,
          patientId: _invoice.patientId,
          patientName: _invoice.patientName,
          relatedType: _invoice.relatedType,
          relatedId: _invoice.relatedId,
          items: _invoice.items,
          subtotal: _invoice.subtotal,
          discount: _invoice.discount,
          tax: _invoice.tax,
          total: _invoice.total,
          currency: _invoice.currency,
          status: newStatus,
          insuranceProvider: _invoice.insuranceProvider,
          insurancePolicy: _invoice.insurancePolicy,
          createdAt: _invoice.createdAt,
          updatedAt: DateTime.now(),
          paidAt: newStatus == InvoiceStatus.paid ? DateTime.now() : _invoice.paidAt,
        );
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث حالة الفاتورة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الحالة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س', decimalDigits: 2);

    final statusColor = {
      InvoiceStatus.draft: Colors.grey,
      InvoiceStatus.issued: Colors.orange,
      InvoiceStatus.paid: Colors.green,
      InvoiceStatus.cancelled: Colors.red,
    }[_invoice.status]!;

    final statusText = {
      InvoiceStatus.draft: 'مسودة',
      InvoiceStatus.issued: 'صادرة',
      InvoiceStatus.paid: 'مدفوعة',
      InvoiceStatus.cancelled: 'ملغاة',
    }[_invoice.status]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الفاتورة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printInvoice(),
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
                  _buildHeaderCard(statusColor, statusText, dateFormat),
                  const SizedBox(height: 16),
                  _buildItemsCard(currencyFormat),
                  const SizedBox(height: 16),
                  _buildFinancialCard(currencyFormat),
                  if (_invoice.insuranceProvider != null) ...[
                    const SizedBox(height: 16),
                    _buildInsuranceCard(),
                  ],
                  const SizedBox(height: 16),
                  _buildActionsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(Color statusColor, String statusText, DateFormat dateFormat) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'رقم الفاتورة',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      _invoice.id.substring(0, 8).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Chip(
                  label: Text(statusText),
                  backgroundColor: statusColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Text('المريض: ${_invoice.patientName}'),
            Text('التاريخ: ${dateFormat.format(_invoice.createdAt)}'),
            if (_invoice.relatedType != null)
              Text('النوع: ${_invoice.relatedType}'),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(NumberFormat currencyFormat) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'عناصر الفاتورة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._invoice.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.description,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text('${item.quantity} × ${currencyFormat.format(item.unitPrice)}'),
                          ],
                        ),
                      ),
                      Text(
                        currencyFormat.format(item.total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(NumberFormat currencyFormat) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFinancialRow('المجموع الفرعي', _invoice.subtotal, currencyFormat),
            if (_invoice.discount > 0)
              _buildFinancialRow('الخصم', -_invoice.discount, currencyFormat),
            if (_invoice.tax > 0)
              _buildFinancialRow('الضريبة', _invoice.tax, currencyFormat),
            const Divider(),
            _buildFinancialRow(
              'الإجمالي',
              _invoice.total,
              currencyFormat,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow(
    String label,
    double amount,
    NumberFormat currencyFormat, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: FontWeight.bold,
              color: isTotal ? Colors.blue : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsuranceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات التأمين',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_invoice.insuranceProvider != null)
              Text('شركة التأمين: ${_invoice.insuranceProvider}'),
            if (_invoice.insurancePolicy != null)
              Text('رقم البوليصة: ${_invoice.insurancePolicy}'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_invoice.status == InvoiceStatus.draft) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(InvoiceStatus.issued),
                  icon: const Icon(Icons.send),
                  label: const Text('إصدار الفاتورة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_invoice.status == InvoiceStatus.issued) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _viewPayments(),
                  icon: const Icon(Icons.payment),
                  label: const Text('إدارة المدفوعات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_invoice.status != InvoiceStatus.paid &&
                _invoice.status != InvoiceStatus.cancelled) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _updateStatus(InvoiceStatus.cancelled),
                  icon: const Icon(Icons.cancel),
                  label: const Text('إلغاء الفاتورة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _viewPayments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentsManagementScreen(invoiceId: _invoice.id),
      ),
    ).then((_) {
      // إعادة تحميل الفاتورة بعد إضافة دفعة
      // يمكن إضافة منطق إعادة التحميل هنا
    });
  }

  Future<void> _printInvoice() async {
    try {
      // جلب المدفوعات
      final payments = await _dataService.getPayments(invoiceId: _invoice.id);
      final paymentList = payments.cast<PaymentModel>();

      // إنشاء PDF
      final pdf = await PdfService.generateInvoicePdf(
        invoice: _invoice,
        payments: paymentList,
      );

      // عرض PDF وطباعته
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في طباعة الفاتورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

