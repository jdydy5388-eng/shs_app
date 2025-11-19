import 'package:flutter/material.dart';

class QualityReportsScreen extends StatelessWidget {
  final DateTime? fromDate;
  final DateTime? toDate;

  const QualityReportsScreen({
    super.key,
    this.fromDate,
    this.toDate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assessment, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'تقارير الجودة',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'قريباً...',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
