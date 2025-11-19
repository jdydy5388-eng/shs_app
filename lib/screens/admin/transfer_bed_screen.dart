import 'package:flutter/material.dart';
import '../../models/room_bed_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';

class TransferBedScreen extends StatefulWidget {
  final BedModel currentBed;

  const TransferBedScreen({super.key, required this.currentBed});

  @override
  State<TransferBedScreen> createState() => _TransferBedScreenState();
}

class _TransferBedScreenState extends State<TransferBedScreen> {
  final DataService _dataService = DataService();
  List<RoomModel> _rooms = [];
  Map<String, List<BedModel>> _bedsByRoom = {};
  BedModel? _selectedBed;
  bool _isLoading = true;
  bool _isTransferring = false;
  UserModel? _patient;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final rooms = await _dataService.getRooms();
      final roomsList = rooms.cast<RoomModel>();

      final bedsByRoom = <String, List<BedModel>>{};
      for (final room in roomsList) {
        final beds = await _dataService.getBeds(roomId: room.id);
        // استبعاد السرير الحالي والسرائر المشغولة
        final availableBeds = beds
            .cast<BedModel>()
            .where((b) =>
                b.id != widget.currentBed.id &&
                b.status == BedStatus.available)
            .toList();
        bedsByRoom[room.id] = availableBeds;
      }

      // تحميل معلومات المريض
      if (widget.currentBed.patientId != null) {
        try {
          final patients = await _dataService.getPatients();
          final patientList = patients.cast<UserModel>();
          _patient = patientList.firstWhere(
            (p) => p.id == widget.currentBed.patientId,
            orElse: () => UserModel(
              id: widget.currentBed.patientId!,
              name: 'مريض غير معروف',
              email: '',
              phone: '',
              role: UserRole.patient,
              createdAt: DateTime.now(),
            ),
          );
        } catch (e) {
          debugPrint('خطأ في تحميل معلومات المريض: $e');
        }
      }

      setState(() {
        _rooms = roomsList;
        _bedsByRoom = bedsByRoom;
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

  Future<void> _transferBed() async {
    if (_selectedBed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار سرير جديد')),
      );
      return;
    }

    if (widget.currentBed.patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مريض في السرير الحالي')),
      );
      return;
    }

    setState(() => _isTransferring = true);
    try {
      // نقل المريض إلى السرير الجديد
      await _dataService.assignBed(_selectedBed!.id, widget.currentBed.patientId!);

      // إخلاء السرير القديم
      await _dataService.updateBed(
        widget.currentBed.id,
        status: BedStatus.available,
        patientId: null,
        occupiedSince: null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نقل المريض بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isTransferring = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في نقل المريض: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقل مريض'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'السرير الحالي',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('التسمية: ${widget.currentBed.label}'),
                          if (_patient != null) ...[
                            const SizedBox(height: 8),
                            Text('المريض: ${_patient!.name}'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'اختر السرير الجديد',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_rooms.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('لا توجد غرف متاحة'),
                      ),
                    )
                  else
                    ..._rooms.map((room) {
                      final beds = _bedsByRoom[room.id] ?? [];
                      if (beds.isEmpty) return const SizedBox.shrink();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: const Icon(Icons.room),
                          title: Text(room.name),
                          subtitle: Text('${beds.length} سرير متاح'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: beds.map((bed) {
                                  final isSelected = _selectedBed?.id == bed.id;
                                  return ChoiceChip(
                                    label: Text(bed.label),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() => _selectedBed = bed);
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isTransferring || _selectedBed == null
                          ? null
                          : _transferBed,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isTransferring
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('نقل المريض'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

