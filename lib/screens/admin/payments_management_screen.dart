import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/payment_model.dart';
import '../../models/invoice_model.dart';
import '../../services/data_service.dart';

class PaymentsManagementScreen extends StatefulWidget {
  final String invoiceId;

  const PaymentsManagementScreen({super.key, required this.invoiceId});

  @override
  State<PaymentsManagementScreen> createState() => _PaymentsManagementScreenState();
}

class _PaymentsManagementScreenState extends State<PaymentsManagementScreen> {
  final DataService _dataService = DataService();
  final Uuid _uuid = const Uuid();
  InvoiceModel? _invoice;
  List<PaymentModel> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final invoice = await _dataService.getInvoice(widget.invoiceId);
      final payments = await _dataService.getPayments(invoiceId: widget.invoiceId);
      
      setState(() {
        if (invoice != null && invoice is InvoiceModel) {
          _invoice = invoice as InvoiceModel;
        }
        _payments = payments.cast<PaymentModel>();
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

  double get _totalPaid => _payments.fold(0.0, (sum, p) => sum + p.amount);
  double get _remainingAmount {
    if (_invoice == null) return 0;
    return _invoice!.total - _totalPaid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المدفوعات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _remainingAmount > 0 ? _addPayment : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_invoice != null) _buildInvoiceSummary(),
                    const SizedBox(height: 16),
                    _buildPaymentsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInvoiceSummary() {
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س', decimalDigits: 2);
    
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص الفاتورة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('إجمالي الفاتورة', _invoice!.total, currencyFormat),
            _buildSummaryRow('المدفوع', _totalPaid, currencyFormat, Colors.green),
            _buildSummaryRow(
              'المتبقي',
              _remainingAmount,
              currencyFormat,
              _remainingAmount > 0 ? Colors.orange : Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, NumberFormat format, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            format.format(amount),
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

  Widget _buildPaymentsList() {
    if (_payments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.payment_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد مدفوعات',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'سجل المدفوعات',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._payments.map((payment) => _buildPaymentCard(payment)),
      ],
    );
  }

  Widget _buildPaymentCard(PaymentModel payment) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');
    final currencyFormat = NumberFormat.currency(symbol: 'ر.س', decimalDigits: 2);

    final methodText = {
      PaymentMethod.cash: 'نقد',
      PaymentMethod.card: 'بطاقة',
      PaymentMethod.transfer: 'تحويل',
      PaymentMethod.insurance: 'تأمين',
    }[payment.method]!;

    final methodIcon = {
      PaymentMethod.cash: Icons.money,
      PaymentMethod.card: Icons.credit_card,
      PaymentMethod.transfer: Icons.account_balance,
      PaymentMethod.insurance: Icons.local_hospital,
    }[payment.method]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.2),
          child: Icon(methodIcon, color: Colors.green),
        ),
        title: Text(
          currencyFormat.format(payment.amount),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الطريقة: $methodText'),
            Text('التاريخ: ${dateFormat.format(payment.createdAt)}'),
            if (payment.reference != null) Text('المرجع: ${payment.reference}'),
            if (payment.notes != null) Text('ملاحظات: ${payment.notes}'),
          ],
        ),
      ),
    );
  }

  void _addPayment() {
    final amountController = TextEditingController();
    PaymentMethod selectedMethod = PaymentMethod.cash;
    final referenceController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة دفعة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PaymentMethod>(
                  decoration: const InputDecoration(
                    labelText: 'طريقة الدفع',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedMethod,
                  items: const [
                    DropdownMenuItem(
                      value: PaymentMethod.cash,
                      child: Text('نقد'),
                    ),
                    DropdownMenuItem(
                      value: PaymentMethod.card,
                      child: Text('بطاقة'),
                    ),
                    DropdownMenuItem(
                      value: PaymentMethod.transfer,
                      child: Text('تحويل'),
                    ),
                    DropdownMenuItem(
                      value: PaymentMethod.insurance,
                      child: Text('تأمين'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedMethod = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'المرجع (اختياري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.confirmation_number),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال مبلغ صحيح')),
                  );
                  return;
                }

                if (amount > _remainingAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('المبلغ أكبر من المتبقي (${_remainingAmount.toStringAsFixed(2)})'),
                    ),
                  );
                  return;
                }

                try {
                  final payment = PaymentModel(
                    id: _uuid.v4(),
                    invoiceId: widget.invoiceId,
                    amount: amount,
                    method: selectedMethod,
                    reference: referenceController.text.trim().isEmpty
                        ? null
                        : referenceController.text.trim(),
                    createdAt: DateTime.now(),
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );

                  await _dataService.createPayment(payment);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إضافة الدفعة بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ في إضافة الدفعة: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

