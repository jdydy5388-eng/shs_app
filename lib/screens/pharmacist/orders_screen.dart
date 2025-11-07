import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/prescription_model.dart';
import '../../providers/auth_provider_local.dart';
import '../../services/data_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _dataService = DataService();
  List<MedicationOrderModel> _orders = [];
  bool _isLoading = true;
  OrderStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
      final pharmacyId = authProvider.currentUser?.id ?? '';
      final orders = await _dataService.getOrders(pharmacyId: pharmacyId);
      setState(() {
        _orders = orders.cast<MedicationOrderModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الطلبات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة طلبات الأدوية'),
        actions: [
          PopupMenuButton<OrderStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (status) {
              setState(() => _filterStatus = status);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('جميع الطلبات'),
              ),
              const PopupMenuItem(
                value: OrderStatus.pending,
                child: Text('قيد الانتظار'),
              ),
              const PopupMenuItem(
                value: OrderStatus.confirmed,
                child: Text('مؤكدة'),
              ),
              const PopupMenuItem(
                value: OrderStatus.preparing,
                child: Text('قيد التحضير'),
              ),
              const PopupMenuItem(
                value: OrderStatus.ready,
                child: Text('جاهزة'),
              ),
              const PopupMenuItem(
                value: OrderStatus.delivered,
                child: Text('تم التسليم'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildOrdersList(),
    );
  }

  Widget _buildOrdersList() {
    final filteredOrders = _filterStatus == null
        ? _orders
        : _orders.where((o) => o.status == _filterStatus).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _filterStatus == null
                    ? 'لا توجد طلبات'
                    : 'لا توجد طلبات بهذه الحالة',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(MedicationOrderModel order) {
    final statusColor = _getStatusColor(order.status);
    final statusText = _getStatusName(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(_getStatusIcon(order.status), color: statusColor),
        ),
        title: Text(
          'الطلب #${order.id.substring(0, 8)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المريض: ${order.patientName}'),
            Text('التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt)}'),
            Chip(
              label: Text(statusText, style: const TextStyle(fontSize: 12)),
              backgroundColor: statusColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: statusColor),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.prescriptionId != null) ...[
                  _buildPrescriptionSectionFuture(order.prescriptionId!),
                  const Divider(),
                ],
                const Text(
                  'الأدوية المطلوبة:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...order.items.map((item) => _buildOrderItem(order, item)),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'المجموع:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '${order.totalAmount.toStringAsFixed(2)} ر.س',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                if (order.deliveryAddress != null) ...[
                  const SizedBox(height: 8),
                  Text('عنوان التوصيل: ${order.deliveryAddress}'),
                ],
                if (order.notes != null) ...[
                  const SizedBox(height: 8),
                  Text('ملاحظات: ${order.notes}'),
                ],
                const SizedBox(height: 16),
                _buildActionButtons(order),
              ],
            ),
          ),
        ],
      ),
    );
  }

  FutureBuilder<PrescriptionModel?> _buildPrescriptionSectionFuture(String prescriptionId) {
    return FutureBuilder<PrescriptionModel?>(
      future: _loadPrescription(prescriptionId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final prescription = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.description, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'الوصفة الطبية',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('الطبيب: ${prescription.doctorName}'),
              Text('التشخيص: ${prescription.diagnosis}'),
              if (prescription.notes != null) Text('ملاحظات: ${prescription.notes}'),
              const SizedBox(height: 8),
              const Text(
                'الأدوية في الوصفة:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...prescription.medications.map((med) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• ${med.name} - ${med.dosage} - ${med.frequency}'),
                  )),
            ],
          ),
        );
      },
    );
  }

  Future<PrescriptionModel?> _loadPrescription(String prescriptionId) async {
    try {
      final prescriptions = await _dataService.getPrescriptions();
      try {
        return prescriptions.firstWhere((p) => p.id == prescriptionId);
      } catch (e) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Widget _buildOrderItem(MedicationOrderModel order, OrderItem item) {
    final hasAlternative = item.alternativeMedicationId != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: hasAlternative ? Colors.orange.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: Icon(
          hasAlternative ? Icons.medication : Icons.medication_liquid,
          color: hasAlternative ? Colors.orange : Colors.blue,
        ),
        title: Text(item.medicationName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الكمية: ${item.quantity}'),
            Text('السعر: ${item.price.toStringAsFixed(2)} ر.س'),
            if (hasAlternative)
              Text(
                item.alternativeMedicationName != null
                    ? 'بديل مقترح: ${item.alternativeMedicationName} (${(item.alternativePrice ?? item.price).toStringAsFixed(2)} ر.س)'
                    : 'تم اقتراح بديل، بانتظار موافقة المريض',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        trailing: Text('${(item.price * item.quantity).toStringAsFixed(2)} ر.س'),
      ),
    );
  }

  Widget _buildActionButtons(MedicationOrderModel order) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (order.status == OrderStatus.pending) ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('قبول الطلب'),
            onPressed: () => _updateOrderStatus(order.id, OrderStatus.confirmed),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.close),
            label: const Text('رفض الطلب'),
            onPressed: () => _rejectOrder(order),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text('اقتراح بدائل'),
            onPressed: () => _showAlternativesDialog(order),
          ),
        ],
        if (order.status == OrderStatus.confirmed)
          ElevatedButton.icon(
            icon: const Icon(Icons.build),
            label: const Text('بدء التحضير'),
            onPressed: () => _updateOrderStatus(order.id, OrderStatus.preparing),
          ),
        if (order.status == OrderStatus.preparing)
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('جاهز للتوصيل'),
            onPressed: () => _updateOrderStatus(order.id, OrderStatus.ready),
          ),
        if (order.status == OrderStatus.ready)
          ElevatedButton.icon(
            icon: const Icon(Icons.local_shipping),
            label: const Text('تم التوصيل'),
            onPressed: () => _updateOrderStatus(order.id, OrderStatus.delivered),
          ),
      ],
    );
  }

  Future<void> _updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    String? notes,
  }) async {
    try {
      await _dataService.updateOrderStatus(orderId, newStatus, notes: notes);
      await _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث حالة الطلب إلى: ${_getStatusName(newStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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

  Future<void> _rejectOrder(MedicationOrderModel order) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يرجى تحديد سبب الرفض:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الرفض',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('رفض'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _updateOrderStatus(
        order.id,
        OrderStatus.cancelled,
        notes: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم رفض الطلب: ${reasonController.text}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _showAlternativesDialog(MedicationOrderModel order) async {
    final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
    final pharmacyId = authProvider.currentUser?.id ?? '';

    try {
      final inventory = await _dataService.getInventory(pharmacyId: pharmacyId);

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اقتراح بدائل للأدوية غير المتوفرة'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('اختر البدائل للأدوية غير المتوفرة:'),
                const SizedBox(height: 16),
                ...order.items.map((item) {
                  final available = inventory.any(
                    (inv) => inv.medicationName.toLowerCase().contains(
                          item.medicationName.toLowerCase().split(' ').first,
                        ) && inv.quantity > 0,
                  );

                  if (available) {
                    return ListTile(
                      title: Text(item.medicationName),
                      subtitle: const Text('متوفر في المخزون'),
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                    );
                  }

                  return ExpansionTile(
                    title: Text(item.medicationName),
                    subtitle: const Text('غير متوفر - اختر بديل'),
                    leading: const Icon(Icons.warning, color: Colors.orange),
                    children: inventory
                        .where((inv) => inv.quantity > 0)
                        .map((alt) => ListTile(
                              title: Text(alt.medicationName),
                              subtitle: Text('متوفر: ${alt.quantity} - السعر: ${alt.price.toStringAsFixed(2)} ر.س'),
                              trailing: const Icon(Icons.arrow_forward),
                              onTap: () async {
                                Navigator.pop(context);
                                try {
                                  await _dataService.suggestOrderAlternative(
                                    orderId: order.id,
                                    orderItemId: item.id,
                                    alternative: alt,
                                  );
                                  await _loadOrders();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('تم اقتراح ${alt.medicationName} كبديل للمريض'),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('تعذر اقتراح البديل: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                            ))
                        .toList(),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال البدائل المقترحة للمريض'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('إرسال للمريض'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المخزون: $e')),
        );
      }
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending;
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.preparing:
        return Icons.build;
      case OrderStatus.ready:
        return Icons.check;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.delivered:
        return Colors.teal;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusName(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'قيد الانتظار';
      case OrderStatus.confirmed:
        return 'مؤكد';
      case OrderStatus.preparing:
        return 'قيد التحضير';
      case OrderStatus.ready:
        return 'جاهز';
      case OrderStatus.delivered:
        return 'تم التسليم';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }
}
