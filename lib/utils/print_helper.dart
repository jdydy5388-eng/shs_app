import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

/// Helper class for printing PDFs with platform-specific implementations
/// Uses open_file for Windows/Linux/MacOS to avoid printing package issues
class PrintHelper {
  /// Print or save PDF based on platform
  static Future<void> printPdf({
    required Future<List<int>> Function() generatePdf,
    String? fileName,
  }) async {
    try {
      // For all platforms, save file and open it
      // This avoids printing package issues on Windows
      final bytes = await generatePdf();
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${fileName ?? 'document'}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      await OpenFile.open(filePath);
    } catch (e) {
      throw Exception('Failed to save/open PDF: $e');
    }
  }
}
