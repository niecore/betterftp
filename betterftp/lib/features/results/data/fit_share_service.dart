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
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final filePath = '${dir.path}/ftp_test_$timestamp.fit';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'application/vnd.ant.fit')],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
