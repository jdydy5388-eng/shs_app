import 'package:shelf/shelf.dart';
import 'dart:convert';

class ResponseHelper {
  static Response success({
    required Map<String, dynamic> data,
    int statusCode = 200,
  }) {
    return Response(
      statusCode,
      body: jsonEncode({
        'success': true,
        'data': data,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Response error({
    required String message,
    int statusCode = 400,
    dynamic error,
  }) {
    return Response(
      statusCode,
      body: jsonEncode({
        'success': false,
        'error': message,
        if (error != null) 'details': error.toString(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Response list({
    required List<Map<String, dynamic>> data,
    int statusCode = 200,
  }) {
    return Response(
      statusCode,
      body: jsonEncode({
        'success': true,
        'data': data,
        'count': data.length,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Response unauthorized([String message = 'غير مصرح']) {
    return Response(
      401,
      body: jsonEncode({
        'success': false,
        'error': message,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Response forbidden([String message = 'غير مسموح']) {
    return Response(
      403,
      body: jsonEncode({
        'success': false,
        'error': message,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Response notFound([String message = 'غير موجود']) {
    return Response(
      404,
      body: jsonEncode({
        'success': false,
        'error': message,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

