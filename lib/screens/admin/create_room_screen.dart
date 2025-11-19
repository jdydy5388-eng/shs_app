import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/room_bed_model.dart';
import '../../services/data_service.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final DataService _dataService = DataService();
  final _formKey = GlobalKey<FormState>();
  final Uuid _uuid = const Uuid();

  final _nameController = TextEditingController();
  RoomType _selectedType = RoomType.ward;
  final _floorController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _floorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة غرفة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الغرفة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.room),
                  hintText: 'مثال: غرفة 101',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال اسم الغرفة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'نوع الغرفة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              RadioListTile<RoomType>(
                title: const Text('عادية'),
                value: RoomType.ward,
                groupValue: _selectedType,
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              RadioListTile<RoomType>(
                title: const Text('عناية مركزة'),
                value: RoomType.icu,
                groupValue: _selectedType,
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              RadioListTile<RoomType>(
                title: const Text('عمليات'),
                value: RoomType.operation,
                groupValue: _selectedType,
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              RadioListTile<RoomType>(
                title: const Text('عزل'),
                value: RoomType.isolation,
                groupValue: _selectedType,
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _floorController,
                decoration: const InputDecoration(
                  labelText: 'الطابق (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.layers),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveRoom,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('حفظ الغرفة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveRoom() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final room = RoomModel(
        id: _uuid.v4(),
        name: _nameController.text.trim(),
        type: _selectedType,
        floor: _floorController.text.trim().isEmpty
            ? null
            : int.tryParse(_floorController.text.trim()),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _dataService.createRoom(room);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة الغرفة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة الغرفة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

