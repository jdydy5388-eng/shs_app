import 'package:flutter/material.dart';
import 'maintenance_requests_screen.dart';
import 'scheduled_maintenance_screen.dart';
import 'equipment_status_screen.dart';
import 'maintenance_vendors_screen.dart';

class MaintenanceManagementScreen extends StatelessWidget {
  const MaintenanceManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام الصيانة'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.build), text: 'طلبات الصيانة'),
              Tab(icon: Icon(Icons.schedule), text: 'الصيانة الدورية'),
              Tab(icon: Icon(Icons.precision_manufacturing), text: 'حالة المعدات'),
              Tab(icon: Icon(Icons.business), text: 'موردين الصيانة'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MaintenanceRequestsScreen(),
            ScheduledMaintenanceScreen(),
            EquipmentStatusScreen(),
            MaintenanceVendorsScreen(),
          ],
        ),
      ),
    );
  }
}

