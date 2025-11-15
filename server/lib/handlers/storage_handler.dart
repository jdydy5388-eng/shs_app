import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'dart:convert' as conv;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../utils/response_helper.dart';

class StorageHandler {
  StorageHandler() {
    _ensureUploadsDir();
  }

  final String _uploadsDir = p.join(Directory.current.path, 'uploads');
  final String _signSecret = Platform.environment['STORAGE_SIGN_SECRET'] ?? 'change_me_secret';

  void _ensureUploadsDir() {
    final dir = Directory(_uploadsDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  Router get router {
    final router = Router();

    // JSON upload: { id, filename, contentBase64, contentType }
    router.post('/upload', _upload);

    // Serve files: /files/<name>
    router.get('/files/<path|.*>', _serveFile);

    // Generate signed URL: { path, expiresSeconds }
    router.post('/sign', _signUrl);

    return router;
  }

  Future<Response> _upload(Request request) async {
    try {
      // بسيط: نسمح فقط للمستخدمين المصادقين - عبر رأس role
      final role = (request.headers['x-user-role'] ?? '').toLowerCase();
      if (role.isEmpty) return Response.forbidden('Unauthorized');
      final bodyStr = await request.readAsString();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;

      final id = (body['id'] as String?) ?? DateTime.now().millisecondsSinceEpoch.toString();
      final filename = (body['filename'] as String?) ?? 'file.bin';
      final contentBase64 = body['contentBase64'] as String?;
      if (contentBase64 == null || contentBase64.isEmpty) {
        return ResponseHelper.error(message: 'Missing contentBase64', statusCode: 400);
      }

      // Decode base64
      final bytes = base64Decode(contentBase64);

      // Sanitize filename and save
      final safeName = '${id}_${filename.replaceAll(RegExp(r"[^a-zA-Z0-9._-]"), "_")}';
      final savePath = p.join(_uploadsDir, safeName);
      final f = File(savePath);
      await f.writeAsBytes(bytes, flush: true);

      // Build public URL
      final url = '/api/storage/files/$safeName';
      return ResponseHelper.success(data: {'url': url, 'name': safeName});
    } catch (e) {
      return ResponseHelper.error(message: 'Upload failed: $e');
    }
  }

  Future<Response> _serveFile(Request request, String path) async {
    try {
      // السماح عبر دور مصادق أو عبر رابط موقّع
      final role = (request.headers['x-user-role'] ?? '').toLowerCase();
      final token = request.url.queryParameters['token'];
      final expiresStr = request.url.queryParameters['expires'];

      if (role.isEmpty) {
        if (token == null || expiresStr == null) {
          return Response.forbidden('Unauthorized');
        }
        final expires = int.tryParse(expiresStr);
        if (expires == null || DateTime.now().millisecondsSinceEpoch > expires) {
          return Response.forbidden('Link expired');
        }
        final expected = _makeSignature(path, expires);
        if (expected != token) {
          return Response.forbidden('Invalid token');
        }
      }
      final filePath = p.normalize(p.join(_uploadsDir, path));
      if (!filePath.startsWith(_uploadsDir)) {
        return Response.forbidden('Invalid path');
      }
      final file = File(filePath);
      if (!file.existsSync()) {
        return Response.notFound('File not found');
      }
      final bytes = await file.readAsBytes();
      // naive content type detection
      String contentType = 'application/octet-stream';
      if (path.endsWith('.png')) contentType = 'image/png';
      else if (path.endsWith('.jpg') || path.endsWith('.jpeg')) contentType = 'image/jpeg';
      else if (path.endsWith('.gif')) contentType = 'image/gif';
      else if (path.endsWith('.pdf')) contentType = 'application/pdf';

      return Response.ok(bytes, headers: {'Content-Type': contentType});
    } catch (_) {
      return Response.internalServerError(body: 'Failed to read file');
    }
  }

  Future<Response> _signUrl(Request request) async {
    try {
      final role = (request.headers['x-user-role'] ?? '').toLowerCase();
      if (role.isEmpty) return Response.forbidden('Unauthorized');
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final path = (body['path'] as String).trim();
      final expiresSeconds = (body['expiresSeconds'] as int?) ?? 300;
      final expires = DateTime.now().millisecondsSinceEpoch + (expiresSeconds * 1000);
      final token = _makeSignature(path, expires);

      // بناء الأساس: /api/storage/
      final baseSegments = <String>[];
      for (final s in request.requestedUri.pathSegments) {
        if (s == 'sign') break;
        baseSegments.add(s);
      }
      final baseUri = request.requestedUri.replace(pathSegments: baseSegments).toString();
      final url = '${baseUri}files/$path?token=$token&expires=$expires';
      return ResponseHelper.success(data: {'url': url, 'expires': expires});
    } catch (e) {
      return ResponseHelper.error(message: 'Sign failed: $e');
    }
  }

  String _makeSignature(String path, int expires) {
    final content = '$path:$expires';
    final h = Hmac(sha256, conv.utf8.encode(_signSecret));
    final digest = h.convert(conv.utf8.encode(content));
    return digest.toString();
  }
}


