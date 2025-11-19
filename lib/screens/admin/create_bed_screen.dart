import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/room_bed_model.dart';
import '../../services/data_service.dart';

class CreateBedScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const CreateBedScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<CreateBedScreen> createState() => _CreateBedScreenState();
}

class _CreateBedScreenState extends State<CreateBedScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final Uuid _uuid = const Uuid();

  final _labelController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة سرير'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.room, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الغرفة',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              widget.roomName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'تسمية السرير',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bed),
                  hintText: 'مثال: سرير 1، A1، 101-A',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال تسمية السرير';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveBed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('حفظ السرير'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveBed() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final bed = BedModel(
        id: _uuid.v4(),
        roomId: widget.roomId,
        label: _labelController.text.trim(),
        status: BedStatus.available,
      );

      await _dataService.createBed(bed);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة السرير بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة السرير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

