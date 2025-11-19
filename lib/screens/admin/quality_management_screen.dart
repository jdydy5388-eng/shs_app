import 'package:flutter/material.dart';
import '../../utils/auth_helper.dart';
import 'quality_kpis_screen.dart';
import 'medical_incidents_screen.dart';
import 'complaints_management_screen.dart';
import 'quality_reports_screen.dart';
import 'accreditation_requirements_screen.dart';

class QualityManagementScreen extends StatelessWidget {
  const QualityManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام الجودة والاعتماد'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.analytics), text: 'مؤشرات الجودة'),
              Tab(icon: Icon(Icons.warning), text: 'الحوادث الطبية'),
              Tab(icon: Icon(Icons.feedback), text: 'الشكاوى'),
              Tab(icon: Icon(Icons.assessment), text: 'تقارير الجودة'),
              Tab(icon: Icon(Icons.verified_user), text: 'متطلبات الاعتماد'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            QualityKPIsScreen(),
            MedicalIncidentsScreen(),
            ComplaintsManagementScreen(),
            QualityReportsScreen(),
            AccreditationRequirementsScreen(),
          ],
        ),
      ),
    );
  }
}

