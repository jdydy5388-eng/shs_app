import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/integration_models.dart';
import '../../services/data_service.dart';
import '../../services/encryption_service.dart';
import '../../services/external_integration_service.dart';
import 'create_integration_screen.dart';

class IntegrationsManagementScreen extends StatefulWidget {
  const IntegrationsManagementScreen({super.key});

  @override
  State<IntegrationsManagementScreen> createState() => _IntegrationsManagementScreenState();
}

class _IntegrationsManagementScreenState extends State<IntegrationsManagementScreen> {
  final DataService _dataService = DataService();
  final ExternalIntegrationService _integrationService = ExternalIntegrationService();
  final EncryptionService _encryptionService = EncryptionService();
  
  List<ExternalIntegrationModel> _integrations = [];
  bool _isLoading = true;
  IntegrationType? _filterType;

  @override
  void initState() {
    super.initState();
    _loadIntegrations();
    _encryptionService.initialize();
  }

  Future<void> _loadIntegrations() async {
    setState(() => _isLoading = true);
    try {
      final integrations = await _dataService.getExternalIntegrations();
      setState(() {
        _integrations = integrations.cast<ExternalIntegrationModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل التكاملات: $e')),
        );
      }
    }
  }

  Future<void> _syncIntegration(ExternalIntegrationModel integration) async {
    try {
      // TODO: تنفيذ المزامنة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري المزامنة...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في المزامنة: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التكاملات الخارجية'),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadIntegrations,
                    child: _integrations.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.link_off,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد تكاملات خارجية',
                                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _integrations.length,
                            itemBuilder: (context, index) {
                              return _buildIntegrationCard(_integrations[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateIntegrationScreen()),
        ).then((_) => _loadIntegrations()),
        icon: const Icon(Icons.add),
        label: const Text('إضافة تكامل جديد'),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: DropdownButtonFormField<IntegrationType?>(
        value: _filterType,
        decoration: const InputDecoration(
          labelText: 'فلترة حسب النوع',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('جميع الأنواع')),
          ...IntegrationType.values.map((type) {
            final typeText = {
              IntegrationType.laboratory: 'مختبر',
              IntegrationType.bank: 'بنك',
              IntegrationType.insurance: 'تأمين',
              IntegrationType.pharmacy: 'صيدلية',
              IntegrationType.hospital: 'مستشفى',
              IntegrationType.hl7: 'HL7/FHIR',
              IntegrationType.other: 'أخرى',
            }[type]!;
            return DropdownMenuItem(value: type, child: Text(typeText));
          }),
        ],
        onChanged: (value) {
          setState(() => _filterType = value);
          // TODO: تطبيق الفلترة
        },
      ),
    );
  }

  Widget _buildIntegrationCard(ExternalIntegrationModel integration) {
    final statusColor = {
      IntegrationStatus.active: Colors.green,
      IntegrationStatus.inactive: Colors.grey,
      IntegrationStatus.error: Colors.red,
      IntegrationStatus.pending: Colors.orange,
    }[integration.status]!;

    final typeText = {
      IntegrationType.laboratory: 'مختبر',
      IntegrationType.bank: 'بنك',
      IntegrationType.insurance: 'تأمين',
      IntegrationType.pharmacy: 'صيدلية',
      IntegrationType.hospital: 'مستشفى',
      IntegrationType.hl7: 'HL7/FHIR',
      IntegrationType.other: 'أخرى',
    }[integration.type]!;

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(_getTypeIcon(integration.type), color: statusColor),
        ),
        title: Text(integration.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('النوع: $typeText'),
            if (integration.description != null) Text(integration.description!),
            if (integration.lastSync != null)
              Text('آخر مزامنة: ${dateFormat.format(integration.lastSync!)}'),
            if (integration.lastSyncError != null)
              Text(
                'خطأ: ${integration.lastSyncError}',
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getStatusText(integration.status),
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () => _syncIntegration(integration),
              tooltip: 'مزامنة',
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(IntegrationType type) {
    switch (type) {
      case IntegrationType.laboratory:
        return Icons.science;
      case IntegrationType.bank:
        return Icons.account_balance;
      case IntegrationType.insurance:
        return Icons.shield;
      case IntegrationType.pharmacy:
        return Icons.local_pharmacy;
      case IntegrationType.hospital:
        return Icons.local_hospital;
      case IntegrationType.hl7:
        return Icons.code;
      default:
        return Icons.link;
    }
  }

  String _getStatusText(IntegrationStatus status) {
    return {
      IntegrationStatus.active: 'نشط',
      IntegrationStatus.inactive: 'غير نشط',
      IntegrationStatus.error: 'خطأ',
      IntegrationStatus.pending: 'قيد الانتظار',
    }[status]!;
  }
}

