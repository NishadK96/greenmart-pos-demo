import 'dart:io';
import 'dart:typed_data';

Future<bool> openDesktopPdfPreview(
  Uint8List bytes, {
  required String fileName,
}) async {
  if (!Platform.isWindows) return false;
  final directory = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}eazy_pos_previews',
  );
  await directory.create(recursive: true);
  final safeName = fileName
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-')
      .replaceAll(RegExp(r'-+'), '-');
  final resolvedName = safeName.toLowerCase().endsWith('.pdf')
      ? safeName
      : '$safeName.pdf';
  final file = File(
    '${directory.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}-$resolvedName',
  );
  await file.writeAsBytes(bytes, flush: true);
  await Process.start('explorer.exe', [
    file.path,
  ], mode: ProcessStartMode.detached);
  return true;
}
