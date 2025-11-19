import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/room_bed_model.dart';
import '../../models/user_model.dart';
import '../../services/data_service.dart';
import '../../utils/auth_helper.dart';
import 'assign_bed_screen.dart';
import 'transfer_bed_screen.dart';
import 'create_room_screen.dart';
import 'create_bed_screen.dart';

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
      for (final room in roomsList) {
        final beds = await _dataService.getBeds(roomId: room.id);
        bedsByRoom[room.id] = beds.cast<BedModel>();
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
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: Text(
                'مشغولة: $occupiedBeds',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: Colors.red.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 4),
            Chip(
              label: Text(
                'متاحة: $availableBeds',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: Colors.green.withValues(alpha: 0.2),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _addBed(room),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة سرير'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _editRoom(room),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('تعديل'),
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

    return InkWell(
      onTap: () => _showBedActions(bed),
      child: Chip(
        avatar: CircleAvatar(
          backgroundColor: statusColor,
          radius: 8,
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
    // يمكن إضافة شاشة تعديل الغرفة لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ميزة التعديل قيد التطوير')),
    );
  }

  void _showBedActions(BedModel bed) {
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
            if (bed.status == BedStatus.occupied) ...[
              ListTile(
                leading: const Icon(Icons.transfer_within_a_station),
                title: const Text('نقل المريض'),
                onTap: () {
                  Navigator.pop(context);
                  _transferBed(bed);
                },
              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('إخلاء السرير'),
                onTap: () {
                  Navigator.pop(context);
                  _vacateBed(bed);
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

