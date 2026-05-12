import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../ramp_test/domain/ramp_test_state.dart';
import 'fit_export_service.dart';

/// Handles FIT file creation and native sharing.
class FitShareService {
  final FitExportService _exportService;

  FitShareService({FitExportService? exportService})
      : _exportService = exportService ?? FitExportService();

  /// Encodes the test state, writes to Documents/fit/, and opens the share sheet.
  /// Files persist and are visible in the iOS Files app.
  ///
  /// On iPad the share sheet presents as a popover and requires
  /// [sharePositionOrigin] as the anchor rect — omitting it throws a
  /// PlatformException("Share position must be set"). iPhone/Android ignore it.
  Future<void> shareTestResult(
    TestRunState state, {
    Rect? sharePositionOrigin,
  }) async {
    final bytes = _exportService.encode(state);

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/fit');
    if (!await dir.exists()) await dir.create(recursive: true);
    final safeName = _sanitizeFilename(_filenameBaseFor(state));
    final filePath = _uniquePath(dir.path, safeName);
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'application/vnd.ant.fit')],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  static final _unsafeChars = RegExp(r'[\\/:*?"<>|\x00-\x1f]');

  /// Filename mirrors the embedded activity name but with the test
  /// start date+time inserted before the brand suffix, so multiple
  /// tests (same protocol + FTP, different day) don't collide.
  String _filenameBaseFor(TestRunState state) {
    final protocol = state.protocol.label;
    final ftp = state.calculatedFtp;
    final dateStr = _formatDate(state.allReadings.first.timestamp);
    if (ftp == null) {
      return '$protocol Test - $dateStr - betterftp.cc';
    }
    return '$protocol Test - ${ftp}W FTP - $dateStr - betterftp.cc';
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} '
        '${two(l.hour)}-${two(l.minute)}';
  }

  String _sanitizeFilename(String name) =>
      name.replaceAll(_unsafeChars, '-').trim();

  String _uniquePath(String dirPath, String baseName) {
    var path = '$dirPath/$baseName.fit';
    var n = 2;
    while (File(path).existsSync()) {
      path = '$dirPath/$baseName ($n).fit';
      n++;
    }
    return path;
  }
}
