import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/room_bed_model.dart';
import '../../models/user_model.dart';
import '../../models/lab_request_model.dart';
import '../../models/medical_record_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';
import 'assign_bed_screen.dart';
import 'transfer_bed_screen.dart';
import 'create_room_screen.dart';
import 'create_bed_screen.dart';
import 'edit_room_screen.dart';

class RoomsBedsManagementScreen extends StatefulWidget {
  const RoomsBedsManagementScreen({super.key});

  @override
  State<RoomsBedsManagementScreen> createState() => _RoomsBedsManagementScreenState();
}

class _RoomsBedsManagementScreenState extends State<RoomsBedsManagementScreen>
    with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  List<RoomModel> _rooms = [];
  Map<String, List<BedModel>> _bedsByRoom = {};
  Map<String, String> _patientNames = {}; // خريطة لتخزين أسماء المرضى
  bool _isLoading = true;
  RoomType? _filterType;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final rooms = await _dataService.getRooms();
      final roomsList = rooms.cast<RoomModel>();

      final bedsByRoom = <String, List<BedModel>>{};
      final patientIds = <String>{};
      
      for (final room in roomsList) {
        final beds = await _dataService.getBeds(roomId: room.id);
        bedsByRoom[room.id] = beds.cast<BedModel>();
        // جمع معرفات المرضى من الأسرة المشغولة
        for (final bed in beds) {
          if (bed.patientId != null && bed.patientId!.isNotEmpty) {
            patientIds.add(bed.patientId!);
          }
        }
      }

      // تحميل أسماء المرضى
      final patientNames = <String, String>{};
      if (patientIds.isNotEmpty) {
        try {
          final patients = await _dataService.getPatients();
          for (final patient in patients) {
            if (patientIds.contains(patient.id)) {
              patientNames[patient.id] = patient.name;
            }
          }
        } catch (e) {
          // في حالة فشل تحميل أسماء المرضى، نستمر بدونها
          print('خطأ في تحميل أسماء المرضى: $e');
        }
      }

      setState(() {
        _rooms = roomsList;
        _bedsByRoom = bedsByRoom;
        _patientNames = patientNames;
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

  List<RoomModel> get _filteredRooms {
    if (_filterType == null) return _rooms;
    return _rooms.where((r) => r.type == _filterType).toList();
  }

  Map<String, dynamic> get _statistics {
    int totalBeds = 0;
    int occupiedBeds = 0;
    int availableBeds = 0;
    int maintenanceBeds = 0;

    for (final beds in _bedsByRoom.values) {
      totalBeds += beds.length;
      for (final bed in beds) {
        if (bed.status == BedStatus.occupied) {
          occupiedBeds++;
        } else if (bed.status == BedStatus.available) {
          availableBeds++;
        } else if (bed.status == BedStatus.maintenance) {
          maintenanceBeds++;
        }
      }
    }

    final occupancyRate = totalBeds > 0 ? (occupiedBeds / totalBeds * 100) : 0.0;

    return {
      'totalRooms': _rooms.length,
      'totalBeds': totalBeds,
      'occupiedBeds': occupiedBeds,
      'availableBeds': availableBeds,
      'maintenanceBeds': maintenanceBeds,
      'occupancyRate': occupancyRate,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الغرف والأسرة'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الغرف والأسرة', icon: Icon(Icons.bed)),
            Tab(text: 'الإحصائيات', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'type') {
                _showTypeFilter();
              } else if (value == 'clear') {
                setState(() => _filterType = null);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'type',
                child: Text('فلترة حسب النوع'),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('إزالة الفلاتر'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddMenu(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRoomsTab(),
          _buildStatisticsTab(),
        ],
      ),
    );
  }

  Widget _buildRoomsTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: _filteredRooms.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bed_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد غرف مسجلة',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddMenu(),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة غرفة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredRooms.length,
                    itemBuilder: (context, index) {
                      final room = _filteredRooms[index];
                      return _buildRoomCard(room);
                    },
                  ),
          );
  }

  Widget _buildRoomCard(RoomModel room) {
    final beds = _bedsByRoom[room.id] ?? [];
    final occupiedBeds = beds.where((b) => b.status == BedStatus.occupied).length;
    final availableBeds = beds.where((b) => b.status == BedStatus.available).length;
    final maintenanceBeds = beds.where((b) => b.status == BedStatus.maintenance).length;

    final roomTypeText = {
      RoomType.ward: 'عادية',
      RoomType.icu: 'عناية مركزة',
      RoomType.operation: 'عمليات',
      RoomType.isolation: 'عزل',
    }[room.type]!;

    final roomTypeColor = {
      RoomType.ward: Colors.blue,
      RoomType.icu: Colors.red,
      RoomType.operation: Colors.orange,
      RoomType.isolation: Colors.purple,
    }[room.type]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: roomTypeColor.withValues(alpha: 0.2),
          child: Icon(Icons.room, color: roomTypeColor),
        ),
        title: Text(
          room.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('النوع: $roomTypeText'),
            if (room.floor != null) Text('الطابق: ${room.floor}'),
            Text('عدد الأسرة: ${beds.length}'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(
                    'مشغولة: $occupiedBeds',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.red.withValues(alpha: 0.2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    'متاحة: $availableBeds',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.green.withValues(alpha: 0.2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (room.notes != null && room.notes!.isNotEmpty) ...[
                  Text(
                    'ملاحظات: ${room.notes}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                ],
                const Divider(),
                const Text(
                  'الأسرة:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (beds.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('لا توجد أسرة في هذه الغرفة'),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: beds.map((bed) => _buildBedChip(bed)).toList(),
                  ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // على الشاشات الصغيرة، نضع الأزرار في عمود
                    if (constraints.maxWidth < 600) {
                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _addBed(room),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('إضافة سرير'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _editRoom(room),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('تعديل'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _deleteRoom(room),
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  label: const Text('حذف', style: TextStyle(color: Colors.red)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    // على الشاشات الكبيرة، نستخدم Row
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _addBed(room),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('إضافة سرير'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _editRoom(room),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('تعديل'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _deleteRoom(room),
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            label: const Text('حذف', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBedChip(BedModel bed) {
    final statusColor = {
      BedStatus.available: Colors.green,
      BedStatus.occupied: Colors.red,
      BedStatus.reserved: Colors.orange,
      BedStatus.maintenance: Colors.grey,
    }[bed.status]!;

    final statusText = {
      BedStatus.available: 'متاحة',
      BedStatus.occupied: 'مشغولة',
      BedStatus.reserved: 'محجوزة',
      BedStatus.maintenance: 'صيانة',
    }[bed.status]!;

    String? stayDuration;
    if (bed.status == BedStatus.occupied && bed.occupiedSince != null) {
      final duration = DateTime.now().difference(bed.occupiedSince!);
      if (duration.inDays > 0) {
        stayDuration = '${duration.inDays} يوم';
      } else if (duration.inHours > 0) {
        stayDuration = '${duration.inHours} ساعة';
      } else {
        stayDuration = '${duration.inMinutes} دقيقة';
      }
    }

    // الحصول على اسم المريض إذا كان السرير مشغولاً
    String? patientName;
    if (bed.status == BedStatus.occupied && bed.patientId != null) {
      patientName = _patientNames[bed.patientId];
    }

    // إذا كان السرير مشغولاً، نعرض معلومات المريض بشكل أوضح
    if (bed.status == BedStatus.occupied && patientName != null) {
      return InkWell(
        onTap: () => _showBedActions(bed),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 10,
                    child: const Icon(Icons.bed, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${bed.label} ($statusText)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_pin, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      patientName!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              if (stayDuration != null) ...[
                const SizedBox(height: 4),
                Text(
                  'مدة الإقامة: $stayDuration',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    // للأسرة غير المشغولة، نستخدم التصميم العادي
    return InkWell(
      onTap: () => _showBedActions(bed),
      child: Chip(
        avatar: CircleAvatar(
          backgroundColor: statusColor,
          radius: 8,
          child: Icon(Icons.bed, size: 14, color: Colors.white),
        ),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${bed.label} ($statusText)',
              style: const TextStyle(fontSize: 12),
            ),
            if (stayDuration != null)
              Text(
                'مدة الإقامة: $stayDuration',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        backgroundColor: statusColor.withValues(alpha: 0.1),
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
            'إحصائيات الغرف والأسرة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي الغرف',
                  stats['totalRooms'].toString(),
                  Icons.room,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'إجمالي الأسرة',
                  stats['totalBeds'].toString(),
                  Icons.bed,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'أسرة مشغولة',
                  stats['occupiedBeds'].toString(),
                  Icons.person,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'أسرة متاحة',
                  stats['availableBeds'].toString(),
                  Icons.check_circle,
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
                  'أسرة صيانة',
                  stats['maintenanceBeds'].toString(),
                  Icons.build,
                  Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'معدل الإشغال',
                  '${stats['occupancyRate'].toStringAsFixed(1)}%',
                  Icons.percent,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildOccupancyChart(),
          const SizedBox(height: 24),
          _buildMaintenanceAlerts(),
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

  Widget _buildOccupancyChart() {
    final stats = _statistics;
    final totalBeds = stats['totalBeds'] as int;
    final occupiedBeds = stats['occupiedBeds'] as int;
    final availableBeds = stats['availableBeds'] as int;
    final maintenanceBeds = stats['maintenanceBeds'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'توزيع الأسرة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (totalBeds > 0) ...[
              _buildChartBar('مشغولة', occupiedBeds, totalBeds, Colors.red),
              _buildChartBar('متاحة', availableBeds, totalBeds, Colors.green),
              _buildChartBar('صيانة', maintenanceBeds, totalBeds, Colors.grey),
            ] else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('لا توجد بيانات'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBar(String label, int value, int total, Color color) {
    final percentage = total > 0 ? (value / total * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                '$value (${percentage.toStringAsFixed(1)}%)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? value / total : 0,
              minHeight: 20,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceAlerts() {
    final maintenanceBeds = <BedModel>[];
    for (final beds in _bedsByRoom.values) {
      maintenanceBeds.addAll(beds.where((b) => b.status == BedStatus.maintenance));
    }

    if (maintenanceBeds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'تنبيهات الصيانة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'يوجد ${maintenanceBeds.length} سرير يحتاج صيانة',
              style: TextStyle(color: Colors.orange.shade900),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.room),
              title: const Text('إضافة غرفة'),
              onTap: () {
                Navigator.pop(context);
                _addRoom();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bed),
              title: const Text('إضافة سرير'),
              onTap: () {
                Navigator.pop(context);
                _selectRoomForBed();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
    ).then((_) => _loadData());
  }

  void _addBed(RoomModel room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateBedScreen(roomId: room.id, roomName: room.name),
      ),
    ).then((_) => _loadData());
  }

  void _selectRoomForBed() {
    if (_rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد غرف متاحة. يرجى إضافة غرفة أولاً')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر الغرفة'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _rooms.length,
            itemBuilder: (context, index) {
              final room = _rooms[index];
              return ListTile(
                title: Text(room.name),
                subtitle: Text({
                  RoomType.ward: 'عادية',
                  RoomType.icu: 'عناية مركزة',
                  RoomType.operation: 'عمليات',
                  RoomType.isolation: 'عزل',
                }[room.type]!),
                onTap: () {
                  Navigator.pop(context);
                  _addBed(room);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _editRoom(RoomModel room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditRoomScreen(room: room),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _deleteRoom(RoomModel room) async {
    // التحقق من وجود أسرة مشغولة
    final beds = _bedsByRoom[room.id] ?? [];
    final occupiedBeds = beds.where((b) => b.status == BedStatus.occupied).length;
    
    if (occupiedBeds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا يمكن حذف الغرفة لأنها تحتوي على $occupiedBeds سرير مشغول'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          beds.isNotEmpty
              ? 'هل أنت متأكد من حذف الغرفة "${room.name}"؟\nسيتم حذف جميع الأسرة المرتبطة بها (${beds.length} سرير).'
              : 'هل أنت متأكد من حذف الغرفة "${room.name}"؟',
        ),
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

    if (confirm != true) return;

    try {
      await _dataService.deleteRoom(room.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الغرفة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حذف الغرفة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBedActions(BedModel bed) {
    // قائمة خاصة للأسرة المشغولة
    if (bed.status == BedStatus.occupied) {
      _showOccupiedBedMenu(bed);
      return;
    }

    // القائمة العادية للأسرة الأخرى
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bed.status == BedStatus.available) ...[
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('حجز السرير'),
                onTap: () {
                  Navigator.pop(context);
                  _assignBed(bed);
                },
              ),
            ],
            if (bed.status == BedStatus.maintenance) ...[
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: const Text('إتمام الصيانة'),
                onTap: () {
                  Navigator.pop(context);
                  _completeMaintenance(bed);
                },
              ),
            ],
            if (bed.status != BedStatus.maintenance) ...[
              ListTile(
                leading: const Icon(Icons.build),
                title: const Text('وضع في الصيانة'),
                onTap: () {
                  Navigator.pop(context);
                  _setMaintenance(bed);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showOccupiedBedMenu(BedModel bed) {
    final patientName = bed.patientId != null ? _patientNames[bed.patientId] : null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bed, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('السرير: ${bed.label}'),
                  if (patientName != null)
                    Text(
                      'المريض: $patientName',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuButton(
                icon: Icons.send,
                title: 'SEND TO....',
                subtitle: 'نقل المريض',
                onTap: () {
                  Navigator.pop(context);
                  _transferBed(bed);
                },
              ),
              const Divider(),
              _buildMenuButton(
                icon: Icons.assignment,
                title: 'REQUESTS LIST',
                subtitle: 'قائمة الطلبات',
                onTap: () {
                  Navigator.pop(context);
                  _showRequestsList(bed);
                },
              ),
              const Divider(),
              _buildMenuButton(
                icon: Icons.history,
                title: 'OLD PROCEDURE',
                subtitle: 'الإجراءات السابقة',
                onTap: () {
                  Navigator.pop(context);
                  _showOldProcedures(bed);
                },
              ),
              const Divider(),
              _buildMenuButton(
                icon: Icons.logout,
                title: 'DISCHARGE',
                subtitle: 'إخلاء السرير',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _vacateBed(bed);
                },
              ),
              const Divider(),
              _buildMenuButton(
                icon: Icons.medical_services,
                title: 'DOCTOR FOLLOW UP',
                subtitle: 'متابعة الطبيب',
                onTap: () {
                  Navigator.pop(context);
                  _showDoctorFollowUp(bed);
                },
              ),
              const Divider(),
              _buildMenuButton(
                icon: Icons.arrow_back,
                title: 'BACK',
                subtitle: 'رجوع',
                onTap: () => Navigator.pop(context),
              ),
              const Divider(),
              _buildMenuButton(
                icon: Icons.exit_to_app,
                title: 'EXIT F6',
                subtitle: 'خروج',
                color: Colors.red,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.blue, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color ?? Colors.blue,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _assignBed(BedModel bed) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignBedScreen(bed: bed),
      ),
    ).then((_) => _loadData());
  }

  void _transferBed(BedModel bed) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransferBedScreen(currentBed: bed),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _vacateBed(BedModel bed) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إخلاء السرير'),
        content: const Text('هل أنت متأكد من إخلاء هذا السرير؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // نحتاج إضافة وظيفة updateBed في DataService
      await _dataService.updateBed(
        bed.id,
        status: BedStatus.available,
        patientId: null,
        occupiedSince: null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إخلاء السرير بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إخلاء السرير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setMaintenance(BedModel bed) async {
    try {
      await _dataService.updateBed(
        bed.id,
        status: BedStatus.maintenance,
        patientId: null,
        occupiedSince: null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم وضع السرير في الصيانة'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeMaintenance(BedModel bed) async {
    try {
      await _dataService.updateBed(
        bed.id,
        status: BedStatus.available,
        patientId: null,
        occupiedSince: null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إتمام الصيانة'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRequestsList(BedModel bed) {
    if (bed.patientId == null || bed.patientId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد مريض في هذا السرير'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // عرض قائمة طلبات الفحوصات للمريض
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قائمة الطلبات'),
        content: FutureBuilder<List>(
          future: _dataService.getLabRequests(patientId: bed.patientId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Text('خطأ: ${snapshot.error}');
            }
            
            final requests = (snapshot.data ?? []).cast<LabRequestModel>();
            
            if (requests.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('لا توجد طلبات فحوصات'),
                ),
              );
            }
            
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return ListTile(
                    leading: Icon(
                      _getRequestStatusIcon(request.status),
                      color: _getRequestStatusColor(request.status),
                    ),
                    title: Text(request.testType),
                    subtitle: Text('${request.patientName} - ${_formatDate(request.requestedAt)}'),
                    trailing: Chip(
                      label: Text(_getRequestStatusText(request.status)),
                      backgroundColor: _getRequestStatusColor(request.status).withValues(alpha: 0.2),
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  IconData _getRequestStatusIcon(dynamic status) {
    final statusStr = status.toString().toLowerCase();
    if (statusStr.contains('pending')) return Icons.pending;
    if (statusStr.contains('completed')) return Icons.check_circle;
    if (statusStr.contains('cancelled')) return Icons.cancel;
    return Icons.assignment;
  }

  Color _getRequestStatusColor(dynamic status) {
    final statusStr = status.toString().toLowerCase();
    if (statusStr.contains('pending')) return Colors.orange;
    if (statusStr.contains('completed')) return Colors.green;
    if (statusStr.contains('cancelled')) return Colors.red;
    return Colors.grey;
  }

  String _getRequestStatusText(dynamic status) {
    final statusStr = status.toString().toLowerCase();
    if (statusStr.contains('pending')) return 'قيد الانتظار';
    if (statusStr.contains('completed')) return 'مكتمل';
    if (statusStr.contains('cancelled')) return 'ملغى';
    return 'غير محدد';
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  void _showOldProcedures(BedModel bed) {
    if (bed.patientId == null || bed.patientId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد مريض في هذا السرير'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // عرض السجل الطبي للمريض (الإجراءات السابقة)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الإجراءات السابقة'),
        content: FutureBuilder<List>(
          future: _dataService.getMedicalRecords(patientId: bed.patientId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Text('خطأ: ${snapshot.error}');
            }
            
            final records = (snapshot.data ?? []).cast<MedicalRecordModel>();
            
            if (records.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('لا توجد سجلات طبية'),
                ),
              );
            }
            
            return SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        Icons.medical_information,
                        color: Colors.blue,
                      ),
                      title: Text(record.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('التاريخ: ${_formatDate(record.date)}'),
                          if (record.doctorName != null)
                            Text('الطبيب: ${record.doctorName}'),
                          if (record.description != null && record.description!.isNotEmpty)
                            Text(
                              record.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showDoctorFollowUp(BedModel bed) {
    if (bed.patientId == null || bed.patientId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد مريض في هذا السرير'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final patientName = _patientNames[bed.patientId];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.medical_services, color: Colors.blue),
            SizedBox(width: 8),
            Text('متابعة الطبيب'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (patientName != null) ...[
              Text(
                'المريض: $patientName',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'يرجى التواصل مع الطبيب المعالج للمتابعة.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'يمكنك الاطلاع على:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• السجلات الطبية'),
            const Text('• الوصفات الطبية'),
            const Text('• نتائج الفحوصات'),
            const Text('• التقارير الطبية'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showOldProcedures(bed);
            },
            icon: const Icon(Icons.medical_information),
            label: const Text('عرض السجلات الطبية'),
          ),
        ],
      ),
    );
  }

  void _showTypeFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب النوع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<RoomType?>(
              title: const Text('جميع الأنواع'),
              value: null,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<RoomType?>(
              title: const Text('عادية'),
              value: RoomType.ward,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<RoomType?>(
              title: const Text('عناية مركزة'),
              value: RoomType.icu,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<RoomType?>(
              title: const Text('عمليات'),
              value: RoomType.operation,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<RoomType?>(
              title: const Text('عزل'),
              value: RoomType.isolation,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

