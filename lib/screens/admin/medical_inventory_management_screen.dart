import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/medical_inventory_model.dart';
import '../../services/data_service.dart';
import 'create_medical_inventory_item_screen.dart';
import 'medical_inventory_item_details_screen.dart';
import 'purchase_orders_screen.dart';
import 'suppliers_management_screen.dart';
import 'maintenance_schedule_screen.dart';

class MedicalInventoryManagementScreen extends StatefulWidget {
  const MedicalInventoryManagementScreen({super.key});

  @override
  State<MedicalInventoryManagementScreen> createState() => _MedicalInventoryManagementScreenState();
}

class _MedicalInventoryManagementScreenState extends State<MedicalInventoryManagementScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  List<MedicalInventoryItemModel> _items = [];
  bool _isLoading = true;
  InventoryItemType? _filterType;
  EquipmentStatus? _filterStatus;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _dataService.getMedicalInventory(
        type: _filterType,
        status: _filterStatus,
      );
      setState(() {
        _items = items.cast<MedicalInventoryItemModel>();
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

  List<MedicalInventoryItemModel> get _filteredItems {
    return _items;
  }

  List<MedicalInventoryItemModel> get _lowStockItems {
    return _items.where((item) => item.isLowStock || item.isOutOfStock).toList();
  }

  List<MedicalInventoryItemModel> get _expiringItems {
    return _items.where((item) => item.isExpiringSoon || item.isExpired).toList();
  }

  List<MedicalInventoryItemModel> get _needsMaintenance {
    return _items.where((item) => item.needsMaintenance).toList();
  }

  Map<String, dynamic> get _statistics {
    final total = _items.length;
    final equipment = _items.where((i) => i.type == InventoryItemType.equipment).length;
    final supplies = _items.where((i) => i.type == InventoryItemType.supplies).length;
    final consumables = _items.where((i) => i.type == InventoryItemType.consumables).length;
    final lowStock = _lowStockItems.length;
    final expiring = _expiringItems.length;
    final maintenance = _needsMaintenance.length;

    return {
      'total': total,
      'equipment': equipment,
      'supplies': supplies,
      'consumables': consumables,
      'lowStock': lowStock,
      'expiring': expiring,
      'maintenance': maintenance,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستودع الطبي'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'المخزون', icon: Icon(Icons.inventory)),
            Tab(text: 'التنبيهات', icon: Icon(Icons.warning)),
            Tab(text: 'الإحصائيات', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'type') {
                _showTypeFilter();
              } else if (value == 'status') {
                _showStatusFilter();
              } else if (value == 'clear') {
                setState(() {
                  _filterType = null;
                  _filterStatus = null;
                });
                _loadItems();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'type',
                child: Text('فلترة حسب النوع'),
              ),
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
          PopupMenuButton<String?>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'purchase') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PurchaseOrdersScreen()),
                );
              } else if (value == 'suppliers') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SuppliersManagementScreen()),
                );
              } else if (value == 'maintenance') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MaintenanceScheduleScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'purchase',
                child: Text('طلبات الشراء'),
              ),
              const PopupMenuItem(
                value: 'suppliers',
                child: Text('الموردين'),
              ),
              const PopupMenuItem(
                value: 'maintenance',
                child: Text('جدولة الصيانة'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createItem(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInventoryTab(),
          _buildAlertsTab(),
          _buildStatisticsTab(),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadItems,
            child: _filteredItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد عناصر في المخزون',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return _buildItemCard(item);
                    },
                  ),
          );
  }

  Widget _buildItemCard(MedicalInventoryItemModel item) {
    final typeText = {
      InventoryItemType.equipment: 'معدات',
      InventoryItemType.supplies: 'مستلزمات',
      InventoryItemType.consumables: 'مواد استهلاكية',
    }[item.type]!;

    final typeColor = {
      InventoryItemType.equipment: Colors.blue,
      InventoryItemType.supplies: Colors.green,
      InventoryItemType.consumables: Colors.orange,
    }[item.type]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: item.isLowStock || item.isExpired ? 4 : 2,
      color: item.isExpired
          ? Colors.red.shade50
          : item.isLowStock
              ? Colors.orange.shade50
              : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withValues(alpha: 0.2),
          child: Icon(
            item.type == InventoryItemType.equipment
                ? Icons.build
                : Icons.inventory_2,
            color: typeColor,
          ),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('النوع: $typeText'),
            Text('الكمية: ${item.quantity} ${item.unit ?? ''}'),
            if (item.location != null) Text('الموقع: ${item.location}'),
            if (item.expiryDate != null)
              Text(
                'انتهاء الصلاحية: ${DateFormat('yyyy-MM-dd', 'ar').format(item.expiryDate!)}',
                style: TextStyle(
                  color: item.isExpired
                      ? Colors.red
                      : item.isExpiringSoon
                          ? Colors.orange
                          : null,
                  fontWeight: item.isExpired || item.isExpiringSoon
                      ? FontWeight.bold
                      : null,
                ),
              ),
            if (item.nextMaintenanceDate != null)
              Text(
                'صيانة قادمة: ${DateFormat('yyyy-MM-dd', 'ar').format(item.nextMaintenanceDate!)}',
                style: TextStyle(
                  color: item.needsMaintenance ? Colors.orange : null,
                  fontWeight: item.needsMaintenance ? FontWeight.bold : null,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.isLowStock)
              const Icon(Icons.warning, color: Colors.orange, size: 20),
            if (item.isExpired)
              const Icon(Icons.error, color: Colors.red, size: 20),
            if (item.needsMaintenance)
              const Icon(Icons.build, color: Colors.blue, size: 20),
            if (item.status != null)
              Chip(
                label: Text(
                  {
                    EquipmentStatus.available: 'متاحة',
                    EquipmentStatus.inUse: 'قيد الاستخدام',
                    EquipmentStatus.maintenance: 'صيانة',
                    EquipmentStatus.outOfOrder: 'معطلة',
                  }[item.status]!,
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: {
                  EquipmentStatus.available: Colors.green,
                  EquipmentStatus.inUse: Colors.blue,
                  EquipmentStatus.maintenance: Colors.orange,
                  EquipmentStatus.outOfOrder: Colors.red,
                }[item.status]!.withValues(alpha: 0.2),
              ),
          ],
        ),
        onTap: () => _viewItemDetails(item),
      ),
    );
  }

  Widget _buildAlertsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_lowStockItems.isNotEmpty) ...[
            _buildAlertSection(
              'مخزون منخفض',
              _lowStockItems,
              Colors.orange,
              Icons.warning,
            ),
            const SizedBox(height: 16),
          ],
          if (_expiringItems.isNotEmpty) ...[
            _buildAlertSection(
              'منتهي الصلاحية أو قريب الانتهاء',
              _expiringItems,
              Colors.red,
              Icons.error,
            ),
            const SizedBox(height: 16),
          ],
          if (_needsMaintenance.isNotEmpty) ...[
            _buildAlertSection(
              'يحتاج صيانة',
              _needsMaintenance,
              Colors.blue,
              Icons.build,
            ),
            const SizedBox(height: 16),
          ],
          if (_lowStockItems.isEmpty &&
              _expiringItems.isEmpty &&
              _needsMaintenance.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.green[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد تنبيهات',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertSection(
    String title,
    List<MedicalInventoryItemModel> items,
    Color color,
    IconData icon,
  ) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  '$title (${items.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.circle, size: 8),
                  title: Text(item.name),
                  subtitle: Text('الكمية: ${item.quantity} ${item.unit ?? ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () => _viewItemDetails(item),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsTab() {
    final stats = _statistics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إحصائيات المستودع',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي العناصر',
                  stats['total'].toString(),
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'مخزون منخفض',
                  stats['lowStock'].toString(),
                  Icons.warning,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'معدات',
                  stats['equipment'].toString(),
                  Icons.build,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'مستلزمات',
                  stats['supplies'].toString(),
                  Icons.medical_services,
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
                  'مواد استهلاكية',
                  stats['consumables'].toString(),
                  Icons.shopping_cart,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'يحتاج صيانة',
                  stats['maintenance'].toString(),
                  Icons.build_circle,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'منتهي/قريب الانتهاء',
            stats['expiring'].toString(),
            Icons.error,
            Colors.red,
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

  void _createItem() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateMedicalInventoryItemScreen()),
    ).then((_) => _loadItems());
  }

  void _viewItemDetails(MedicalInventoryItemModel item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicalInventoryItemDetailsScreen(item: item),
      ),
    ).then((_) => _loadItems());
  }

  void _showTypeFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب النوع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<InventoryItemType?>(
              title: const Text('جميع الأنواع'),
              value: null,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
                _loadItems();
              },
            ),
            RadioListTile<InventoryItemType?>(
              title: const Text('معدات'),
              value: InventoryItemType.equipment,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
                _loadItems();
              },
            ),
            RadioListTile<InventoryItemType?>(
              title: const Text('مستلزمات'),
              value: InventoryItemType.supplies,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
                _loadItems();
              },
            ),
            RadioListTile<InventoryItemType?>(
              title: const Text('مواد استهلاكية'),
              value: InventoryItemType.consumables,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
                _loadItems();
              },
            ),
          ],
        ),
      ),
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
            RadioListTile<EquipmentStatus?>(
              title: const Text('جميع الحالات'),
              value: null,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadItems();
              },
            ),
            RadioListTile<EquipmentStatus?>(
              title: const Text('متاحة'),
              value: EquipmentStatus.available,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadItems();
              },
            ),
            RadioListTile<EquipmentStatus?>(
              title: const Text('قيد الاستخدام'),
              value: EquipmentStatus.inUse,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadItems();
              },
            ),
            RadioListTile<EquipmentStatus?>(
              title: const Text('صيانة'),
              value: EquipmentStatus.maintenance,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadItems();
              },
            ),
          ],
        ),
      ),
    );
  }
}

