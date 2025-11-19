import 'package:flutter/material.dart';
import '../../utils/auth_helper.dart';
import 'employees_management_screen.dart';
import 'leaves_management_screen.dart';
import 'payroll_management_screen.dart';
import 'training_management_screen.dart';
import 'certifications_management_screen.dart';

class HRManagementScreen extends StatelessWidget {
  const HRManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام الموارد البشرية'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'الموظفين'),
              Tab(icon: Icon(Icons.calendar_today), text: 'الإجازات'),
              Tab(icon: Icon(Icons.payment), text: 'الرواتب'),
              Tab(icon: Icon(Icons.school), text: 'التدريب'),
              Tab(icon: Icon(Icons.card_membership), text: 'الشهادات'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            EmployeesManagementScreen(),
            LeavesManagementScreen(),
            PayrollManagementScreen(),
            TrainingManagementScreen(),
            CertificationsManagementScreen(),
          ],
        ),
      ),
    );
  }
}

