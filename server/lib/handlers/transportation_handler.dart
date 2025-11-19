import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/database_service.dart';
import '../utils/response_helper.dart';
import '../logger/app_logger.dart';

class TransportationHandler {
  final DatabaseService _db = DatabaseService();

  Router get router {
    final router = Router();

    // Ambulances
    router.get('/ambulances', _getAmbulances);
    router.post('/ambulances', _createAmbulance);

    // Transportation Requests
    router.get('/requests', _getTransportationRequests);
    router.post('/requests', _createTransportationRequest);

    // Location Tracking
    router.get('/location-tracking', _getLocationTracking);

    return router;
  }

  Future<Response> _getAmbulances(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final conn = await _db.connection;

      String query = 'SELECT * FROM ambulances WHERE 1=1';
      final values = <String, dynamic>{};

      if (queryParams.containsKey('status')) {
        query += ' AND status = @status';
        values['status'] = queryParams['status']!;
      }

      query += ' ORDER BY vehicle_number ASC';

      final results = await conn.query(query, substitutionValues: values.isEmpty ? null : values);

      final ambulances = results.map((row) {
        return {
          'id': row[0],
          'vehicleNumber': row[1],
          'vehicleModel': row[2],
          'type': row[3],
          'status': row[4],
          'driverId': row[5],
          'driverName': row[6],
          'location': row[7],
          'latitude': row[8],
          'longitude': row[9],
          'lastLocationUpdate': row[10],
          'equipment': row[11],
          'notes': row[12],
          'additionalInfo': row[13] != null ? jsonDecode(row[13] as String) : null,
          'createdAt': row[14],
          'updatedAt': row[15],
        };
      }).toList();

      return ResponseHelper.list(data: ambulances);
    } catch (e, stackTrace) {
      AppLogger.error('Get ambulances error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب سيارات الإسعاف: $e', stackTrace);
    }
  }

  Future<Response> _createAmbulance(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO ambulances (
          id, vehicle_number, vehicle_model, type, status,
          driver_id, driver_name, location, latitude, longitude,
          last_location_update, equipment, notes, additional_info,
          created_at, updated_at
        ) VALUES (
          @id, @vehicleNumber, @vehicleModel, @type, @status,
          @driverId, @driverName, @location, @latitude, @longitude,
          @lastLocationUpdate, @equipment, @notes, @additionalInfo,
          @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'vehicleNumber': data['vehicleNumber'],
        'vehicleModel': data['vehicleModel'],
        'type': data['type'],
        'status': data['status'] ?? 'available',
        'driverId': data['driverId'],
        'driverName': data['driverName'],
        'location': data['location'],
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'lastLocationUpdate': data['lastLocationUpdate'],
        'equipment': data['equipment'],
        'notes': data['notes'],
        'additionalInfo': data['additionalInfo'] != null ? jsonEncode(data['additionalInfo']) : null,
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success({'message': 'تم إنشاء سيارة الإسعاف بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create ambulance error', e, stackTrace);
      return ResponseHelper.error('خطأ في إنشاء سيارة الإسعاف: $e', stackTrace);
    }
  }

  Future<Response> _getTransportationRequests(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final conn = await _db.connection;

      String query = 'SELECT * FROM transportation_requests WHERE 1=1';
      final values = <String, dynamic>{};

      if (queryParams.containsKey('status')) {
        query += ' AND status = @status';
        values['status'] = queryParams['status']!;
      }

      query += ' ORDER BY requested_date DESC';

      final results = await conn.query(query, substitutionValues: values.isEmpty ? null : values);

      final requests = results.map((row) {
        return {
          'id': row[0],
          'patientId': row[1],
          'patientName': row[2],
          'type': row[3],
          'status': row[4],
          'pickupLocation': row[5],
          'pickupLatitude': row[6],
          'pickupLongitude': row[7],
          'dropoffLocation': row[8],
          'dropoffLatitude': row[9],
          'dropoffLongitude': row[10],
          'requestedDate': row[11],
          'scheduledDate': row[12],
          'pickupTime': row[13],
          'dropoffTime': row[14],
          'ambulanceId': row[15],
          'ambulanceNumber': row[16],
          'driverId': row[17],
          'driverName': row[18],
          'reason': row[19],
          'notes': row[20],
          'requestedBy': row[21],
          'requestedByName': row[22],
          'additionalData': row[23] != null ? jsonDecode(row[23] as String) : null,
          'createdAt': row[24],
          'updatedAt': row[25],
        };
      }).toList();

      return ResponseHelper.list(data: requests);
    } catch (e, stackTrace) {
      AppLogger.error('Get transportation requests error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب طلبات النقل: $e', stackTrace);
    }
  }

  Future<Response> _createTransportationRequest(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final conn = await _db.connection;
      await conn.execute('''
        INSERT INTO transportation_requests (
          id, patient_id, patient_name, type, status,
          pickup_location, pickup_latitude, pickup_longitude,
          dropoff_location, dropoff_latitude, dropoff_longitude,
          requested_date, scheduled_date, pickup_time, dropoff_time,
          ambulance_id, ambulance_number, driver_id, driver_name,
          reason, notes, requested_by, requested_by_name,
          additional_data, created_at, updated_at
        ) VALUES (
          @id, @patientId, @patientName, @type, @status,
          @pickupLocation, @pickupLatitude, @pickupLongitude,
          @dropoffLocation, @dropoffLatitude, @dropoffLongitude,
          @requestedDate, @scheduledDate, @pickupTime, @dropoffTime,
          @ambulanceId, @ambulanceNumber, @driverId, @driverName,
          @reason, @notes, @requestedBy, @requestedByName,
          @additionalData, @createdAt, @updatedAt
        )
      ''', substitutionValues: {
        'id': data['id'],
        'patientId': data['patientId'],
        'patientName': data['patientName'],
        'type': data['type'],
        'status': data['status'] ?? 'pending',
        'pickupLocation': data['pickupLocation'],
        'pickupLatitude': data['pickupLatitude'],
        'pickupLongitude': data['pickupLongitude'],
        'dropoffLocation': data['dropoffLocation'],
        'dropoffLatitude': data['dropoffLatitude'],
        'dropoffLongitude': data['dropoffLongitude'],
        'requestedDate': data['requestedDate'] ?? DateTime.now().millisecondsSinceEpoch,
        'scheduledDate': data['scheduledDate'],
        'pickupTime': data['pickupTime'],
        'dropoffTime': data['dropoffTime'],
        'ambulanceId': data['ambulanceId'],
        'ambulanceNumber': data['ambulanceNumber'],
        'driverId': data['driverId'],
        'driverName': data['driverName'],
        'reason': data['reason'],
        'notes': data['notes'],
        'requestedBy': data['requestedBy'],
        'requestedByName': data['requestedByName'],
        'additionalData': data['additionalData'] != null ? jsonEncode(data['additionalData']) : null,
        'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': data['updatedAt'],
      });

      return ResponseHelper.success({'message': 'تم إنشاء طلب النقل بنجاح'});
    } catch (e, stackTrace) {
      AppLogger.error('Create transportation request error', e, stackTrace);
      return ResponseHelper.error('خطأ في إنشاء طلب النقل: $e', stackTrace);
    }
  }

  Future<Response> _getLocationTracking(Request request) async {
    try {
      final queryParams = request.url.queryParameters;
      final conn = await _db.connection;

      String query = 'SELECT * FROM location_tracking WHERE 1=1';
      final values = <String, dynamic>{};

      if (queryParams.containsKey('ambulanceId')) {
        query += ' AND ambulance_id = @ambulanceId';
        values['ambulanceId'] = queryParams['ambulanceId']!;
      }

      query += ' ORDER BY timestamp DESC LIMIT 100';

      final results = await conn.query(query, substitutionValues: values.isEmpty ? null : values);

      final locations = results.map((row) {
        return {
          'id': row[0],
          'ambulanceId': row[1],
          'ambulanceNumber': row[2],
          'latitude': row[3],
          'longitude': row[4],
          'address': row[5],
          'speed': row[6],
          'heading': row[7],
          'timestamp': row[8],
          'metadata': row[9] != null ? jsonDecode(row[9] as String) : null,
        };
      }).toList();

      return ResponseHelper.list(data: locations);
    } catch (e, stackTrace) {
      AppLogger.error('Get location tracking error', e, stackTrace);
      return ResponseHelper.error('خطأ في جلب تتبع المواقع: $e', stackTrace);
    }
  }
}

