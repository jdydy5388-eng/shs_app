import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/entity_model.dart';
import '../../services/data_service.dart';
import 'package:intl/intl.dart';

class ManageEntitiesScreen extends StatefulWidget {
  const ManageEntitiesScreen({super.key});

  @override
  State<ManageEntitiesScreen> createState() => _ManageEntitiesScreenState();
}

class _ManageEntitiesScreenState extends State<ManageEntitiesScreen> {
  final _dataService = DataService();
  List<EntityModel> _entities = [];
  bool _isLoading = true;
  EntityType? _filterType;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  Future<void> _loadEntities() async {
    setState(() => _isLoading = true);
    try {
      final entities = await _dataService.getEntities();
      setState(() {
        _entities = entities.cast<EntityModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الكيانات: $e')),
        );
      }
    }
  }

  List<EntityModel> get _filteredEntities {
    var filtered = _entities;

    if (_filterType != null) {
      filtered = filtered.where((e) => e.type == _filterType).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((e) {
        return e.name.toLowerCase().contains(query) ||
            e.address.toLowerCase().contains(query) ||
            e.email.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الكيانات المتعاقدة'),
        actions: [
          PopupMenuButton<EntityType?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (type) {
              setState(() => _filterType = type);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('جميع الكيانات'),
              ),
              const PopupMenuItem(
                value: EntityType.pharmacy,
                child: Text('الصيدليات'),
              ),
              const PopupMenuItem(
                value: EntityType.hospital,
                child: Text('المستشفيات'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEntities,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'بحث في الكيانات',
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
                : _buildEntitiesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEntityDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEntitiesList() {
    final filtered = _filteredEntities;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.business_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty ? 'لا توجد كيانات' : 'لا توجد نتائج',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEntities,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final entity = filtered[index];
          return _buildEntityCard(entity);
        },
      ),
    );
  }

  Widget _buildEntityCard(EntityModel entity) {
    final typeColor = entity.type == EntityType.pharmacy ? Colors.purple : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withValues(alpha: 0.2),
          child: Icon(
            entity.type == EntityType.pharmacy ? Icons.local_pharmacy : Icons.local_hospital,
            color: typeColor,
          ),
        ),
        title: Text(
          entity.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entity.typeName),
            Text(entity.address),
            Chip(
              label: Text(entity.typeName, style: const TextStyle(fontSize: 12)),
              backgroundColor: typeColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: typeColor),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('العنوان: ${entity.address}'),
                Text('الهاتف: ${entity.phone}'),
                Text('البريد: ${entity.email}'),
                if (entity.licenseNumber != null)
                  Text('رقم الرخصة: ${entity.licenseNumber}'),
                if (entity.latitude != null && entity.longitude != null)
                  Text('الموقع: ${entity.latitude}, ${entity.longitude}'),
                if (entity.notes != null) ...[
                  const SizedBox(height: 8),
                  Text('ملاحظات: ${entity.notes}'),
                ],
                Text('تاريخ الإضافة: ${DateFormat('yyyy-MM-dd').format(entity.createdAt)}'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('تعديل'),
                      onPressed: () => _showEditEntityDialog(entity),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('حذف', style: TextStyle(color: Colors.red)),
                      onPressed: () => _deleteEntity(entity.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEntityDialog() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final licenseController = TextEditingController();
    final notesController = TextEditingController();
    EntityType? selectedType = EntityType.pharmacy;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إضافة كيان جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<EntityType>(
                  decoration: const InputDecoration(
                    labelText: 'نوع الكيان *',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedType,
                  items: EntityType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type == EntityType.pharmacy ? 'صيدلية' : 'مستشفى'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedType = value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الكيان *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: licenseController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الرخصة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
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
                if (nameController.text.trim().isEmpty ||
                    addressController.text.trim().isEmpty ||
                    phoneController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty ||
                    selectedType == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedType != null) {
      try {
        final entity = EntityModel(
          id: const Uuid().v4(),
          name: nameController.text.trim(),
          type: selectedType!,
          address: addressController.text.trim(),
          phone: phoneController.text.trim(),
          email: emailController.text.trim(),
          licenseNumber: licenseController.text.trim().isEmpty
              ? null
              : licenseController.text.trim(),
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
          createdAt: DateTime.now(),
        );

        await _dataService.createEntity(entity);
        await _loadEntities();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إضافة الكيان بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في الإضافة: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditEntityDialog(EntityModel entity) async {
    final nameController = TextEditingController(text: entity.name);
    final addressController = TextEditingController(text: entity.address);
    final phoneController = TextEditingController(text: entity.phone);
    final emailController = TextEditingController(text: entity.email);
    final licenseController = TextEditingController(text: entity.licenseNumber ?? '');
    final notesController = TextEditingController(text: entity.notes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل بيانات الكيان'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الكيان',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: licenseController,
                decoration: const InputDecoration(
                  labelText: 'رقم الرخصة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final updatedEntity = EntityModel(
          id: entity.id,
          name: nameController.text.trim(),
          type: entity.type,
          address: addressController.text.trim(),
          phone: phoneController.text.trim(),
          email: emailController.text.trim(),
          licenseNumber: licenseController.text.trim().isEmpty
              ? null
              : licenseController.text.trim(),
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
          latitude: entity.latitude,
          longitude: entity.longitude,
          createdAt: entity.createdAt,
        );

        await _dataService.updateEntity(
          updatedEntity.id,
          name: updatedEntity.name,
          address: updatedEntity.address,
          phone: updatedEntity.phone,
          email: updatedEntity.email,
          locationLat: updatedEntity.latitude,
          locationLng: updatedEntity.longitude,
        );
        await _loadEntities();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث البيانات بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في التحديث: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteEntity(String entityId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الكيان؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dataService.deleteEntity(entityId);
        await _loadEntities();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الكيان بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في الحذف: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

