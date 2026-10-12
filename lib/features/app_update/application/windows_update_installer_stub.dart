import '../domain/app_update_info.dart';

Future<void> downloadAndLaunchWindowsUpdate(
  AppUpdateInfo update, {
  required void Function(double progress) onProgress,
}) => throw UnsupportedError('Windows updates are only available on Windows.');
