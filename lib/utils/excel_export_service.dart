import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ExcelExportService {
  static Future<void> exportReport({
    required String fileName,
    required List<String> headers,
    required List<List<dynamic>> data,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // إضافة العناوين
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
    }

    // إضافة البيانات
    for (int row = 0; row < data.length; row++) {
      for (int col = 0; col < data[row].length; col++) {
        final value = data[row][col];
        if (value is String) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1)).value = TextCellValue(value);
        } else if (value is num) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1)).value = IntCellValue(value.toInt());
        } else {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1)).value = TextCellValue(value.toString());
        }
      }
    }

    // حفظ الملف
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);

    // فتح الملف
    await OpenFile.open(filePath);
  }
}

