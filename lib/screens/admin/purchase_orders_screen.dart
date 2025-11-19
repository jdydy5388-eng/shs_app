import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/medical_inventory_model.dart';
import '../../services/data_service.dart';
import 'create_purchase_order_screen.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final DataService _dataService = DataService();
  List<PurchaseOrderModel> _orders = [];
  bool _isLoading = true;
  PurchaseOrderStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final orders = await _dataService.getPurchaseOrders(status: _filterStatus);
      setState(() {
        _orders = orders.cast<PurchaseOrderModel>();
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
        title: const Text('طلبات الشراء'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'status') {
                _showStatusFilter();
              } else if (value == 'clear') {
                setState(() => _filterStatus = null);
                _loadOrders();
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
            onPressed: () => _createOrder(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: _orders.isEmpty
                  ? Center(
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
                              'لا توجد طلبات شراء',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        return _buildOrderCard(order);
                      },
                    ),
            ),
    );
  }

  Widget _buildOrderCard(PurchaseOrderModel order) {
    final dateFormat = DateFormat('yyyy-MM-dd', 'ar');

    final statusColor = {
      PurchaseOrderStatus.draft: Colors.grey,
      PurchaseOrderStatus.pending: Colors.orange,
      PurchaseOrderStatus.approved: Colors.blue,
      PurchaseOrderStatus.ordered: Colors.purple,
      PurchaseOrderStatus.received: Colors.green,
      PurchaseOrderStatus.cancelled: Colors.red,
    }[order.status]!;

    final statusText = {
      PurchaseOrderStatus.draft: 'مسودة',
      PurchaseOrderStatus.pending: 'قيد الانتظار',
      PurchaseOrderStatus.approved: 'معتمدة',
      PurchaseOrderStatus.ordered: 'تم الطلب',
      PurchaseOrderStatus.received: 'مستلمة',
      PurchaseOrderStatus.cancelled: 'ملغاة',
    }[order.status]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.shopping_cart, color: statusColor),
        ),
        title: Text(
          'طلب #${order.orderNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (order.supplierName != null) Text('المورد: ${order.supplierName}'),
            Text('عدد العناصر: ${order.items.length}'),
            Text('المبلغ الإجمالي: ${order.totalAmount.toStringAsFixed(2)} ريال'),
            Text('التاريخ: ${dateFormat.format(order.createdAt)}'),
          ],
        ),
        trailing: Chip(
          label: Text(statusText, style: const TextStyle(fontSize: 12)),
          backgroundColor: statusColor.withValues(alpha: 0.2),
          labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
        onTap: () {
          // يمكن إضافة شاشة تفاصيل الطلب لاحقاً
        },
      ),
    );
  }

  void _createOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePurchaseOrderScreen()),
    ).then((_) => _loadOrders());
  }

  void _showStatusFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب الحالة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<PurchaseOrderStatus?>(
              title: const Text('جميع الحالات'),
              value: null,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadOrders();
              },
            ),
            RadioListTile<PurchaseOrderStatus?>(
              title: const Text('قيد الانتظار'),
              value: PurchaseOrderStatus.pending,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadOrders();
              },
            ),
            RadioListTile<PurchaseOrderStatus?>(
              title: const Text('معتمدة'),
              value: PurchaseOrderStatus.approved,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadOrders();
              },
            ),
          ],
        ),
      ),
    );
  }
}

