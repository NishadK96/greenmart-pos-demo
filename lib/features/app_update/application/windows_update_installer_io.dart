import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../domain/app_update_info.dart';

Future<void> downloadAndLaunchWindowsUpdate(
  AppUpdateInfo update, {
  required void Function(double progress) onProgress,
}) async {
  if (!Platform.isWindows || !update.canInstall) {
    throw UnsupportedError('This update cannot be installed on this device.');
  }

  final uri = Uri.parse(update.downloadUrl!);
  final hostAddress = InternetAddress.tryParse(uri.host);
  final isLocal =
      uri.host.toLowerCase() == 'localhost' || hostAddress?.isLoopback == true;
  if (uri.scheme != 'https' && !isLocal) {
    throw const HttpException('The update download must use HTTPS.');
  }

  final safeName = (update.filename ?? 'Eazy-POS-Update.exe').replaceAll(
    RegExp(r'[^A-Za-z0-9._-]'),
    '_',
  );
  if (!safeName.toLowerCase().endsWith('.exe')) {
    throw const FormatException('The update file is not a Windows installer.');
  }

  final directory = await Directory.systemTemp.createTemp('eazy-pos-update-');
  final file = File('${directory.path}${Platform.pathSeparator}$safeName');
  final client = http.Client();
  try {
    final request = http.Request('GET', uri);
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    final resolvedUri = response.request?.url ?? uri;
    final resolvedAddress = InternetAddress.tryParse(resolvedUri.host);
    final resolvedIsLocal =
        resolvedUri.host.toLowerCase() == 'localhost' ||
        resolvedAddress?.isLoopback == true;
    if (resolvedUri.scheme != 'https' && !resolvedIsLocal) {
      throw const HttpException('The update redirected to an insecure URL.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Update download failed with HTTP ${response.statusCode}.',
        uri: uri,
      );
    }

    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 60),
      )) {
        received += chunk.length;
        if (received > update.size!) {
          throw const FormatException(
            'The update file is larger than expected.',
          );
        }
        sink.add(chunk);
        onProgress((received / update.size!).clamp(0, 1));
      }
    } finally {
      await sink.close();
    }

    if (received != update.size!) {
      throw FormatException(
        'The update download is incomplete ($received of ${update.size} bytes).',
      );
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString().toLowerCase() != update.sha256) {
      throw const FormatException('The update checksum does not match.');
    }

    onProgress(1);
    await Process.start(
      file.path,
      const [],
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
    exit(0);
  } catch (_) {
    if (await file.exists()) await file.delete();
    rethrow;
  } finally {
    client.close();
  }
}
