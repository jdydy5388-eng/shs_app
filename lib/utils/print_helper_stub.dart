/// Stub implementation for non-web platforms
void downloadPdfOnWeb(List<int> bytes, String fileName) {
  // This should never be called on non-web platforms
  throw UnsupportedError('downloadPdfOnWeb is only available on web');
}

