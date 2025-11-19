import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transportation_models.dart';
import '../../services/data_service.dart';

class LocationTrackingScreen extends StatefulWidget {
  const LocationTrackingScreen({super.key});

  @override
  State<LocationTrackingScreen> createState() => _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends State<LocationTrackingScreen> {
  final DataService _dataService = DataService();
  List<LocationTrackingModel> _locations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    try {
      final locations = await _dataService.getLocationTracking();
      setState(() {
        _locations = locations.cast<LocationTrackingModel>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _locations.isEmpty
              ? const Center(child: Text('لا توجد بيانات تتبع مواقع'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _locations.length,
                  itemBuilder: (context, index) {
                    return _buildLocationCard(_locations[index]);
                  },
                ),
    );
  }

  Widget _buildLocationCard(LocationTrackingModel location) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss', 'ar');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.location_on, color: Colors.white),
        ),
        title: Text(location.ambulanceNumber ?? location.ambulanceId),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('خط العرض: ${location.latitude.toStringAsFixed(6)}'),
            Text('خط الطول: ${location.longitude.toStringAsFixed(6)}'),
            if (location.address != null) Text('العنوان: ${location.address}'),
            if (location.speed != null) Text('السرعة: ${location.speed!.toStringAsFixed(1)} km/h'),
            Text('الوقت: ${dateFormat.format(location.timestamp)}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.map),
          onPressed: () {
            // TODO: Open map with location
          },
        ),
      ),
    );
  }
}

