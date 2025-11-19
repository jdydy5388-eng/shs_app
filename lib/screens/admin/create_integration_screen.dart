import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/integration_models.dart';
import '../../services/data_service.dart';
import '../../services/encryption_service.dart';

class CreateIntegrationScreen extends StatefulWidget {
  const CreateIntegrationScreen({super.key});

  @override
  State<CreateIntegrationScreen> createState() => _CreateIntegrationScreenState();
}

class _CreateIntegrationScreenState extends State<CreateIntegrationScreen> {
  final DataService _dataService = DataService();
  final EncryptionService _encryptionService = EncryptionService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiSecretController = TextEditingController();
  final _descriptionController = TextEditingController();

  IntegrationType _selectedType = IntegrationType.other;
  IntegrationStatus _selectedStatus = IntegrationStatus.pending;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _encryptionService.initialize();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveIntegration() async {
    if (!_formKey.currentState!.validate()) return;

    // تشفير API key و secret
    String? encryptedApiKey;
    String? encryptedApiSecret;

    if (_apiKeyController.text.isNotEmpty) {
      encryptedApiKey = _encryptionService.encryptText(_apiKeyController.text);
    }
    if (_apiSecretController.text.isNotEmpty) {
      encryptedApiSecret = _encryptionService.encryptText(_apiSecretController.text);
    }

    final integration = ExternalIntegrationModel(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      type: _selectedType,
      status: _selectedStatus,
      apiUrl: _apiUrlController.text.trim().isEmpty
          ? null
          : _apiUrlController.text.trim(),
      apiKey: encryptedApiKey,
      apiSecret: encryptedApiSecret,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() => _isSaving = true);
    try {
      await _dataService.createExternalIntegration(integration);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء التكامل بنجاح')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء التكامل: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة تكامل جديد'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم التكامل *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true
                    ? 'يرجى إدخال اسم التكامل'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<IntegrationType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'نوع التكامل *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: IntegrationType.laboratory, child: Text('مختبر')),
                  DropdownMenuItem(value: IntegrationType.bank, child: Text('بنك')),
                  DropdownMenuItem(value: IntegrationType.insurance, child: Text('تأمين')),
                  DropdownMenuItem(value: IntegrationType.pharmacy, child: Text('صيدلية')),
                  DropdownMenuItem(value: IntegrationType.hospital, child: Text('مستشفى')),
                  DropdownMenuItem(value: IntegrationType.hl7, child: Text('HL7/FHIR')),
                  DropdownMenuItem(value: IntegrationType.other, child: Text('أخرى')),
                ],
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<IntegrationStatus>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'الحالة *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: IntegrationStatus.active, child: Text('نشط')),
                  DropdownMenuItem(value: IntegrationStatus.inactive, child: Text('غير نشط')),
                  DropdownMenuItem(value: IntegrationStatus.pending, child: Text('قيد الانتظار')),
                ],
                onChanged: (value) => setState(() => _selectedStatus = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiUrlController,
                decoration: const InputDecoration(
                  labelText: 'رابط API',
                  border: OutlineInputBorder(),
                  hintText: 'https://api.example.com',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'مفتاح API',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiSecretController,
                decoration: const InputDecoration(
                  labelText: 'سر API',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveIntegration,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

