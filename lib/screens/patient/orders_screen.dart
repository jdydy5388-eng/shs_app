import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/prescription_model.dart';
import '../../models/user_model.dart';
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

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
      final patientId = authProvider.currentUser?.id ?? '';
      final orders = await _dataService.getOrders(patientId: patientId);
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
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateOrderDialog(),
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
    if (_orders.isEmpty) {
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
                'لا توجد طلبات',
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
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
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
            Text('الصيدلية: ${order.pharmacyName}'),
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
                if (order.prescriptionId != null)
                  FutureBuilder<PrescriptionModel?>(
                    future: _loadPrescription(order.prescriptionId!),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        final prescription = snapshot.data!;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
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
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                const Text(
                  'الأدوية:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...order.items.map((item) => _buildOrderItem(item)),
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
                if (order.items.any((item) => item.alternativeMedicationId != null)) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.swap_horiz, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'بدائل مقترحة',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...order.items.where((item) => item.alternativeMedicationId != null).map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.alternativeMedicationName != null
                                            ? '${item.medicationName} → ${item.alternativeMedicationName}'
                                            : '${item.medicationName} → بديل',
                                      ),
                                    ),
                                    if (order.status == OrderStatus.pending ||
                                        order.status == OrderStatus.confirmed)
                                      Row(
                                        children: [
                                          TextButton.icon(
                                            icon: const Icon(Icons.check, color: Colors.green),
                                            label: const Text('موافق'),
                                            onPressed: () => _approveAlternative(order.id, item),
                                          ),
                                          TextButton.icon(
                                            icon: const Icon(Icons.close, color: Colors.red),
                                            label: const Text('رفض'),
                                            onPressed: () => _rejectAlternative(order.id, item),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item) {
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الكمية: ${item.quantity}'),
            if (item.alternativeMedicationName != null)
              Text(
                'بديل مقترح: ${item.alternativeMedicationName} (${(item.alternativePrice ?? 0).toStringAsFixed(2)} ر.س)',
                style: const TextStyle(color: Colors.orange),
              ),
          ],
        ),
        trailing: Text('${(item.price * item.quantity).toStringAsFixed(2)} ر.س'),
      ),
    );
  }

  Future<void> _showCreateOrderDialog() async {
    final authProvider = Provider.of<AuthProviderLocal>(context, listen: false);
    final patientId = authProvider.currentUser?.id ?? '';

    try {
      final prescriptions = await _dataService.getPrescriptions(patientId: patientId);
      final pharmacies = await _dataService.getUsers(role: UserRole.pharmacist);

      if (prescriptions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا توجد وصفات طبية متاحة لطلب الأدوية'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (pharmacies.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا توجد صيدليات متاحة'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      PrescriptionModel? selectedPrescription;
      UserModel? selectedPharmacy;
      final deliveryAddressController = TextEditingController();
      final notesController = TextEditingController();

      try {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text('طلب دواء جديد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<PrescriptionModel>(
                      decoration: const InputDecoration(
                        labelText: 'اختر الوصفة الطبية *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      value: selectedPrescription,
                      items: prescriptions.map((prescription) {
                        return DropdownMenuItem<PrescriptionModel>(
                          value: prescription,
                          child: Text('${prescription.diagnosis} - ${prescription.doctorName}'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedPrescription = value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'يرجى اختيار وصفة طبية';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<UserModel>(
                      decoration: const InputDecoration(
                        labelText: 'اختر الصيدلية *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_pharmacy),
                      ),
                      value: selectedPharmacy,
                      items: pharmacies.map((pharmacy) {
                        return DropdownMenuItem<UserModel>(
                          value: pharmacy,
                          child: Text(pharmacy.pharmacyName ?? pharmacy.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedPharmacy = value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'يرجى اختيار صيدلية';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: deliveryAddressController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان التوصيل (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات إضافية للمستودع (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedPrescription == null || selectedPharmacy == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى اختيار الوصفة والصيدلية')),
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('إرسال الطلب'),
                ),
              ],
            ),
          ),
        );
        if (result == true && selectedPrescription != null && selectedPharmacy != null) {
          try {
            final currentUser = authProvider.currentUser;
            if (currentUser == null) {
              throw Exception('تعذر تحديد حساب المريض الحالي');
            }

            final deliveryAddress = deliveryAddressController.text.trim().isEmpty
                ? null
                : deliveryAddressController.text.trim();
            final notes = notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim();

            await _dataService.createOrderFromPrescription(
              patient: currentUser,
              pharmacy: selectedPharmacy!,
              prescription: selectedPrescription!,
              deliveryAddress: deliveryAddress,
              notes: notes,
            );
            await _loadOrders();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إرسال الطلب بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('خطأ في إرسال الطلب: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } finally {
        deliveryAddressController.dispose();
        notesController.dispose();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
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

  Future<void> _approveAlternative(String orderId, OrderItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الموافقة على البديل'),
        content: Text(
            'هل أنت متأكد من الموافقة على البديل ${item.alternativeMedicationName ?? item.medicationName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('موافق'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dataService.approveOrderAlternative(
          orderId: orderId,
          orderItemId: item.id,
        );
        await _loadOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم الموافقة على البديل'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر الموافقة على البديل: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectAlternative(String orderId, OrderItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض البديل'),
        content: Text(
          'هل أنت متأكد من رفض البديل ${item.alternativeMedicationName ?? item.medicationName}؟',
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
      try {
        await _dataService.rejectOrderAlternative(
          orderId: orderId,
          orderItemId: item.id,
        );
        await _loadOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض البديل'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر رفض البديل: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
