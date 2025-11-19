// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web-specific implementation for PDF download
void downloadPdfOnWeb(List<int> bytes, String fileName) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', '$fileName.pdf')
    ..click();
  html.Url.revokeObjectUrl(url);
}

