import 'package:flutter/material.dart';
import 'ambulances_management_screen.dart';
import 'transportation_requests_screen.dart';
import 'location_tracking_screen.dart';

class TransportationManagementScreen extends StatelessWidget {
  const TransportationManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام المواصلات'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.local_shipping), text: 'سيارات الإسعاف'),
              Tab(icon: Icon(Icons.transfer_within_a_station), text: 'طلبات النقل'),
              Tab(icon: Icon(Icons.location_on), text: 'تتبع المواقع'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AmbulancesManagementScreen(),
            TransportationRequestsScreen(),
            LocationTrackingScreen(),
          ],
        ),
      ),
    );
  }
}

