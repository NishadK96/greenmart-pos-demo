import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/api_provider.dart';
import '../application/windows_update_installer.dart';
import '../domain/app_update_info.dart';

class WindowsUpdateGate extends ConsumerStatefulWidget {
  const WindowsUpdateGate({
    super.key,
    required this.accessToken,
    required this.child,
  });

  final String accessToken;
  final Widget child;

  @override
  ConsumerState<WindowsUpdateGate> createState() => _WindowsUpdateGateState();
}

class _WindowsUpdateGateState extends ConsumerState<WindowsUpdateGate> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final currentVersion = _serverVersion(package);
      final update = await ref
          .read(apiProvider)
          .windowsAppUpdate(
            accessToken: widget.accessToken,
            currentVersion: currentVersion,
          );
      if (!mounted || !update.canInstall) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: !update.mandatory,
        builder: (_) => _WindowsUpdateDialog(update: update),
      );
    } catch (error) {
      if (!mounted || kDebugMode) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to check for app updates right now.'),
        ),
      );
    }
  }

  String _serverVersion(PackageInfo package) {
    final version = package.version.trim();
    final build = package.buildNumber.trim();
    if (build.isEmpty || build == '0' || version.endsWith('.$build')) {
      return version;
    }
    return '$version.$build';
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _WindowsUpdateDialog extends StatefulWidget {
  const _WindowsUpdateDialog({required this.update});

  final AppUpdateInfo update;

  @override
  State<_WindowsUpdateDialog> createState() => _WindowsUpdateDialogState();
}

class _WindowsUpdateDialogState extends State<_WindowsUpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      await downloadAndLaunchWindowsUpdate(
        widget.update,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'The update could not be installed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    return PopScope(
      canPop: !update.mandatory && !_downloading,
      child: AlertDialog(
        icon: const Icon(Icons.system_update_alt_rounded, size: 36),
        title: Text(
          update.mandatory ? 'Update required' : 'Eazy POS update available',
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version ${update.version} is ready to install.'),
              if (update.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'What’s new',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...update.releaseNotes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $note'),
                  ),
                ),
              ],
              if (_downloading) ...[
                const SizedBox(height: 18),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text('Downloading ${(_progress * 100).round()}%'),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!update.mandatory)
            TextButton(
              onPressed: _downloading ? null : () => Navigator.pop(context),
              child: const Text('Later'),
            ),
          FilledButton.icon(
            onPressed: _downloading ? null : _install,
            icon: const Icon(Icons.download_rounded),
            label: Text(_error == null ? 'Download and install' : 'Try again'),
          ),
        ],
      ),
    );
  }
}
